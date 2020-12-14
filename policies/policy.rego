package httpapi.authz
import input

default allow = false

# role-permissions assignments
rl_permissions := {
    "user": [{"action": "s3:CreateBucket"},
             {"action": "s3:DeleteBucket"},
             {"action": "s3:PutObjectLegalHold"},
             {"action": "s3:PutObjectRetention"},
             {"action": "s3:DeleteObject"},
             {"action": "s3:GetObject"},
             {"action": "s3:ListAllMyBuckets"},
             {"action": "s3:GetBucketObjectLockConfiguration"},
             {"action": "s3:GetBucketLocation"},
             {"action": "s3:ListBucket"},
             {"action": "s3:PutObject"}],
    "scratch": [{"action": "s3:ListAllMyBuckets"},
                {"action": "s3:GetObject"},
                {"action": "s3:ListBucket" }],
    "admin": [{"action": "admin:ServerTrace"},
             {"action": "s3:PutObjectLegalHold"},
             {"action": "s3:PutObjectRetention"},
             {"action": "s3:CreateBucket"},
             {"action": "s3:GetBucketLocation"},
             {"action": "s3:DeleteBucket"},
             {"action": "s3:DeleteBucket"},
             {"action": "s3:DeleteObject"},
             {"action": "s3:GetObject"},
             {"action": "s3:ListAllMyBuckets"},
             {"action": "s3:ListBucket"},
             {"action": "s3:PutObject"}],
}

allowed_issuer := "https://dodas-iam.cloud.cnaf.infn.it/"

allow {
  input.claims.iss == allowed_issuer
  permissions := rl_permissions["admin"]
  p := permissions[_]
  p == {"action": input.action}
}