output "resource_group_name" {
  description = "Name of the CloudTwin Azure resource group."
  value       = azurerm_resource_group.this.name
}

output "vnet_id" {
  description = "ID of the CloudTwin virtual network."
  value       = azurerm_virtual_network.this.id
}

output "subnet_id" {
  description = "ID of the CloudTwin subnet (10.1.1.0/24)."
  value       = azurerm_subnet.this.id
}

output "nsg_id" {
  description = "ID of the network security group attached to the subnet."
  value       = azurerm_network_security_group.this.id
}

output "storage_account_name" {
  description = "Name of the storage account holding Terraform state and DB backups."
  value       = azurerm_storage_account.this.name
}

output "backups_container_name" {
  description = "Name of the private container for DB backups."
  value       = azurerm_storage_container.backups.name
}

output "acr_login_server" {
  description = "Login server of the Azure Container Registry (null when enable_acr = false)."
  value       = var.enable_acr ? azurerm_container_registry.this[0].login_server : null
}

output "vm_public_ip" {
  description = "Public IP of the DR VM (null when enable_vm = false)."
  value       = var.enable_vm ? azurerm_public_ip.vm[0].ip_address : null
}

output "vm_id" {
  description = "ID of the DR VM (null when enable_vm = false)."
  value       = var.enable_vm ? azurerm_linux_virtual_machine.this[0].id : null
}

output "log_analytics_workspace_id" {
  description = "Workspace ID of the Log Analytics workspace for Azure Monitor."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.name
}
