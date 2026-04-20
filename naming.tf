# Copyright (c) Microsoft Corporation.use_naming
# Licensed under the MIT License.

data "popsrox_resource_name" "action_group" {
  name          = var.workload_name
  resource_type = "azurerm_monitor_action_group"
  prefixes      = [var.org_name, var.use_location_short_name ? module.mod_azregions.location_short : module.mod_azregions.location_cli]
  suffixes      = compact([var.name_prefix == "" ? null : local.name_prefix, var.deploy_environment, local.name_suffix, var.use_naming ? "" : "ag"])
  use_slug      = var.use_naming
  clean_input   = true
  separator     = "-"
}

# Custom naming until managed by CAF provider
data "popsrox_resource_name" "activity_log_alerts" {
  for_each      = var.activity_log_alerts
  name          = var.workload_name
  resource_type = "azurerm_resource_group"
  prefixes      = [var.org_name, var.use_location_short_name ? module.mod_azregions.location_short : module.mod_azregions.location_cli]
  suffixes      = compact([var.name_prefix == "" ? null : local.name_prefix, var.deploy_environment, local.name_suffix, var.use_naming ? "" : "ala"])
  use_slug      = false # var.use_naming
  clean_input   = true
  separator     = "-"
}

# Custom naming until managed by CAF provider
data "popsrox_resource_name" "metric_alerts" {
  for_each      = var.metric_alerts
  name          = var.workload_name
  resource_type = "azurerm_resource_group"
  prefixes      = [var.org_name, var.use_location_short_name ? module.mod_azregions.location_short : module.mod_azregions.location_cli]
  suffixes      = compact([var.name_prefix == "" ? null : local.name_prefix, var.deploy_environment, local.name_suffix, var.use_naming ? "" : "ma"])
  use_slug      = false # var.use_naming
  clean_input   = true
  separator     = "-"
}
