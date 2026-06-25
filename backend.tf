# ─────────────────────────────────────────────────────────
# Remote State Backend
# ─────────────────────────────────────────────────────────
# Storage Account + Container are created once by ../bootstrap.
# Values are intentionally left blank here and supplied at `terraform init`
# time via -backend-config (locally) or via the pipeline (CI/CD), so that
# no environment-specific values are hardcoded in the repository.
#
# Local usage:
#   terraform init \
#     -backend-config="resource_group_name=<from bootstrap output>" \
#     -backend-config="storage_account_name=<from bootstrap output>" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=cloud-project.tfstate"
#
# In the pipeline this is supplied via the AzureDevOps Terraform task /
# explicit -backend-config args using pipeline variables, never committed.
# ─────────────────────────────────────────────────────────

terraform {
  backend "azurerm" {}
}
