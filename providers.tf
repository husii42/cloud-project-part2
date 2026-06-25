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
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true # to delete the key valut immediately when we run terraform destroy, instead of having to wait for 90 days until it is permanently deleted. This is useful for testing and development purposes, but should be used with caution in production environments.
      recover_soft_deleted_key_vaults = true # to recover the key vault if it is accidentally deleted. This is useful for testing and development purposes, but should be used with caution in production environments.
    }
  }
}
