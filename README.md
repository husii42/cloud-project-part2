# Cloud & DevOps Engineering — Part II
### Aalen University · Hüseyin Simsek

## What this project does

This project implements a small cloud application — storing and
displaying images in an Azure Storage Account, with Key Vault for
sensitive data — together with the infrastructure and CI/CD pipeline that
deploy it. It was built in two parts:

- **Part I** (prior submission): the Terraform infrastructure foundation —
  Resource Group, Storage Account, Key Vault, and an App Service prepared
  with a Managed Identity.
- **Part II** (this submission): a working Flask web application, a
  CI/CD pipeline that builds and deploys it, and the additional Terraform
  resources (RBAC role assignments, a remote state backend) needed to run
  that pipeline securely.

The end result is a live web app with two pages:

- **Page 1** — lists every file currently stored in Azure Blob Storage,
  with a download link for each.
- **Page 2** — an upload form to add new files/images.

Both pages talk to Azure Storage using the App Service's **Managed
Identity** — no connection string or access key is ever read by the
running application.

## How it's deployed

Infrastructure is defined in Terraform and applied either locally or
through an **Azure DevOps pipeline**. The pipeline authenticates to Azure
using **Workload Identity Federation** (OIDC) — there is no client secret
stored anywhere in this repository or in Azure DevOps. On every push to
`main`, the pipeline plans and applies the Terraform configuration, then
builds and deploys the Flask application to the App Service.

## Repository structure

```
.
├── main.tf, variables.tf, outputs.tf, providers.tf, backend.tf
│                              # Root Terraform module
├── bootstrap/                  # One-time setup: remote state Storage Account
├── modules/
│   ├── storage/                 # Storage Account + container
│   ├── keyvault/                 # Key Vault (RBAC) + secret
│   └── appservice/                # App Service Plan + Web App + Managed Identity
├── application/                # Flask web application (Page 1 + Page 2)
├── pipelines/
│   └── azure-pipelines.yml      # Terraform Plan → Apply → Build & Deploy
├── scripts/
│   └── deploy.ps1                # Manual/local deployment script
└── documentation/
    └── AZURE_DEVOPS_SETUP.md     # One-time manual Service Connection setup
```

## Where to read more

| Document | Covers |
|---|---|
| [`SETUP_GUIDE.md`](SETUP_GUIDE.md) / `.html` | Complete step-by-step instructions, from an empty subscription to a live, pipeline-deployed app — including troubleshooting for the issues actually hit while building this |
| [`ARCHITECTURE_RATIONALE.md`](ARCHITECTURE_RATIONALE.md) / `.html` | Why the infrastructure and pipeline are designed the way they are — the reasoning and trade-offs behind each decision |
| [`documentation/AZURE_DEVOPS_SETUP.md`](documentation/AZURE_DEVOPS_SETUP.md) | The one-time manual steps to set up the Azure DevOps Service Connection |
| `documentation.html` | Part I write-up (infrastructure foundation) |
| `documentation-part2.html` | Part II write-up (application, identity, pipeline) |

## Quick start

```powershell
# 1. Bootstrap remote state (one-time)
cd bootstrap && terraform init && terraform apply

# 2. Apply the main infrastructure
cd ..
terraform init -backend-config="resource_group_name=..." -backend-config="storage_account_name=..." -backend-config="container_name=tfstate" -backend-config="key=cloud-project.tfstate"
terraform apply

# 3. Deploy the app
.\scripts\deploy.ps1 -ResourceGroupName "rg-<project>-dev" -AppServiceName "app-<project>-dev"
```

See `SETUP_GUIDE.md` for the full version of these steps, including the
Azure DevOps pipeline setup and the pitfalls worth knowing about in
advance (most importantly: pick one `project_name` and use it
consistently everywhere — locally and in the pipeline).
