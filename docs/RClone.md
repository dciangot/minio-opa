# Quick start

Per questo quick-start usiamo un deployment gia' pronto installato come descritto [qui]("Encryption.md"). Raggiungibile a `https://131.154.97.121:9001/`

- Setup Oidc-agent as describe [here](Oidc.md)
- `cd examples && pip3 install --user -r requirements.txt`
- `curl https://rclone.org/install.sh | sudo bash`
- `TOKEN=`oidc-token demo` python3 rclone.py`
    - this will use the id_token provided retrieve minio credentials
    - check if the user bucket exists and create it if not
    - mount all the user buckets in /tmp/<username>
    - do some operation
    - unmount the volume (opional and commented) and exit

## Code walk-through

First of all you have to get your IAM token from oidc-agent and put it into `TOKEN` env variable.

```bash
export TOKEN=`oidc-token demo`
```

then in the python code you can recall it with:

```python
import os

token = os.getenv("TOKEN")
```

Now you need to use this token to retrieve your Minio S3 temporary credentials. 
One way to do this is as follows:

```python
import requests
import xmltodict


r = requests.post("https://131.154.97.121:9001",
                  data={
                      'Action':
                      "AssumeRoleWithWebIdentity",
                      'Version': "2011-06-15",
                      'WebIdentityToken': token,
                      'DurationSeconds': 900
                  },
                  verify='MINIO.pem')

print(r.status_code, r.reason)

tree = xmltodict.parse(r.content)

credenstials = dict(tree['AssumeRoleWithWebIdentityResponse']
                    ['AssumeRoleWithWebIdentityResult']['Credentials'])
```

You have now a set of valid credentials composed by an accessID, a secret, and a session token:

```python
print("accessID:", credenstials['AccessKeyId'])
print("secret:", credenstials['SecretAccessKey'])
print("session token:", credenstials['SessionToken'])
```

Now before mounting your bucket with RClone, you might want to check if the bucket with your username exists, and in case not, to create one. You can do it easily with the MINIO python APIs:

```python
import jwt
from minio import Minio
from minio.error import (ResponseError, BucketAlreadyOwnedByYou,
                         BucketAlreadyExists)

# Get username from your token
username = jwt.decode(token, verify=False)[
    'preferred_username'].lower().split("@")[0]

# Prepare the local directory, where you will mount your bucket
directory = "/tmp/" + username
if not os.path.exists(directory):
    os.makedirs(directory)

# Initialize Minio client
minioClient = Minio(
    '131.154.97.121:9001',
    access_key=credenstials['AccessKeyId'],
    secret_key=credenstials['SecretAccessKey'],
    session_token=credenstials['SessionToken'],
    secure=True,
    http_client=urllib3.PoolManager(
        timeout=urllib3.Timeout.DEFAULT_TIMEOUT,
        cert_reqs='CERT_REQUIRED',
        ca_certs="MINIO.pem",
    )
)

# Make a bucket with the make_bucket API call. Skip if already exists
try:
    minioClient.make_bucket(username)
except BucketAlreadyOwnedByYou:
    pass
except BucketAlreadyExists:
    pass
except ResponseError as err:
    raise err
```

Now we are ready to configure RClone with our endpoint and credentials as follow:

```python
# Write rclone config file in $PWD/<username>.conf
config = """
[%s]
type = s3
provider = Minio
env_auth = true
access_key_id =
secret_access_key =
session_token =
endpoint = https://%s:9001
""" % (
    username,

    '131.154.97.121'
)

with open("%s.conf" % username, "w") as conf_file:
    conf_file.write(config)

# Set env vars with credentials
os.environ['AWS_ACCESS_KEY'] = credenstials['AccessKeyId']
os.environ['AWS_SECRET_KEY'] = credenstials['SecretAccessKey']
os.environ['AWS_SESSION_TOKEN'] = credenstials['SessionToken']

print("export AWS_ACCESS_KEY=%s" % credenstials['AccessKeyId'])
print("export AWS_SECRET_KEY=%s" % credenstials['SecretAccessKey'])
print("export AWS_SESSION_TOKEN=%s" % credenstials['SessionToken'])
```

Before mounting our volume, let's check if there is anything mounted and in case umounting it:

```python
# Unmount volume if already present
myCmd = os.popen('fusermount -u /tmp/%s' % username).read()
print(myCmd)
```

It's all set now. Let's mount our volume and access data on it just like a normal posix:

```python
# Mount all user buckets
myCmd = os.popen('rclone --ca-cert MINIO.pem --config %s.conf mount --daemon --vfs-cache-mode full --no-modtime %s: /tmp/%s && sleep 2' %
                 (username, username, username)).read()
print(myCmd)

# List contents of user buckets
myCmd = os.popen('ls -ltrh /tmp/%s/*/' % (username)).read()
print(myCmd)

# Write a posix file
filename = "%s.txt" % uuid.uuid1()
with open( "/tmp/%s/%s/%s" % (username,username,filename) , "w") as text_file:
    text_file.write("the file name is %s \n\n" % filename)
    text_file.write("and the file has been created by %s \n\n" % username)
```

That's it. Now you can exit and start doing thing with your mounted volume. 
> N.B. Be careful though, your credentials are limited to 1h, after that you need to unmount and remount with new credentials.
> There is a PR that is in preparation to make RClone talk with oidc-agent for an automatic refresh of the credentials.

# Unmount the volume

```bash
fusermount -u <path to your volume>
```