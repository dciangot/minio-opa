# Quick start

- Setup Oidc-agent as describe [here](Oidc.md)
- `cd examples && pip3 install --user -r requirements.txt`
- `curl https://rclone.org/install.sh | sudo bash`
- `TOKEN=`oidc-token demo` python3 rclone.py`
    - this will use the id_token provided retrieve minio credentials
    - check if the user bucket exists and create it if not
    - mount all the user buckets in /tmp/<username>
    - do some operation
    - unmount the volume and exit
