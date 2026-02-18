# OCI-to-AWS Sync Deployment

## Prerequisites

- **OpenTofu** (or Terraform) >= 1.5
- **OCI CLI** configured (`~/.oci/config`) with sufficient privileges
- AWS S3 bucket created in the target region

## Steps

### 1. Configure Variables

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

- `region`, `tenancy_ocid`
- Network: set `create_vcn`, `create_subnet`, `create_nat_gateway`, `create_service_gateway` (or use `existing_*_id`)
- Vault: `create_vault`, `create_key`, `create_aws_secrets` (or existing IDs)
- **`aws_s3_bucket_name`**, **`aws_s3_prefix`**, **`aws_region`**
- If `create_aws_secrets = true`, provide `aws_access_key` and `aws_secret_key`
- **OCI API Key:** Cost reports use API key auth (instance principal does not work for bling). Provide `oci_api_key_fingerprint` and `oci_api_private_key` after adding an API key to the rclone-sync user.

### 2. Apply

```bash
tofu init
tofu plan
tofu apply
```

### 3. OCI API Key (two-step)

1. **First apply** creates the `rclone-sync` IAM user and group. You can use empty `oci_api_private_key` initially.
2. **Add API key:** Identity → Users → rclone-sync → API Keys → Add API Key. Generate a key pair, download the private key, copy the fingerprint.
3. **Second apply:** Add `oci_api_key_fingerprint` and `oci_api_private_key` (PEM content) to tfvars, run `tofu apply` again to store the key in Vault. The next sync (cron or manual) will use it.

### 4. Verify

- Check instance: `oci compute instance get --instance-id <instance_id>`
- SSH (via bastion) and inspect: `/var/log/rclone-sync.log`, `/usr/local/bin/sync.sh`
