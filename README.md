# Cloud Project – Part II
### Principles of Cloud and DevOps Engineering | Aalen University

---

## Description

A cloud application that stores and displays images in an Azure Storage
Account, using Key Vault for sensitive data. It consists of:

- **Infrastructure as Code** (Terraform) – Resource Group, Storage Account,
  Key Vault, App Service Plan, Linux Web App, all wired together with RBAC
  role assignments instead of static credentials.
- **A Flask web application** with two pages:
  - **Page 1** (`/`) – lists every blob in the Storage Account's `images`
    container with a download link, and a link to Page 2.
  - **Page 2** (`/upload`) – an upload form for files/images.
- **A CI/CD pipeline** (Azure DevOps) that plans/applies the Terraform
  configuration and then builds and deploys the Flask app to the App
  Service - authenticating to Azure via **Workload Identity Federation**
  (OIDC), with no client secret stored anywhere.

---

## Approach

Part I's modular Terraform design (one module per resource type) is
extended, not rewritten, for Part II:

- **Authentication** for local `terraform apply` still uses Azure CLI
  (`az login`). The **pipeline** instead authenticates as a Service
  Principal via **Workload Identity Federation** - a short-lived OIDC
  token is exchanged for an Azure access token at run time, so no
  client secret is ever generated, stored, or rotated.
- **Authorization** moved from Key Vault Access Policies to **RBAC role
  assignments** (`azurerm_role_assignment`), so every identity - the
  developer, the pipeline, and the App Service - is granted access the
  same, auditable way.
- **The application never sees a credential.** The Flask app uses
  `DefaultAzureCredential`, which resolves to the App Service's
  **System-Assigned Managed Identity** in Azure and to the local
  `az login` session when run locally. The Storage Account connection
  string is still written to Key Vault (kept from Part I for completeness/
  manual debugging), but nothing in the running application reads it.
- **Remote state**: Terraform's state file moved out of local disk into a
  dedicated Storage Account (`bootstrap/`), so the pipeline and any
  contributor share one consistent source of truth instead of each having
  their own copy.

---

## Architecture – Connections Between Resources

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Azure Resource Group                         │
│                                                                       │
│   ┌────────────────┐   Storage Blob Data    ┌────────────────────┐   │
│   │ Storage Account│◄───── Contributor ──────│    App Service      │  │
│   │  [images]      │       (RBAC)            │  Managed Identity   │  │
│   └───────┬────────┘                         └─────────┬──────────┘  │
│           │                                             │             │
│           │ primary key written                         │ Key Vault   │
│           │ as secret                                    │ Secrets    │
│           ▼                                              │ User (RBAC)│
│   ┌────────────────┐                                     ▼            │
│   │   Key Vault     │◄──────────────────────────────────────────────┐ │
│   │ storage-conn-str │                                              │ │
│   └────────┬─────────┘                                              │ │
│            │ Key Vault Administrator (RBAC)                          │ │
│            ▼                                                         │ │
│      Developer (az login)                                            │ │
└────────────────────────────────────────────────────────────────────────┘

Azure DevOps Pipeline ──(Workload Identity Federation / OIDC, no secret)──► Subscription (Contributor)
```

**Data flows:**
- The Flask app (`application/app.py`) calls the Storage Account's Blob
  API directly using `DefaultAzureCredential` → on App Service this
  resolves to the System-Assigned Managed Identity, authorized via the
  `Storage Blob Data Contributor` role.
- The Storage Container `images` is also public-read, so the
  download links shown on Page 1 work without any authentication.
- Terraform still writes the Storage Account's primary key into Key
  Vault as a secret (`storage-connection-string`) for completeness/manual
  debugging - the running application does not read it.
- The pipeline authenticates to Azure with a short-lived OIDC token
  (no stored secret), then runs Terraform and deploys the app package to
  the App Service.

---

## Authentication / Identity Context

| Identity | Type | Access granted |
|---|---|---|
| Developer (`az login`) | Azure CLI user (Microsoft Entra) | `Key Vault Administrator` (RBAC) on the Key Vault |
| Azure DevOps pipeline | Service Principal, **Workload Identity Federation** (OIDC, no secret) | `Contributor` on the subscription |
| App Service | System-Assigned Managed Identity | `Storage Blob Data Contributor` on the Storage Account; `Key Vault Secrets User` on the Key Vault |

Secrets are **never** stored in:
- `.tf` source files or the Git repository
- `terraform.tfvars` (listed in `.gitignore`)
- Pipeline YAML or pipeline variables (Workload Identity Federation needs none)
- Application code or App Settings (the app uses Managed Identity, not a connection string)

See [`documentation/AZURE_DEVOPS_SETUP.md`](documentation/AZURE_DEVOPS_SETUP.md)
for the one-time manual steps needed to set this up (creating the Service
Connection, granting subscription access, setting pipeline variables).

---

## Repository Structure

```
cloud-project/
├── main.tf                       # Root module – wires all modules together
├── variables.tf                  # Input variables
├── outputs.tf                    # Exported values
├── providers.tf                  # Azure provider + Terraform version
├── backend.tf                    # Remote state backend (azurerm), config supplied at init time
├── terraform.tfvars.example      # Template – copy to terraform.tfvars (git-ignored)
├── .gitignore
├── README.md
│
├── bootstrap/                    # One-time setup: creates the remote state Storage Account
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── modules/
│   ├── storage/                  # Storage Account + Container + RBAC for App Service identity
│   ├── keyvault/                 # Key Vault (RBAC authorization) + secret + role assignments
│   └── appservice/                # App Service Plan + Linux Web App + Managed Identity
│
├── application/                  # Part II Flask web application
│   ├── app.py                    # Web Page 1 (list blobs) + Web Page 2 (upload form)
│   ├── requirements.txt
│   ├── .deployment                # Enables Oryx build on App Service
│   └── templates/
│       ├── base.html
│       ├── index.html
│       └── upload.html
│
├── pipelines/
│   └── azure-pipelines.yml       # 3 stages: Terraform Plan → Terraform Apply → Build & Deploy App
│
├── scripts/
│   └── deploy.ps1                # Manual/local deployment script (PowerShell) – builds & deploys the app
│
└── documentation/
    └── AZURE_DEVOPS_SETUP.md     # One-time manual setup: Service Connection, role assignment, pipeline variables
```

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Terraform | ≥ 1.5 | https://developer.hashicorp.com/terraform/install |
| Azure CLI | latest | https://learn.microsoft.com/cli/azure/install-azure-cli |
| Python | 3.11 | https://www.python.org/downloads/ (only needed for local app testing) |
| Azure Subscription | – | Student subscription works |
| Azure DevOps organization/project | – | for the CI/CD pipeline |

---

## Getting Started (local infrastructure)

```bash
# 1. Bootstrap the remote state backend (one-time)
cd bootstrap
az login
terraform init
terraform apply
cd ..

# 2. Configure backend + variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars – set project_name, environment, location

terraform init \
  -backend-config="resource_group_name=<from bootstrap output>" \
  -backend-config="storage_account_name=<from bootstrap output>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=cloud-project.tfstate"

# 3. Preview and apply
terraform plan
terraform apply
```

## Getting Started (application, local)

```powershell
cd application
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt

$env:AZURE_STORAGE_ACCOUNT_NAME = "<storage_account_name output>"
$env:AZURE_STORAGE_CONTAINER_NAME = "images"

az login   # DefaultAzureCredential falls back to this locally

python app.py   # http://localhost:8000
```

## Deploying the application

Either let the pipeline do it (`pipelines/azure-pipelines.yml`, triggered on
push to `main`), or run it manually:

```powershell
.\scripts\deploy.ps1 -ResourceGroupName "rg-cloudproject-dev" -AppServiceName "app-cloudproject-dev"
```

---

## Naming Conventions

| Resource | Name pattern | Example |
|---|---|---|
| Resource Group | `rg-<project>-<env>` | `rg-cloudproject-dev` |
| Storage Account | `st<project><env>` | `stcloudprojectdev` |
| Key Vault | `kv-<project>-<env>` | `kv-cloudproject-dev` |
| App Service Plan | `asp-<project>-<env>` | `asp-cloudproject-dev` |
| Web App | `app-<project>-<env>` | `app-cloudproject-dev` |
| Remote state Storage Account | `sttfstate<project>` | `sttfstatecloudproject` |

---

## Notes on production timeout fix

Gunicorn's default 30-second worker timeout was occasionally too short for
cold starts on App Service (e.g. the `DefaultAzureCredential` → Managed
Identity token handshake on the very first request). The App Service's
startup command (`modules/appservice/main.tf`) sets `--timeout 600` to
give workers enough headroom, and `--workers 2` to fit the B1 plan's
single vCPU without starving requests of resources.
