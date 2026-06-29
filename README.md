# Cloud and DevOps Engineering: Part II

*Aalen University  ·  Application & CI/CD Pipeline on Azure  ·  Hüseyin Simsek  ·  Summer Semester 2026*


## 1. What is this?

This project extends the infrastructure from Part I with a Flask web application and a fully automated CI/CD pipeline.
    The infrastructure itself (Resource Group, Storage Account, Key Vault, App Service Plan, Web App) is not modified — Part II only adds the application code, the pipeline, and a remote state backend on top of it.

The following is added on top of Part I:

```
- Flask web application      Lists files in Blob Storage and provides an upload form
- Remote state backend        Terraform state moved from local disk to Azure Storage
- RBAC role assignments       Managed Identity granted access to Storage and Key Vault
- Azure DevOps pipeline       Plan → Apply → Build → Deploy, fully automated
- Workload Identity Federation Pipeline authenticates to Azure without a stored secret
```


## 2. Prerequisites

The following tools must be installed before running this project:

```
- Terraform ≥ 1.5.0      https://developer.hashicorp.com/terraform/install
- Azure CLI latest        https://learn.microsoft.com/cli/azure/install-azure-cli
- Python 3.11             https://www.python.org/downloads
- Git any                 https://git-scm.com
- Azure Subscription active   A student subscription is sufficient
- Azure DevOps organization     Free tier is sufficient (for the pipeline)
```

### How to Run Locally (in PowerShell)

```
# 1. Clone the repository
git clone https://github.com/husii42/cloud-project.git
cd cloud-project

# 2. One-time: bootstrap the remote state backend
cd bootstrap
az login
terraform init
terraform apply
# note the two outputs: resource_group_name, storage_account_name
cd ..

# 3. Create the variables file and set a unique project_name
cp terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars

# 4. Initialise Terraform with the remote backend (values from step 2)
terraform init `
  -backend-config="resource_group_name=<from bootstrap output>" `
  -backend-config="storage_account_name=<from bootstrap output>" `
  -backend-config="container_name=tfstate" `
  -backend-config="key=cloud-project.tfstate"

# 5. Preview and deploy the infrastructure
terraform plan
terraform apply

# 6. Deploy the Flask application
.\scripts\deploy.ps1 -ResourceGroupName "rg-<project_name>-dev" -AppServiceName "app-<project_name>-dev"
```

For automated deployment via Azure DevOps instead of the manual script, see [`documentation/AZURE_DEVOPS_SETUP.md`](documentation/AZURE_DEVOPS_SETUP.md) for the one-time setup steps, then push to `main`.


## 3. Repository Structure

```
Test_App/
├── main.tf                    # Root module: connects all modules + RBAC role assignments
├── backend.tf                 # Remote state backend (azurerm), config supplied at init time
├── variables.tf               # Input variables (project_name, environment, location, tags)
├── outputs.tf                 # Values displayed after terraform apply
├── providers.tf               # Azure provider version and configuration
├── terraform.tfvars.example   # Template for local variables (copy to .tfvars)
├── modules/
│   ├── storage/                # Unchanged from Part I (Storage Account + images container)
│   ├── keyvault/                # RBAC-based Key Vault (replaces legacy Access Policies)
│   └── appservice/               # App Service Plan + Web App with Managed Identity & app settings
├── bootstrap/                 # Separate, one-time config: creates the Storage Account for remote state
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── application/                # The Flask web application (Part II)
│   ├── app.py                  # Routes: "/" (list files), "/upload" (upload form), "/healthz"
│   ├── requirements.txt        # Flask, gunicorn, azure-identity, azure-storage-blob
│   └── templates/               # base.html, index.html, upload.html
├── pipelines/
│   └── azure-pipelines.yml     # 3-stage pipeline: TerraformPlan → TerraformApply → DeployApp
├── scripts/
│   └── deploy.ps1              # Manual local equivalent of the pipeline's build+deploy stage
└── documentation/
    └── AZURE_DEVOPS_SETUP.md   # One-time manual setup: Service Connection, pipeline variables
```


### How the files work together

`backend.tf` points Terraform at a remote state file in Azure Storage instead of the local disk used in Part I; the actual storage account/resource group names are passed in at `terraform init` time (locally via `-backend-config`, in the pipeline via pipeline variables), so no environment-specific values are hardcoded in the repository.
    `main.tf` builds on Part I's three modules by adding two `azurerm_role_assignment` resources: one grants the Web App's Managed Identity the **Storage Blob Data Contributor** role, the other grants **Key Vault Secrets User**.
    These are placed in the root module rather than inside `modules/storage` or `modules/keyvault`, because the Managed Identity's `principal_id` does not exist until the Web App itself has been created — defining the role assignments at the root, unconditionally, lets Terraform defer them automatically instead of running into a "count cannot be determined" error.
    `modules/appservice` configures the Web App's `app_settings` with the Storage Account name, container name, and Key Vault URI; `application/app.py` reads these at runtime and uses `DefaultAzureCredential` to authenticate — first via the Managed Identity, falling back to the Azure CLI login when run locally.
    `pipelines/azure-pipelines.yml` then automates the entire flow: plan, apply, build, and deploy.


## 4. Approach & Reasoning


### Building on Part I without modifying it

As planned in Part I, none of the existing modules needed to be changed. The Storage, Key Vault, and App Service modules are reused as-is; Part II only adds the remote backend, the RBAC role assignments, the application code, and the pipeline on top.
    This confirms the benefit of the modular structure chosen in Part I: extending the project was additive rather than requiring edits to existing, already-applied resources.


### Secret-less authentication end-to-end

Part I already avoided storing the Storage Account's access key directly in application code by writing it into Key Vault and giving the App Service a System-Assigned Managed Identity.
    Part II completes this pattern: the Flask application never reads that Key Vault secret at all.
    Instead, it uses the `azure-identity` SDK's `DefaultAzureCredential`, which automatically picks up the Web App's Managed Identity when running on App Service, and falls back to the developer's `az login` session when running locally.
    Combined with the RBAC role assignments in `main.tf` (Storage Blob Data Contributor, Key Vault Secrets User), the application can list and upload blobs without a single password, connection string, or access key ever appearing in code, environment variables, or App Settings.

The same secret-less idea is extended to the pipeline: instead of a Service Principal with a client secret, the Azure DevOps Service Connection uses **Workload Identity Federation**, in which Azure DevOps exchanges a short-lived OIDC token for an Azure access token at run time.
    No credential is generated or stored anywhere for the pipeline to authenticate with Azure.

```
Identity                 Type                                  Access granted
────────────────────────────────────────────────────────────────────────────────────
Developer (az login)     Azure CLI user (Microsoft Entra)       Key Vault Administrator (RBAC)
Pipeline (OIDC)           Service Principal, Workload Identity    Contributor on the subscription
                            Federation, no stored secret
App Service                System-Assigned Managed Identity        Storage Blob Data Contributor;
                                                                       Key Vault Secrets User
```


### RBAC instead of Access Policies

Part I's Key Vault used legacy Access Policies. Part II switches the Key Vault module to `enable_rbac_authorization = true`, using `azurerm_role_assignment` resources instead.
    This keeps authorization consistent with how access to the Storage Account is granted (also via role assignments), so every identity in the project — the developer, the pipeline, and the App Service — is authorized through the same model rather than mixing two different ones.


### Remote state backend

Part I deliberately kept the Terraform state local, noting the "chicken-and-egg" problem: the Storage Account that would hold the state is itself created by the same Terraform run.
    Part II solves this with a separate `bootstrap/` configuration: a small, standalone Terraform project that is applied once, manually, purely to create a Storage Account and container for the *main* configuration's state.
    Once that exists, `backend.tf` in the main configuration points to it via `-backend-config` (kept out of the repository so no environment-specific values are committed), allowing both the developer's machine and the CI/CD pipeline to share one consistent state file instead of each having a conflicting local copy.


### Pipeline structure: Plan, Apply, Deploy

The pipeline (`pipelines/azure-pipelines.yml`) is split into three stages rather than one long script:

```
1. TerraformPlan    Runs on every push; produces a plan as a reviewable artifact
2. TerraformApply   Applies that exact plan, but only on the main branch
3. DeployApp        Builds and deploys the Flask app, only after the apply succeeds
```

Separating Plan from Apply means a `terraform plan` runs (and can be inspected) on every push without ever touching real infrastructure, and the Apply stage always applies the *exact* plan that was reviewed — not a freshly recomputed one that could have drifted.
    Gating Apply and Deploy on the `main` branch and on the previous stage's success prevents partially-applied infrastructure or deploying application code against infrastructure that failed to provision.


### Why App Service deployment instead of containers

The Flask app is deployed as a zipped folder via Azure's built-in zip-deploy / Oryx build (`SCM_DO_BUILD_DURING_DEPLOYMENT = true`), rather than as a Docker container.
    For a small, single-process Flask app with few dependencies, this avoids maintaining a Dockerfile and a container registry; Azure builds the Python environment directly from `requirements.txt` on deployment.
    The trade-off is less control over the exact runtime environment than a custom container image would give — acceptable here given the application's simplicity.


## 5. Known Limitations


### Cost

In addition to the App Service Plan (B1, ~€13/month) from Part I, the remote state Storage Account adds a small additional cost (a few cents/month for a single state file).
    If `terraform destroy` is not run after the project is complete, both the main infrastructure and the bootstrap Storage Account continue to incur charges.


### No staging environment

The pipeline applies directly to a single `dev` environment on every push to `main`.
    In a production setup, a `staging` stage with manual approval would sit between Plan and Apply so changes can be verified before reaching the environment that's actually in use.


### Pipeline approval gate

The `production` Azure DevOps environment can be configured to require manual approval before `TerraformApply` and `DeployApp` run.
    For this student project, that approval gate is optional and can be skipped — but in a team setting, it would be the main safeguard against an unreviewed change going live automatically.


### Upload validation is basic

The upload form (`application/app.py`) checks file extensions against an allow-list and limits uploads to 25 MB, but performs no virus scanning or content inspection.
    For a project storing user-uploaded files in a publicly-readable container, a production setup would add antivirus scanning (e.g. Microsoft Defender for Storage) before a file is exposed.


### No application monitoring

As in Part I, there are no alerts or Application Insights configured for the running application.
    The `/healthz` endpoint exists and is suitable for a future uptime check or pipeline smoke test, but nothing currently consumes it automatically.


### Local script vs. pipeline can drift

`scripts/deploy.ps1` duplicates the build-and-deploy logic that also lives in `pipelines/azure-pipelines.yml`, so the two could diverge over time if one is updated and not the other.
    This is accepted here since the script exists purely as a faster manual fallback during development, not as the primary deployment path.


## 6. Summary

Part II completes the project end-to-end: from `terraform apply` provisioning the infrastructure, through a Flask application that reads and writes Blob Storage using only Managed Identity (no secrets in code or configuration), to an Azure DevOps pipeline that plans, applies, builds, and deploys automatically on every push to `main` — itself authenticating via Workload Identity Federation rather than a stored credential.
    The infrastructure modules from Part I required no changes; everything in Part II was added on top.
