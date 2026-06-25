output "resource_group_name" {
  description = "Name of the created Resource Group"
  value       = azurerm_resource_group.main.name
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = module.storage.storage_account_name
}

output "storage_account_primary_endpoint" {
  description = "Primary blob endpoint of the Storage Account"
  value       = module.storage.primary_blob_endpoint
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = module.keyvault.key_vault_name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = module.keyvault.key_vault_uri
}

output "app_service_plan_id" {
  description = "ID of the App Service Plan (used in Part II)"
  value       = module.appservice.app_service_plan_id
}

output "app_service_default_hostname" {
  description = "Default hostname of the App Service (used in Part II)"
  value       = module.appservice.default_hostname
}

output "app_service_name" {
  description = "Name of the App Service / Web App (for use in deployment pipeline/script)"
  value       = "app-${var.project_name}-${var.environment}"
}
