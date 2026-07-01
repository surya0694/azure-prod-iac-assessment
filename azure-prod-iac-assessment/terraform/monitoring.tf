resource "azurerm_monitor_action_group" "ops" {
  count               = var.alert_email != "" ? 1 : 0
  name                = "ag-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "opsag"
  tags                = local.tags

  email_receiver {
    name          = "primary-ops-email"
    email_address = var.alert_email
  }
}

resource "azurerm_monitor_metric_alert" "vm_availability" {
  name                = "alert-vm-availability-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_virtual_machine.web.id]
  description         = "Triggers when Azure platform VM availability drops below healthy state for 5 minutes."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "VmAvailabilityMetric"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  dynamic "action" {
    for_each = var.alert_email != "" ? [azurerm_monitor_action_group.ops[0].id] : []

    content {
      action_group_id = action.value
    }
  }
}
