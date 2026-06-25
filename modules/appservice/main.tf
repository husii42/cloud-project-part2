# App Service Plan (the underlying compute)
resource "azurerm_service_plan" "main" {
  name                = "asp-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux" # Cheaper thgan Windows plans, and better for Python apps
  sku_name            = "B1" # Basic tier – cheapest billable plan; free tier (F1) has no always-on. Always-on is required for the app to stay responsive, so B1 is the cheapest viable option.

  tags = var.tags
}

# Web App – runs the Part II Flask application
resource "azurerm_linux_web_app" "main" {
  name                = "app-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.main.id

  # System-assigned Managed Identity so the app can access Storage and Key Vault
  # without any secrets in code or app settings (DefaultAzureCredential picks
  # this up automatically when running on App Service).
  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true

    application_stack {
      python_version = "3.11" # Part II web app uses Flask
    }

    # Gunicorn startup command:
    # --timeout 600           Azure cold-starts and the Managed Identity token
    #                          handshake (DefaultAzureCredential -> IMDS) can take
    #                          longer than gunicorn's 30s default worker timeout,
    #                          which was killing workers mid-request in production.
    # --workers 2              Small B1 plan (1 vCPU) - 2 workers is enough without
    #                          starving each other of CPU/memory.
    # --access-logfile/-error- '-'  send logs to stdout/stderr so they show up in
    #                          Azure's Log Stream instead of being lost.
    app_command_line = "gunicorn --bind=0.0.0.0:8000 --timeout 600 --workers 2 --access-logfile '-' --error-logfile '-' app:app"
  }

  # App Settings consumed by the Flask app (see application/app.py)
  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "SCM_DO_BUILD_DURING_DEPLOYMENT"       = "true" # install Python packages automatically every time the code is updated
    "AZURE_STORAGE_ACCOUNT_NAME"           = var.storage_account_name
    "AZURE_STORAGE_CONTAINER_NAME"         = var.storage_container_name
    "KEY_VAULT_URI"                        = var.key_vault_uri
  }

  tags = var.tags
}
