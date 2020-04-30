# Setup oidc-agent per istanza IAM-demo

Oidc-agent ci aiutera' a gestire in maniera automatica e sicura i nostri Token per l'accesso ai dati.

## Requirement

- Installare oidc-agent come descritto [qui](https://indigo-dc.gitbook.io/oidc-agent/installation)
- Far partire l'agente:
```bash
eval `oidc-agent`
```

## Configurare l'account IAM-demo

Iniziamo creando il nostro account con il nome `demo`:
```bash
$ oidc-gen demo
```

Ci verra' chiesto di scegliere il nome dello issuer. Scrivere `https://iam-demo.cloud.cnaf.infn.it/` e premere invio 
```text
[1] https://iam-escape.cloud.cnaf.infn.it/
[2] https://iam-demo.cloud.cnaf.infn.it/
[3] https://accounts.google.com/
[4] https://iam-test.indigo-datacloud.eu/
[5] https://iam.deep-hybrid-datacloud.eu/
[6] https://iam.extreme-datacloud.eu/
[7] https://b2access.eudat.eu/oauth2/
[8] https://b2access-integration.fz-juelich.de/oauth2
[9] https://unity.eudat-aai.fz-juelich.de/oauth2/
[10] https://unity.helmholtz-data-federation.de/oauth2/
[11] https://login.helmholtz-data-federation.de/oauth2/
[12] https://services.humanbrainproject.eu/oidc/
[13] https://aai.egi.eu/oidc/
[14] https://aai-dev.egi.eu/oidc
[15] https://login.elixir-czech.org/oidc/
[16] https://oidc.scc.kit.edu/auth/realms/kit/
[17] https://wlcg.cloud.cnaf.infn.it/
Issuer [https://iam-escape.cloud.cnaf.infn.it/]:  https://iam-demo.cloud.cnaf.infn.it/   
```

Poi digitare `max` per richiedere tutti gli scope possibili e premere invio:

```text
This issuer supports the following scopes: openid profile email address phone offline_access
Space delimited list of scopes or 'max' [openid profile offline_access]: max
```

Ora dovrebbe apparire un messaggio del tipo:
```text
Registering Client ...
Generating account configuration ...
accepted
To continue and approve the registered client visit the following URL in a Browser of your choice:
https://iam-demo.cloud.cnaf.infn.it/authorize?response_type=code&client_id=c70edf20-51e6-3ae753c&redirect_uri=http://localhost:8080&scope=address phone openid email profile offline_access&access_type=offline&prompt=consent&state=0:BNF-HR38LjQ4MA&code_challenge_method=S256&code_challenge=brx7x6RuQI5rkzlkGwh2u2z7vCVctSlQ
```

Se non si apre in automatico una finestra nel vostro browser copiate a mano il link prodotto e inseritelo nel vostro browser.

Portate a fine il login on IAM. Se avete problemi di timeout durante il caricamento della pagina, riprovate fino a che non si apre e quando riuscite tornate al terminale.

Se la sessione e' andata in timeout, sara' apparso un messaggio del tipo:
```text
Polling oidc-agent to get the generated account configuration .......................
Polling is boring. Already tried 20 times. I stop now.
Please press Enter to try it again.
```

Fate come dice e cliccate invio. Dovrebbe essere ora andato tutto a buon fine e vi verra' chiesto di immetere una password che serve per criptare le vostre credenziali:

```text
success
The generated account config was successfully added to oidc-agent. You don't have to run oidc-add.
Enter encryption password for account configuration 'demo':
```

Inseritene una a scelta e proseguite. Il setup e' concluso. Controllate che tutto sia ok con:

```bash
$ oidc-token demo
```
```text
eyJraWQiOiJyc2ExIiwiYWxnIjoiUlMyNTYifQ.eyJzdWIiOiJlZjVmMTgzZC00ZDllLTRmMmEtOWRjNi0zZjEzNTlmMTliMzUiLCJpc3MiOiJodHRwczpcL1wvaWFtLWRlbW8uY2xvdWQuY25hZi5pbmZuLml0XC8iLCJuYW1lIjoiRGllZ28gQ2lhbmdvdHRpbmk....
```

Questo significa che il nostro agente riesce a ritirare correttamente i token dal servizio IAM.

Per avere a disposizione questo tool su ogni sessione bash, includere nel vostro profile on in bashrc:

```bash
eval `oidc-keychain`
```

Inoltre potrebbe essere necessario ricaricare l'account `demo` dopo ogni riavvio del PC. Per farlo basta:

```bash
oidc-gen --reauthenticate demo
```

e seguire la procedura proposta.
