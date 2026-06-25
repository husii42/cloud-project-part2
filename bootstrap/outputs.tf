output "resource_group_name" {
  description = "Name of the Resource Group holding the remote state Storage Account"
  value       = azurerm_resource_group.state.name
}

output "storage_account_name" {
  description = "Name of the Storage Account used as the Terraform remote state backend"
  value       = azurerm_storage_account.state.name
}

output "container_name" {
  description = "Name of the Blob Container used to store the .tfstate file"
  value       = azurerm_storage_container.tfstate.name
}

output "backend_config_snippet" {
  description = "Copy this into the backend block in providers.tf / backend.tf of the main configuration"
  value       = <<-EOT
    terraform {
      backend "azurerm" {
        resource_group_name = "${azurerm_resource_group.state.name}"
        storage_account_name = "${azurerm_storage_account.state.name}"
        container_name       = "${azurerm_storage_container.tfstate.name}"
        key                  = "cloud-project.tfstate"
      }
    }
  EOT
}
