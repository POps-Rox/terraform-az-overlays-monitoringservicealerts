
resource "azurerm_resource_group" "rg" {
  name     = "rg-alerting"
  location = "eastus"
}


module "mod_alerting" {
  depends_on = [azurerm_resource_group.rg]
  #source  = "github.com/POps-Rox/terraform-az-overlays-monitoringservicealerts"
  #version = "x.x.x"
  source = "../.."

  existing_resource_group_name   = azurerm_resource_group.rg.name
  monitoring_resource_group_name = azurerm_resource_group.rg.name
  location                       = azurerm_resource_group.rg.location
  org_name                       = var.org_name
  environment                    = var.environment
  deploy_environment             = var.deploy_environment
  workload_name                  = var.workload_name

  action_group_short_name = "Alerting"

  action_group_webhooks = {
    PagerDuty = "https://events.pagerduty.com/integration/{integration-UID}/enqueue"
    Slack     = "https://hooks.slack.com/services/{azerty}/XXXXXXXXXXXXXXx/{hook-key}"
  }

  activity_log_alerts = {
    "service-health" = {
      description         = "ServiceHealth global Subscription alerts"
      resource_group_name = azurerm_resource_group.rg.name
      scopes              = [format("/subscriptions/%s", var.subscription_id)]
      criteria = {
        category = "ServiceHealth"
      }
    }

    "security-center" = {
      custom_name         = "${var.workload_name}-global-security-center"
      description         = "Security Center global Subscription alerts"
      resource_group_name = azurerm_resource_group.rg.name
      scopes              = [format("/subscriptions/%s", var.subscription_id)]
      criteria = {
        category = "Security"
        level    = "Error"
      }
    }

    "advisor" = {
      custom_name         = "${var.workload_name}-global-advisor-alerts"
      description         = "Advisor global Subscription alerts"
      resource_group_name = azurerm_resource_group.rg.name
      scopes              = [format("/subscriptions/%s", var.subscription_id)]
      criteria = {
        category = "Recommendation"
        level    = "Informational"
      }
    }

    "managed-disks" = {
      custom_name         = "${var.workload_name}-global-managed-disks-alerts"
      description         = "Azure disks movements alerts"
      resource_group_name = azurerm_resource_group.rg.name
      scopes              = [format("/subscriptions/%s", var.subscription_id)]
      criteria = {
        category      = "Administrative"
        resource_type = "Microsoft.Compute/disks"
        level         = "Informational"
        status        = "Succeeded"
      }
    }
  }

  add_tags = {
    purpose = "alerting testing"
  }
}

