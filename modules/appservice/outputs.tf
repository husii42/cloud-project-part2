output "app_service_plan_id" {
  value = azurerm_service_plan.main.id
}

output "default_hostname" {
  value = azurerm_linux_web_app.main.default_hostname
}

output "web_app_id" {
  value = azurerm_linux_web_app.main.id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the Web App's Managed Identity (used to grant Key Vault access in Part II)"
  value       = azurerm_linux_web_app.main.identity[0].principal_id
}
