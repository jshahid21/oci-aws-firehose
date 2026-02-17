# OCI-to-AWS Firehose (Deprecated)

> **Deprecated:** The event-driven approach (OCI Functions + Python) has been removed.  
> **Use [oci-rclone-sync](../oci-rclone-sync)** for syncing OCI Cost and Usage Reports to AWS S3 via VM + Rclone.

## What Remains

This project now contains only **shared infrastructure** (VCN, Vault, secrets) with no consumer.

**If you have existing `terraform.tfvars`:** Remove variables `create_bucket`, `existing_bucket_namespace`, `source_bucket_name`, `create_function_app`, `existing_function_app_id`, `existing_function_id`, `function_image`, `create_event_rule`, `event_rule_display_name`, and related function vars.

The following were removed:

- Python function (`functions/`)
- OCI Function, Events rule, Dynamic Group, Policy
- OCI source bucket
- Fn CLI and Docker setup scripts

## Remaining Resources

If you have existing state, the infra still provisions:

- Compartment (optional)
- VCN, Subnet, NAT Gateway, Service Gateway
- Vault, KMS Key
- AWS credential secrets in Vault

These have no consumer. To tear down: `cd infra && tofu destroy`

---

## Migrate to oci-rclone-sync

For OCI Usage Reports (including cross-tenancy) → AWS S3:

```bash
cd ../oci-rclone-sync
# See oci-rclone-sync/README.md
```
