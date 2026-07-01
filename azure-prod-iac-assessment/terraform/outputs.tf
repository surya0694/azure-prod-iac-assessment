output "resource_group_name" {
  description = "Name of the resource group."
  value       = azurerm_resource_group.main.name
}

output "public_ip_address" {
  description = "Public IP address of the HTTPS service."
  value       = azurerm_public_ip.web.ip_address
}

output "https_url" {
  description = "HTTPS endpoint for the service health page."
  value       = "https://${azurerm_public_ip.web.ip_address}/healthz"
}

output "vm_name" {
  description = "Linux VM name."
  value       = azurerm_linux_virtual_machine.web.name
}

output "key_vault_name" {
  description = "Azure Key Vault name."
  value       = azurerm_key_vault.main.name
}

output "vm_availability_alert_name" {
  description = "Azure Monitor metric alert name."
  value       = azurerm_monitor_metric_alert.vm_availability.name
}
