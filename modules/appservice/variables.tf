variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "storage_account_name" {
  description = "Name of the Storage Account the app reads/writes blobs from"
  type        = string
}

variable "storage_container_name" {
  description = "Name of the Blob Container the app reads/writes images to"
  type        = string
  default     = "images"
}

variable "key_vault_uri" {
  description = "URI of the Key Vault, passed to the app in case it needs to read additional secrets"
  type        = string
}
