# =============================================================================
# OCI Observability - Notification Topic, Email Alerts, Logging, Alarm
# =============================================================================

# -----------------------------------------------------------------------------
# Notification Topic & Email Subscription
# -----------------------------------------------------------------------------
resource "oci_ons_notification_topic" "rclone_alerts" {
  count = var.enable_monitoring ? 1 : 0

  compartment_id = local.compartment_id
  name           = "rclone-sync-alerts"
  description    = "Alerts for rclone OCI-to-AWS sync failures"
}

resource "oci_ons_subscription" "rclone_email" {
  count = var.enable_monitoring && var.alert_email_address != "" ? 1 : 0

  compartment_id = local.compartment_id
  topic_id      = oci_ons_notification_topic.rclone_alerts[0].topic_id
  protocol      = "EMAIL"
  endpoint      = var.alert_email_address
}

# -----------------------------------------------------------------------------
# Log Group & Custom Log (for sync execution logs)
# -----------------------------------------------------------------------------
resource "oci_logging_log_group" "rclone_sync" {
  count = var.enable_monitoring ? 1 : 0

  compartment_id = local.compartment_id
  display_name   = "rclone-sync-logs"
  description    = "Log group for rclone sync execution logs"
}

resource "oci_logging_log" "rclone_execution" {
  count = var.enable_monitoring ? 1 : 0

  display_name      = "rclone-execution-log"
  log_group_id      = oci_logging_log_group.rclone_sync[0].id
  log_type          = "CUSTOM"
  retention_duration = 30
}

# -----------------------------------------------------------------------------
# IAM: Allow rclone instance (via dynamic group) to write logs and publish alerts
# -----------------------------------------------------------------------------
resource "oci_identity_policy" "rclone_logging" {
  count = var.enable_monitoring ? 1 : 0

  compartment_id = var.tenancy_ocid
  name           = "rclone-logging-policy"
  description    = "Allow rclone instance to use OCI Logging and publish to notification topic"

  statements = [
    "Allow dynamic-group rclone-dg to use log-content in compartment id ${local.compartment_id}",
    "Allow dynamic-group rclone-dg to use ons-topic in compartment id ${local.compartment_id}"
  ]
}

# -----------------------------------------------------------------------------
# Unified Agent Configuration (push /var/log/rclone-sync.log to OCI Logging)
# Requires: Oracle Cloud Agent Custom Logs plugin enabled on instance
# -----------------------------------------------------------------------------
resource "oci_logging_unified_agent_configuration" "rclone" {
  count = var.enable_monitoring ? 1 : 0

  compartment_id = local.compartment_id
  display_name   = "rclone-sync-agent-config"
  description    = "Collect /var/log/rclone-sync.log from rclone instance"
  is_enabled     = true

  group_association {
    group_list = [oci_identity_dynamic_group.rclone_dg.id]
  }

  service_configuration {
    configuration_type = "LOGGING"

    destination {
      log_object_id = oci_logging_log.rclone_execution[0].id
    }

    sources {
      name       = "rclone-sync-log"
      source_type = "LOG_SOURCE"
      paths      = ["/var/log/rclone-sync.log"]

      parser {
        parser_type = "NONE"
      }
    }
  }
}

# Log-based alerting: sync.sh publishes to the notification topic on rclone failure,
# which triggers the email subscription above. No metric alarm needed.
