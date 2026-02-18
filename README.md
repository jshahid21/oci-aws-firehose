# oci-rclone-sync

Sync OCI cost reports (bling namespace) to AWS S3. Runs on a VM in OCI with rclone on a 6-hour cron.

**Stack:** OpenTofu · OCI (VCN, NAT, Vault, Compute) · Rclone

## Architecture

```
OCI bling (cost reports)  →  VM (rclone + cron)  →  AWS S3
```

- VM in private subnet, egress via NAT + Service Gateway
- Rclone uses OCI API key for bling (instance principal does not work for cost reports)
- AWS credentials for S3 write
- Sync every 6h; optional email alerts on failure

## Prerequisites

- **OpenTofu:** `brew install opentofu`
- **OCI:** `~/.oci/config` with DEFAULT profile
- **AWS:** IAM user with S3 access; keys in tfvars
- **Email:** For sync-failure alerts (optional)

## Quick Start

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: region, tenancy_ocid, compartment, aws_*, oci_api_*, etc.

tofu init
tofu apply
```

**Two-step for OCI API key:** First apply creates the `rclone-sync` user. Add an API key in Console → Identity → Users → rclone-sync → API Keys, then set `oci_api_key_fingerprint` and `oci_api_private_key` in tfvars and apply again.

## Security

**How credentials are passed to the sync VM:**

| Credential | Method | Where it lives |
|------------|--------|----------------|
| **OCI API private key** | Injected in cloud-init user_data (base64) | `terraform.tfvars` → Terraform state → instance metadata (`user_data`) → decoded at boot to `/root/.oci/key.pem` |
| **AWS access key + secret** | Injected in cloud-init user_data (base64) | `terraform.tfvars` → Terraform state → instance metadata (`user_data`) → decoded at each sync run into env vars `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |

**Implications:**
- Credentials are embedded in instance metadata. Anyone with `compute instance read` + `instance console connection` or metadata access can read them.
- Terraform state contains the values. Use a locked remote backend; avoid committing state.
- `terraform.tfvars` is gitignored. Never commit it.

**Vault alternative:** Set `inject_oci_private_key_via_cloud_init = false` and `inject_aws_credentials_via_cloud_init = false` to fetch credentials from OCI Vault at runtime via instance principal. Requires the dynamic group to have `read secret-bundles` on the compartment; in some tenancies this returns 404, so injection is the default.

## Configuration

| Variable | Required |
|----------|----------|
| `region`, `tenancy_ocid`, `existing_compartment_id` | ✓ |
| `aws_s3_bucket_name`, `aws_s3_prefix`, `aws_region` | ✓ |
| `aws_access_key`, `aws_secret_key` | ✓ (when create_aws_secrets) |
| `oci_api_key_fingerprint`, `oci_api_private_key` | ✓ (after adding API key to user) |
| `oci_rclone_user_email`, `alert_email_address` | ✓ |

## AWS IAM Policy

The IAM user needs S3 access. Example policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket"],
    "Resource": [
      "arn:aws:s3:::YOUR_BUCKET",
      "arn:aws:s3:::YOUR_BUCKET/*"
    ]
  }]
}
```

## SSH Access (Bastion)

Bastion is created by default. After apply:

```bash
ssh -J opc@<bastion_public_ip> opc@<instance_private_ip>
```

Logs: `/var/log/rclone-sync.log`

## Troubleshooting

| Issue | Action |
|-------|--------|
| `key.pem empty` | Ensure `oci_api_private_key` in tfvars is the full PEM. Taint instance and re-apply. |
| `403 Forbidden` (S3) | Add `s3:GetObject` to IAM policy (rclone uses it for HeadObject). |
| `EC2 IMDS` error | AWS keys not set. Ensure `aws_access_key`/`aws_secret_key` in tfvars and inject is enabled. |
| No bling data | Reports are in tenancy home region. Set `region` correctly; reports may take 24–48h. |
