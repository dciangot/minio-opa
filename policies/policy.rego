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

allow {
  input.account == "minioadmin"
}


# Allow users to manage their own data.
allow {
  username := split(lower(input.claims.preferred_username),"@")[0]
  input.bucket == username
  input.claims.iss == "https://iam-demo.cloud.cnaf.infn.it/"
  permissions := rl_permissions["user"]
  p := permissions[_]
  p == {"action": input.action}
}

allow {
  username := input.claims.preferred_username
  input.bucket == username
  input.claims.iss == "https://iam-demo.cloud.cnaf.infn.it/"
  permissions := rl_permissions["user"]
  p := permissions[_]
  p == {"action": input.action}
}

allow {
  username := input.claims.preferred_username
  input.bucket == username
  input.claims.iss == "https://iam-demo.cloud.cnaf.infn.it/"
  permissions := rl_permissions["user"]
  p := permissions[_]
  p == {"action": input.action}
}

allow {
  username := split(lower(input.claims.preferred_username),"@")[0]

  ref := input.conditions.Referer[_]

  url := concat("/", ["^http://.*:9000/minio/scratch",username,".*$"] )

  re_match( url , ref)

  input.claims.iss == "https://iam-demo.cloud.cnaf.infn.it/"
  permissions := rl_permissions["user"]
  p := permissions[_]
  p == {"action": input.action}
}

allow {
  username := input.claims.preferred_username

  ref := input.conditions.Referer[_]

  url := concat("/", ["^http://.*:9000/minio/scratch",username,".*$"] )

  re_match( url , ref)

  input.claims.iss == "https://iam-demo.cloud.cnaf.infn.it/"
  permissions := rl_permissions["user"]
  p := permissions[_]
  p == {"action": input.action}
}

# Allow to retrieve and see data from other users in scratch area
allow {
  input.bucket == "scratch"
  permissions := rl_permissions["scratch"]
  p := permissions[_]
  # check if the permission granted to r matches the user's request
  p == {"action": input.action}
}