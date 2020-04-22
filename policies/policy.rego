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


allow {
  input.account == "minioadmin"
  permissions := rl_permissions["user"]
  p := permissions[_]
  p == {"action": input.action}
}

# Allow users to manage their own data.
allow {
  username := split(lower(input.claims.email),"@")[0]
  input.bucket == username
  input.claims.aud == "minio-cnaf"
  permissions := rl_permissions["user"]
  p := permissions[_]
  p == {"action": input.action}
}

allow {
  username := split(lower(input.claims.email),"@")[0]

  ref := input.conditions.Referer[_]

  url := concat("/", ["^http://.*:9000/minio/scratch",username,".*$"] )

  re_match( url , ref)

  input.claims.aud == "minio-cnaf"
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
