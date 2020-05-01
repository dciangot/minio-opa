# Guida per setup IAM-MINIO-OPA

## Riferimenti

- [https://www.openpolicyagent.org/docs/latest/](https://www.openpolicyagent.org/docs/latest/)
- [https://docs.min.io/docs/minio-sts-quickstart-guide](https://docs.min.io/docs/minio-sts-quickstart-guide)
- [https://github.com/minio/minio/blob/master/docs/sts/opa.md](https://github.com/minio/minio/blob/master/docs/sts/opa.md)

## Prerequisiti

- Install make, docker e docker-compose
- porta 9000 aperta
- Client IAM per code-flow con redirect URIs:
    -  'http://<minio host>:9000/minio/'
    - 'http://<minio host>:9000/minio/login/openid
- Scaricare il repository: 
```bash
git clone https://github.com/dciangot/minio-opa.git && cd minio-opa
```


## Installazione

`docker-compose up`

o 

`make install`

Per stop e start usare:

`make stop/start`

## Test delle default OPA policies in questo setup

- andare alla porta http://<minio host>9000 del sever e seguire la procedura di autenticazione
- una volta entrati si puo creare il solo bucket con il proprio cognome o nome.cognome
- all'interno di quel bucket e' possibile scrivere, leggere e creare cartelle
- dentro il bucket `scratch` tutti possono leggere e scaricare tutto, ma possono solo scrivere in `scratch/<cognome>` o, se mancante, crearla.

Di seguito la spiegazione di come queste policy sono configurate in opa

## Esempio di creazione policy OPA usando token claims IAM in Minio

Un tipico input che arriva al server OPA da Minio dopo l'autenticazione con token IAM e' in questa forma:

```json
      {
        "input": {
          "account": "Z........................BI",
          "action": "s3:CreateBucket",
          "bucket": "ciangottini",
          "conditions": {
            "Accept-Encoding": [
              "identity"
            ],
            "Authorization": [
              "AWS4-HMAC-SHA256 Credential=ZX4QOC80CNLHIBCLG7BI/20200423/us-east-1/s3/aws4_request, SignedHeaders=host;user-agent;x-amz-content-sha256;x-amz-date;x-amz-security-token, Signature=2926934a3a1380ff8c80c20faeb187a2ddcc42b47a9075fb111987c890811618"
            ],
            "Content-Length": [
              "0"
            ],
            "CurrentTime": [
              "2020-04-23T09:09:31Z"
            ],
            "EpochTime": [
              "1587632971"
            ],
            "Referer": [
              ""
            ],
            "SecureTransport": [
              "false"
            ],
            "SourceIp": [
              "188.XX3.77.XX"
            ],
            "User-Agent": [
              "MinIO (Linux; x86_64) minio-py/5.0.10"
            ],
            "UserAgent": [
              "MinIO (Linux; x86_64) minio-py/5.0.10"
            ],
            "X-Amz-Content-Sha256": [
              "e3b.................852b855"
            ],
            "X-Amz-Date": [
              "20200423T090933Z"
            ],
            "X-Amz-Security-Token": [
              "eyJhbGciO............vqgpJO9vWgQ3oc3tDOnP4A"
            ],
            "accessKey": [
              "ZX4QOC80CNLHIBCLG7BI"
            ],
            "aud": [
              "b8.........................d0d9"
            ],
            "email": [
              "ciangottini@pg.infn.it"
            ],
            "iss": [
              "https://iam.cloud.infn.it/"
            ],
            "jti": [
              "ffe5...................ce4e"
            ],
            "kid": [
              "rsa1"
            ],
            "name": [
              "Diego Ciangottini"
            ],
            "organisation_name": [
              "infn-cc"
            ],
            "preferred_username": [
              "ciangottini@infn.it"
            ],
            "principaltype": [
              "User"
            ],
            "sub": [
              "2f8......................286"
            ],
            "userid": [
              "ZX................BI"
            ],
            "username": [
              "ZX4..................BI"
            ]
          },
          "owner": false,
             {"action": "s3:GetObject"},
          "object": "",
          "claims": {
            "accessKey": "................LG7BI",
            "aud": "b830.........................07d0d9",
            "email": "ciangottini@pg.infn.it",
            "exp": 1587633250,
            "groups": [
              "developers"
            ],
            "iat": 1587632650,
            "iss": "https://iam.cloud.infn.it/",
            "jti": "ffe5.......7ce4e",
            "kid": "rsa1",
            "name": "Diego Ciangottini",
            "organisation_name": "infn-cc",
            "preferred_username": "ciangottini@infn.it",
            "sub": "2f8d..............61d89286"
          }
```

Tutti questi parametri possono essere utilizzati da OPA per decidere se autorizzare o no la richiesta. Si vede inoltre che MINIO ha processato l'`id_token` dell'utente ricavandone i campi `claims`.

Nel nostro esempio abbiamo due principali categorie di permessi: `user` e `scratch`.
Nel primo vogliamo autorizzare praticamente qualsiasi operazione s3, mentre nell'altro, vogliamo che solo il list e il get dei file sia permesso.
Questo e' rappresentato nel file di default [policy](https://github.com/dciangot/minio-opa/tree/master/policies) che abbiamo creato con:

```python
package httpapi.authz
import input

default allow = false

# role-permissions assignments
rl_permissions := {
    "user": [{"action": "s3:CreateBucket"},
             {"action": "s3:DeleteBucket"},
             {"action": "s3:DeleteObject"},
             {"action": "s3:GetObject"},
             {"action": "s3:ListAllMyBuckets"},
             {"action": "s3:ListBucket"},
             {"action": "s3:PutObject"}],
    "scratch": [{"action": "s3:ListAllMyBuckets"},
                {"action": "s3:GetObject"},
                {"action": "s3:ListBucket" }]
}
```

Ora possiamo decidere in quali casi applicare questi permessi sulla base degli input visti prima. Iniziamo dal bucket utente, vogliamo autorizzare a creare ed operare su un determinato bucket solo le richieste che arrivano con un `claim` di tipo email nelle forma `<bucket name>@...`. Cosi che nel caso IAM INFN cloud l'utente possa scrivere nel bucket a suo `nome.cognome` o `cognome`.

```python
# Allow users to manage their own data.
allow {
  # Extract username from email
  username := split(lower(input.claims.preferred_username),"@")[0]

  # verify that bucketname == username
  input.bucket == username

  # apply only when token auth happened 
  # This is needed to keep admin user and password with full powers
  input.claims.organisation_name == "infn-cc"

  # Apply user permissions to this request
  permissions := rl_permissions["user"]
  p := permissions[_]
  p == {"action": input.action}
}
```

Per quanto riguarda il bucket `scratch` invece, vogliamo che chiunque abbia i permessi `scratch` definiti sopra, quindi:

```python
# Allow to retrieve and see data from other users in scratch area
allow {
  input.bucket == "scratch"
  permissions := rl_permissions["scratch"]
  p := permissions[_]
  # check if the permission granted to r matches the user request
  p == {"action": input.action}
}
```

Mentre per limitare un subrange di chiamate a path del tipo `scratch/<cognome>` abbiamo bisogno di prendere altri input dalla richiesta e verificarli come segue:

```python
allow {
  username := split(lower(input.claims.preferred_username),"@")[0]

  ref := input.conditions.Referer[_]

  url := concat("/", ["^http://.*:9000/minio/scratch",username,".*$"] )

  re_match( url , ref)

  input.claims.organisation_name == "infn-cc"
  permissions := rl_permissions["user"]
  p := permissions[_]
  p == {"action": input.action}
}
```

Infine vogliamo mantenere tutti i poter per l'autenticazione user e password dell'admin:

```python
allow {
  input.account == "minioadmin"
  permissions := rl_permissions["user"]
  p := permissions[_]
  p == {"action": input.action}
}
```

A questo punto se non fossero gia incluse di default in questo deployment, potremmo inserire nuove policy in opa con un semplice curl:

```
curl -X PUT --data-binary @policy.rego   http://localhost:8181/v1/policies/users
```

## Debugging OPA

I log sono visibili (per ora) in debug mode qui:

```bash
docker logs --tail 2000 minio-opa_opa_1
```


## Debugging Minio

- [Installare client mc](https://github.com/minio/mc/blob/master/docs/minio-admin-complete-guide.md)

- Configurarlo per accesso admin

```bash
mc config host add myminio http://localhost:9000 minioadmin minioadmin
```

- stampare il trace http con

```bash
mc admin trace myminio
```
