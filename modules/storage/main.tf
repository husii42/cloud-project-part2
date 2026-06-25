resource "azurerm_storage_account" "main" {
  # Storage Account names: 3-24 chars, lowercase letters + numbers only
  name                     = "st${var.project_name}${var.environment}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard" # Cheapest version
  account_replication_type = "LRS" # Cheaper than e.g. GRS, but no geo-redundancy (not needed for this demo)

  # Required for blob storage used by the web app in Part II
  blob_properties {
    cors_rule {
      allowed_headers    = ["*"]
      # Currently allows GET, POST and PUT from any origin.
      # Upload authentication (who can upload) is handled at application level in Part II – not at infrastructure level.
      # In production, you would likely want to restrict allowed methods and origins more tightly.
      allowed_methods    = ["GET", "POST", "PUT"]
      allowed_origins    = ["*"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }
  }

  tags = var.tags
}

# Container for image uploads (used in Part II)
resource "azurerm_storage_container" "images" {
  name                  = "images"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "blob" # Public read for blobs (images accessible via URL)
}
