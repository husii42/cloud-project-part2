variable "project_name" {
  description = "Short name used as prefix for the remote state resources (lowercase, no spaces). Must be globally unique across Azure, since it becomes part of a Storage Account name (sttfstate<project_name>)."
  type        = string
  default     = "cloudproject"
}

variable "location" {
  description = "Azure region for the remote state resources"
  type        = string
  default     = "swedencentral"
}
