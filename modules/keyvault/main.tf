resource "azurerm_key_vault" "main" {
  # Key Vault names: 3-24 chars, alphanumeric + hyphens
  name                       = "kv-${var.project_name}-${var.environment}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard" # Cheapest SKU, sufficient for this demo
  soft_delete_retention_days = 7          # Minimum retention period for soft-deleted vaults, required by Azure (cannot be set to 0 or disabled).
  purge_protection_enabled   = false      # For university exercises, we disable purge protection to allow quick cleanup. In production, you would likely want to enable it for better security.

  # RBAC instead of (legacy) Access Policies: permissions are managed centrally
  # via Azure role assignments (azurerm_role_assignment), consistent with how
  # access to the Storage Account is granted in Part II. This also means any
  # future identity (CI/CD Service Principal, additional team members) is
  # granted access the same way, instead of mixing two authorization models.
  enable_rbac_authorization = true

  tags = var.tags
}

# Grant the current user (e.g. the developer running `az login` / `terraform apply`)
# the built-in "Key Vault Administrator" role so they can manage secrets/keys directly.
resource "azurerm_role_assignment" "current_user_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.object_id
}

# Store the Storage Account connection string as a secret (kept for completeness /
# local debugging). The App Service itself does NOT use this secret - it accesses
# Storage directly via its Managed Identity and RBAC (see modules/storage and
# modules/appservice), which is the more secure, secret-less pattern.
resource "azurerm_key_vault_secret" "storage_connection_string" {
  name         = "storage-connection-string"
  value        = var.storage_connection_string
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.current_user_admin]
}
