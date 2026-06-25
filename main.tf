# ─────────────────────────────────────────────
# Checking the Azure account which is logged in
# ─────────────────────────────────────────────
data "azurerm_client_config" "current" {}

# ─────────────────────────────────────────────
# Resource Group
# ─────────────────────────────────────────────
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = var.tags
}

# ─────────────────────────────────────────────
# Locals
# ─────────────────────────────────────────────
# Storage Account / Key Vault names are deterministic from project_name +
# environment (see modules/storage and modules/keyvault). Computing them here
# breaks an otherwise circular module dependency: appservice needs to know
# the Storage Account name/Key Vault URI for its app_settings, while
# storage/keyvault need appservice's Managed Identity principal_id to grant
# RBAC roles. Both sides can be satisfied without either module having to
# wait on the other's full resource creation.
locals {
  storage_account_name = "st${var.project_name}${var.environment}"
  key_vault_name        = "kv-${var.project_name}-${var.environment}"
  key_vault_uri          = "https://${local.key_vault_name}.vault.azure.net/"
}

# ─────────────────────────────────────────────
# Module: App Service
# ─────────────────────────────────────────────
module "appservice" {
  source = "./modules/appservice"

  project_name           = var.project_name
  environment             = var.environment
  location                = var.location
  resource_group_name     = azurerm_resource_group.main.name
  storage_account_name    = local.storage_account_name
  storage_container_name  = "images"
  key_vault_uri           = local.key_vault_uri
  tags                     = var.tags
}

# ─────────────────────────────────────────────
# Module: Storage Account
# ─────────────────────────────────────────────
module "storage" {
  source = "./modules/storage" # --> with source terraform knows where the code for storage account is located

  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

# ─────────────────────────────────────────────
# Module: Key Vault
# ─────────────────────────────────────────────
module "keyvault" {
  source = "./modules/keyvault"

  project_name              = var.project_name
  environment               = var.environment
  location                  = var.location
  resource_group_name       = azurerm_resource_group.main.name
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  object_id                 = data.azurerm_client_config.current.object_id
  storage_connection_string = module.storage.primary_access_key # --> we can use the output from the storage module as input for the keyvault module
  tags                      = var.tags
}

# ─────────────────────────────────────────────
# RBAC: grant the App Service's Managed Identity access to Storage and Key Vault
# ─────────────────────────────────────────────
# Defined here (root), unconditionally, rather than inside modules/storage or
# modules/keyvault with a `count` based on whether the principal_id is known
# yet: a `count` that depends on a not-yet-applied resource's computed
# attribute (azurerm_linux_web_app.main.identity[0].principal_id is unknown
# until the Web App is actually created) causes Terraform's classic
# "Invalid count argument: ... cannot be determined until apply" error on
# the very first `apply`. Without `count`, Terraform just defers these two
# resources until the Web App's identity is known - no special-casing needed.
resource "azurerm_role_assignment" "app_service_blob_contributor" {
  scope                = module.storage.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.appservice.managed_identity_principal_id
}

resource "azurerm_role_assignment" "app_service_secrets_user" {
  scope                = module.keyvault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.appservice.managed_identity_principal_id
}
