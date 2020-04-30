from minio import Minio
from minio.error import (ResponseError, BucketAlreadyOwnedByYou,
                         BucketAlreadyExists)
import jwt
import requests
import xmltodict
import os
import urllib3

token = os.getenv("TOKEN")

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

# Get username from token and check if a folder for the mount is ready
username = jwt.decode(token, verify=False)[
    'preferred_username'].lower().split("@")[0]
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

# Make a bucket with the make_bucket API call.
try:
    minioClient.make_bucket(username)
except BucketAlreadyOwnedByYou:
    pass
except BucketAlreadyExists:
    pass
except ResponseError as err:
    raise err

# TODO: sudo cp MINIO.pem /etc/pki/ca-trust/source/anchors/
# sudo update-ca-certificates

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


# Unmount volume if already present
myCmd = os.popen('fusermount -u /tmp/%s' % username).read()
print(myCmd)

# Mount all user buckets
myCmd = os.popen('rclone --ca-cert MINIO.pem --config %s.conf mount --daemon --vfs-cache-mode full --no-modtime %s: /tmp/%s && sleep 2' %
                 (username, username, username)).read()
print(myCmd)

# List contents of user buckets
myCmd = os.popen('ls -ltrh /tmp/%s/*/' % (username)).read()
print(myCmd)

# Unmount before exit
myCmd = os.popen('sleep 2 && fusermount -u /tmp/%s' % username).read()
print(myCmd)
