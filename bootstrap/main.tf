# ─────────────────────────────────────────────────────────
# Bootstrap – Remote State Backend
# ─────────────────────────────────────────────────────────
# This is a SEPARATE, one-time Terraform configuration. It has its own
# local state (just for this bootstrap step) and creates the Storage
# Account + Container that the MAIN configuration (../) will use as
# its remote backend.
#
# Why separate? The main configuration cannot store its own state in
# a Storage Account that doesn't exist yet ("chicken-and-egg" problem).
# This is run once, manually, before the CI/CD pipeline ever runs.
#
# Usage:
#   cd bootstrap
#   terraform init
#   terraform apply
#   (copy the output values into ../backend.tf)
# ─────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "state" {
  name     = "rg-${var.project_name}-tfstate"
  location = var.location
  tags = {
    project    = "cloud-devops-engineering"
    managed_by = "terraform"
    purpose    = "terraform-remote-state"
  }
}

resource "azurerm_storage_account" "state" {
  # Storage Account names: 3-24 chars, lowercase letters + numbers only.
  # Must be globally unique - choose a unique var.project_name in variables.tf
  # (consistent with how the main configuration's Storage Account is named).
  name                     = "sttfstate${var.project_name}"
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # Sufficient redundancy for a student project's state file

  blob_properties {
    versioning_enabled = true # Keep history of state file changes, makes recovery from a bad apply possible
  }

  tags = {
    project    = "cloud-devops-engineering"
    managed_by = "terraform"
    purpose    = "terraform-remote-state"
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private" # State files can contain sensitive data - never public
}
