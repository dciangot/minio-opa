# Usare Server Side Encryption

"MinIO uses a key-management-system (KMS) to support SSE-S3. If a client requests SSE-S3, or auto-encryption
is enabled, the MinIO server encrypts each object with an unique object key which is protected by a master key
managed by the KMS.
MinIO supports commonly-used KMS implementations, like AWS-KMS or
Hashicorp Vault via our KES project.
KES makes it possible to scale your KMS horizontally with your storage infrastructure (MinIO clusters).
Therefore, it wraps around the KMS implementation like this:"

```
       +-------+                 +-------+
       | MinIO |                 | MinIO |
       +---+---+                 +---+---+
           |                         |
      +----+-------------------------+----+---- KMS
      |    |                         |    |
      | +--+--+                   +--+--+ |
      | | KES +--+             +--+ KES | |
      | +-----+  |  +-------+  |  +-----+ |
      |          +--+ Vault +--+          |
      | +-----+  |  +-------+  |  +-----+ |
      | | KES +--+             +--+ KES | |
      | +--+--+                   +--+--+ |
      |    |                         |    |
      +----+-------------------------+----+---- KMS
           |                         |
       +---+---+                 +---+---+
       | MinIO |                 | MinIO |
       +-------+                 +-------+
```

Per semplicita' di seguito proveremo il setup con un solo server KES e un server minio. Al posto di Vault la chiave verra' salvata su FS.

## Riferimenti
- [https://docs.min.io/docs/how-to-secure-access-to-minio-server-with-tls](https://docs.min.io/docs/how-to-secure-access-to-minio-server-with-tls)
- [https://docs.minio.io/docs/how-to-use-minio-s-server-side-encryption-with-aws-cli](https://docs.minio.io/docs/how-to-use-minio-s-server-side-encryption-with-aws-cli)
- [https://github.com/minio/kes/wiki/MinIO-Object-Storage#kes-server-setup]([https://github.com/minio/kes/wiki/MinIO-Object-Storage#kes-server-setup)
- [https://github.com/minio/kes/wiki/Server-API](https://github.com/minio/kes/wiki/Server-API)

## Requirements

- Install make, docker e docker-compose
- porta 9000 aperta
- Client IAM per code-flow con redirect URIs:
    -  'http://<minio host>:9000/minio/'
    - 'http://<minio host>:9000/minio/login/openid
- Scaricare il repository: 
```bash
git clone https://github.com/dciangot/minio-opa.git && cd minio-opa

# Install utility for self signed certificate generation
sudo wget https://github.com/DODAS-TS/dodas-x509/releases/download/v0.0.2/dodas-x509 -O /usr/local/bin/dodas-x509

# Install Minio KES
wget https://github.com/minio/kes/releases/latest/download/linux-amd64.zip
unzip linux-amd64.zip
sudo mv kes /usr/local/bin/

# Create folder for certificates and keys
mkdir -p certs/CAs
mkdir keys

# Create folder for Minoi encryption test
mkdir data_encrypt
```

## Generate self-signed certificates

```bash
# Generate KES server certificate
dodas-x509 --hostname 127.0.0.1 --ca-path $PWD/certs/CAs --cert-path $PWD/certs --cert-name kes --ca-name KES

# Generate Minio server certificate
dodas-x509 --hostname <public IP minio> --ca-path $PWD/certs/CAs --cert-path $PWD/certs --cert-name minio --ca-name MINIO

# Use the minio naming convention for certificates
mv certs/minio.pem certs/public.crt
mv certs/minio.key certs/private.key
```

## Creare utenti KES

Definiamo un utente con permessi admin (root) e uno per il server Minio:

```bash
# Creation of KES user root
kes tool identity new --key="certs/root.key" --cert="certs/root.cert" root

# Creation of KES user Minio
kes tool identity new --key="certs/minio.key" --cert="certs/minio.cert" MinIO
```

Adesso in cert dovrebbero essere stati create i certificati indicati, che puo' indicarci lo user ID di KES per questi certificati con:

```bash
kes tool identity of certs/root.cert

kes tool identity of certs/minio.cert
```


## File di configurazione KES

Il file di configurazione (`kes.config`) per questo setup consiste nell'indicare i cert per TLS e quello per autorizzare Minio a ritirare e creare chiavi.

```
address = "0.0.0.0:7373"
root    = "<value obtained with: `kes tool identity of certs/root.cert`>"

[tls]
key  = "kes.key"
cert = "kes.pem"

[policy.prod-app] 
paths      = [ "/v1/key/create/my-minio-key", 
               "/v1/key/generate/my-minio-key" ,
               "/v1/key/decrypt/my-minio-key" ]
identities = [ "<value obtained with: `kes tool identity of certs/minio.cert`>" ]

# We use the local filesystem for simplicity.
# We could use Vault for instance.
[keystore.fs]
path    = "./keys" # Choose a directory for the secret keys
```

## Docker Compose: minio, opa, kes

```yaml
version: '3.7'
services:
  opa:
    image: openpolicyagent/opa:0.18.0
    network_mode: host
    command:
      - "run"
      - "--server"
      - "--log-level=debug"
      - "--log-format=text"
      - "--addr=0.0.0.0:8181"
      - "/policies"
    volumes:
      - ./policies:/policies

  minio:
    network_mode: host
    image: dciangot/minio
    command:
      - "server"
      - "--address"
      - ":9000"
      - "/data"
    environment:
      MINIO_POLICY_OPA_URL: http://localhost:8181/v1/data/httpapi/authz/allow
      MINIO_IDENTITY_OPENID_CLIENT_ID: <IAM client ID>
      MINIO_IDENTITY_OPENID_CONFIG_URL: https://iam-demo.cloud.cnaf.infn.it/.well-known/openid-configuration
      MINIO_KMS_KES_ENDPOINT: https://127.0.0.1:7373
      MINIO_KMS_KES_CERT_FILE: /root/.minio/certs/minio.cert
      MINIO_KMS_KES_KEY_FILE: /root/.minio/certs/minio.key
      MINIO_KMS_KES_CA_PATH: /root/.minio/certs/kes.pem
      MINIO_KMS_KES_KEY_NAME: my-minio-key
      MINIO_KMS_AUTO_ENCRYPTION: 1
    volumes:
      - ./data_encrypt:/data
      - ./certs:/root/.minio/certs

  kes:
    network_mode: host
    image: minio/kes
    command:
      - "server"
      - "--mtls-auth=ignore"
      - "--config=/root/config/server-config.toml"
    volumes:
      - ./certs:/root/certs
      - ./kes.config:/root/config/server-config.toml
      - ./keys:/keys
```

### Restart del docker compose precedente

```bash
# Stop
docker-compose down

# Start
docker-compose up -d
```

## Generare una chiave di cifratura per Minio

Generiamo una chiave con l'utente minio:

```bash
cd certs
export KES_CLIENT_TLS_CERT_FILE=minio.cert
export KES_CLIENT_TLS_KEY_FILE=minio.key
kes key create my-minio-key -k
cd -
```

Ora in `.keys` dovrebbe essere apparsa la chiave.

Dovrebbe essere tutto pronto per poter andare a https://<indirizzo pubblico Minio>:9000 creare un bucket con l'utenza `minioadmin:minioadmin`(vedi istruzioni [qui](https://docs.minio.io/docs/minio-client-quickstart-guide.html)). Tutto quello che verra' caricato nel bucket apparira' in `./data_encrypt`.

- Per configurare il client per accesso admin:

```bash
mc config host add myminio https://<indirizzo pubblico Minio>:9000 minioadmin minioadmin
```
