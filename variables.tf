# ─────────────────────────────────────────────
# Defining variables for the project
# ─────────────────────────────────────────────

variable "project_name" {
  description = "Short name used as prefix for all resources (lowercase, no spaces)"
  type        = string
  default     = "cloudproject"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "swedencentral"
}

variable "tags" { # tags is adding descriptions to the resources in Azure, so we can easily identify them and filter them in the Azure portal. We can also use tags for cost management and automation.
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    project     = "cloud-devops-engineering"
    managed_by  = "terraform"
    creator = "Simsek"
    for = "learning"
  }
}
