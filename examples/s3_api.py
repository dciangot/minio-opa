from minio import Minio
from minio.error import (ResponseError, BucketAlreadyOwnedByYou,
                         BucketAlreadyExists)
import jwt
import requests
import xmltodict
import os
import urllib3
import uuid
import io

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

buckets = minioClient.list_buckets()

for bucket in buckets:
    print(bucket.name, bucket.creation_date)

#uniq file name just for lazy testing
filename = "%s.txt" % uuid.uuid1()

#put a object in a sub-directory of the bucket
try:
    with open('requirements.txt', 'rb') as file_data:
        file_stat = os.stat('requirements.txt')
        minioClient.put_object( username, 'my_object/test_objec_%s' % filename, file_data, file_stat.st_size)
except ResponseError as err:
    print(err)

# streaming data to a directory within the bucket
data = "I want to stream some test to minio"
data_bytes = data.encode('utf-8')
data_stream = io.BytesIO(data_bytes)

try:
    minioClient.put_object(username, "my_stream/test_stream_%s" % filename, data_stream , len(data_bytes))
except Exception as ex:
    raise ex
