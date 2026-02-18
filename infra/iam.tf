# Dynamic Group + Cross-Tenancy Policy (Usage Report read, Vault secret read)
# Matches instances tagged Role=rclone-worker in the compartment (production-ready: tag-based, not instance-id)
resource "oci_identity_dynamic_group" "rclone_dg" {
  compartment_id = var.tenancy_ocid
  name          = "rclone-dg"
  description   = "Dynamic group for OCI-to-AWS rclone sync VM"
  matching_rule = "ALL {tag.Role.value = 'rclone-worker', instance.compartment.id = '${local.compartment_id}'}"
}

resource "oci_identity_policy" "rclone_policy" {
  compartment_id = var.tenancy_ocid  # Endorse policies must be in root compartment
  name           = "rclone-cross-tenancy-policy"
  description    = "Cross-tenancy OCI Cost Report read + Vault secret read"
  statements = [
    # Oracle-managed reporting tenancy OCID - do not change (OCI Cost Report docs)
    "Define tenancy reporting as ocid1.tenancy.oc1..aaaaaaaaned4fkpkisbwjlr56u7cj63lf3wffbilvqknstgtvzub7vhqkggq",
    "Endorse dynamic-group rclone-dg to read objects in tenancy reporting",
    "Endorse dynamic-group rclone-dg to read buckets in tenancy reporting",
    "Allow dynamic-group rclone-dg to read secret-bundles in compartment id ${local.compartment_id}"
  ]
}
