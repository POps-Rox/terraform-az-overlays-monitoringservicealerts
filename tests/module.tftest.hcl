# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

mock_provider "azurerm" {

  mock_resource "azurerm_monitor_action_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-existing-alerts/providers/Microsoft.Insights/actionGroups/ag-custom"
    }
  }

  mock_data "azurerm_resource_group" {
    defaults = {
      name     = "rg-existing-alerts"
      location = "eastus"
    }
  }
}

mock_provider "azapi" {}

mock_provider "popsrox" {
  mock_data "popsrox_resource_name" {
    defaults = {
      result = "generated-name"
    }
  }
}

variables {
  location                       = "eastus"
  monitoring_resource_group_name = "rg-monitoring-fallback"
  existing_resource_group_name   = "rg-existing-alerts"
  action_group_short_name        = "alerts"
  org_name                       = "contoso"
  workload_name                  = "payments"
  deploy_environment             = "test"
  environment                    = "public"
  default_tags_enabled           = true
  add_tags = {
    owner = "platform"
  }
}

run "existing_resource_group_and_alert_mapping" {
  command = apply

  override_module {
    target = module.mod_azregions
    outputs = {
      location_cli   = "eastus"
      location_short = "eus"
    }
  }

  variables {
    custom_action_group_name = "ag-custom"
    action_group_webhooks = {
      PagerDuty = "https://example.invalid/pagerduty"
    }
    action_group_emails = {
      Ops = "ops@example.invalid"
    }
    activity_log_alerts = {
      advisor = {
        description = "Advisor recommendations"
        scopes      = ["/subscriptions/00000000-0000-0000-0000-000000000000"]
        criteria = {
          category = "Recommendation"
          level    = "Informational"
        }
      }
      custom = {
        custom_name         = "activity-custom"
        description         = "Custom activity alert"
        resource_group_name = "rg-activity"
        scopes              = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-activity"]
        criteria = {
          category      = "Administrative"
          level         = "Error"
          resource_type = "Microsoft.Compute/virtualMachines"
          status        = "Succeeded"
        }
      }
    }
    metric_alerts = {
      cpu = {
        custom_name              = "metric-custom"
        description              = "CPU alert"
        resource_group_name      = "rg-metric"
        scopes                   = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-metric/providers/Microsoft.Compute/virtualMachines/vm1"]
        enabled                  = false
        auto_mitigate            = false
        severity                 = 2
        frequency                = "PT1M"
        window_size              = "PT5M"
        target_resource_type     = "Microsoft.Compute/virtualMachines"
        target_resource_location = "westus2"
        tags = {
          service = "payments"
          owner   = "service-team"
        }
        criteria = [{
          metric_namespace = "Microsoft.Compute/virtualMachines"
          metric_name      = "Percentage CPU"
          aggregation      = "Average"
          operator         = "GreaterThan"
          threshold        = 80
          dimension = [{
            name   = "VMName"
            values = ["vm1"]
          }]
        }]
      }
    }
  }

  assert {
    condition     = azurerm_monitor_action_group.action_group_notification.name == "ag-custom"
    error_message = "custom_action_group_name must override generated action group names."
  }

  assert {
    condition     = azurerm_monitor_action_group.action_group_notification.resource_group_name == "rg-existing-alerts"
    error_message = "when create_alerts_resource_group is false, resources must use the existing resource group data source."
  }

  assert {
    condition     = azurerm_monitor_action_group.action_group_notification.tags.owner == "platform" && azurerm_monitor_action_group.action_group_notification.tags.environment == "public" && azurerm_monitor_action_group.action_group_notification.tags.workload == "payments"
    error_message = "action group tags must merge default tags with add_tags."
  }

  assert {
    condition     = azurerm_monitor_action_group.action_group_notification.webhook_receiver[0].name == "PagerDuty" && azurerm_monitor_action_group.action_group_notification.webhook_receiver[0].service_uri == "https://example.invalid/pagerduty" && azurerm_monitor_action_group.action_group_notification.webhook_receiver[0].use_common_alert_schema == true
    error_message = "webhook receivers must map action_group_webhooks into common-schema webhook_receiver blocks."
  }

  assert {
    condition     = azurerm_monitor_action_group.action_group_notification.email_receiver[0].name == "Ops" && azurerm_monitor_action_group.action_group_notification.email_receiver[0].email_address == "ops@example.invalid" && azurerm_monitor_action_group.action_group_notification.email_receiver[0].use_common_alert_schema == true
    error_message = "email receivers must map action_group_emails into common-schema email_receiver blocks."
  }

  assert {
    condition     = azurerm_monitor_activity_log_alert.activity_log_alert["custom"].name == "activity-custom" && azurerm_monitor_activity_log_alert.activity_log_alert["custom"].resource_group_name == "rg-activity"
    error_message = "activity log alert custom names and per-alert resource group overrides must be honored."
  }

  assert {
    condition     = azurerm_monitor_activity_log_alert.activity_log_alert["advisor"].resource_group_name == "rg-monitoring-fallback"
    error_message = "activity log alerts without per-alert resource_group_name must fall back to monitoring_resource_group_name."
  }

  assert {
    condition     = azurerm_monitor_activity_log_alert.activity_log_alert["advisor"].location == "global"
    error_message = "activity log alerts must keep the provider-required global location."
  }

  assert {
    condition     = azurerm_monitor_activity_log_alert.activity_log_alert["custom"].criteria[0].category == "Administrative" && azurerm_monitor_activity_log_alert.activity_log_alert["custom"].criteria[0].resource_type == "Microsoft.Compute/virtualMachines" && one(azurerm_monitor_activity_log_alert.activity_log_alert["custom"].action).action_group_id == azurerm_monitor_action_group.action_group_notification.id
    error_message = "activity log alert criteria and action group mapping must match input."
  }

  assert {
    condition     = azurerm_monitor_metric_alert.metric_alert["cpu"].name == "metric-custom" && azurerm_monitor_metric_alert.metric_alert["cpu"].resource_group_name == "rg-metric" && azurerm_monitor_metric_alert.metric_alert["cpu"].enabled == false && azurerm_monitor_metric_alert.metric_alert["cpu"].auto_mitigate == false
    error_message = "metric alert name, resource group, enabled, and auto_mitigate mappings must match input."
  }

  assert {
    condition     = azurerm_monitor_metric_alert.metric_alert["cpu"].target_resource_type == "Microsoft.Compute/virtualMachines" && azurerm_monitor_metric_alert.metric_alert["cpu"].target_resource_location == "westus2"
    error_message = "metric alert target resource type and location must pass through unchanged."
  }

  assert {
    condition     = azurerm_monitor_metric_alert.metric_alert["cpu"].criteria[0].metric_name == "Percentage CPU" && azurerm_monitor_metric_alert.metric_alert["cpu"].criteria[0].dimension[0].name == "VMName" && one(azurerm_monitor_metric_alert.metric_alert["cpu"].action).action_group_id == azurerm_monitor_action_group.action_group_notification.id
    error_message = "metric alert criteria, dimensions, and action group mapping must match input."
  }

  assert {
    condition     = azurerm_monitor_metric_alert.metric_alert["cpu"].tags.owner == "service-team" && azurerm_monitor_metric_alert.metric_alert["cpu"].tags.service == "payments" && azurerm_monitor_metric_alert.metric_alert["cpu"].tags.workload == "payments"
    error_message = "metric alert tags must merge default tags, add_tags, and per-alert tags with per-alert precedence."
  }
}

run "empty_string_custom_names_fall_through" {
  command = apply

  override_module {
    target = module.mod_azregions
    outputs = {
      location_cli   = "eastus"
      location_short = "eus"
    }
  }

  variables {
    custom_action_group_name = ""
    activity_log_alerts = {
      generated = {
        custom_name = ""
        scopes      = ["/subscriptions/00000000-0000-0000-0000-000000000000"]
        criteria = {
          category = "Recommendation"
        }
      }
    }
    metric_alerts = {
      generated = {
        custom_name = ""
        scopes      = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1"]
        criteria = [{
          metric_namespace = "Microsoft.Compute/virtualMachines"
          metric_name      = "Percentage CPU"
          aggregation      = "Average"
          operator         = "GreaterThan"
          threshold        = 80
        }]
      }
    }
  }

  assert {
    condition     = azurerm_monitor_action_group.action_group_notification.name == "generated-name"
    error_message = "empty custom_action_group_name must fall through to generated action group name."
  }

  assert {
    condition     = azurerm_monitor_activity_log_alert.activity_log_alert["generated"].name == "generated-name"
    error_message = "empty activity_log_alerts custom_name must fall through to generated alert name."
  }

  assert {
    condition     = azurerm_monitor_metric_alert.metric_alert["generated"].name == "generated-name"
    error_message = "empty metric_alerts custom_name must fall through to generated alert name."
  }
}

run "created_resource_group_path" {
  command = apply

  override_module {
    target = module.mod_azregions
    outputs = {
      location_cli   = "westus2"
      location_short = "wus2"
    }
  }

  override_module {
    target = module.mod_scaffold_rg
    outputs = {
      resource_group_name = "rg-created-alerts"
    }
  }

  variables {
    create_alerts_resource_group = true
    location                     = "westus2"
  }

  assert {
    condition     = azurerm_monitor_action_group.action_group_notification.resource_group_name == "rg-created-alerts"
    error_message = "when create_alerts_resource_group is true, resources must use the scaffolded resource group module output."
  }
}

run "disabled_scaffold_path_uses_existing_rg" {
  command = apply

  override_module {
    target = module.mod_azregions
    outputs = {
      location_cli   = "eastus"
      location_short = "eus"
    }
  }

  override_module {
    target = module.mod_scaffold_rg
    outputs = {
      resource_group_name = "rg-created-alerts"
    }
  }

  variables {
    create_alerts_resource_group = false
  }

  assert {
    condition     = azurerm_monitor_action_group.action_group_notification.resource_group_name == "rg-existing-alerts"
    error_message = "when create_alerts_resource_group is false, scaffolded resource group output must not be used."
  }
}
