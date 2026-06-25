# Azure DevOps – One-Time Setup (Authentication / Identity Context)

This document covers the steps that are **done once, manually**, before the
pipeline can run for the first time. They cannot be automated by the
pipeline itself, because the pipeline needs an identity to authenticate
with Azure *before* it can do anything else.

---

## 1. Bootstrap the remote state backend

Terraform's state file needs somewhere to live that isn't a local disk
(otherwise the pipeline and your laptop would each have their own, conflicting
copy of "the truth").

```bash
cd bootstrap
az login
terraform init
terraform apply
```

Note the two output values `resource_group_name` and `storage_account_name`.

---

## 2. Create the Azure DevOps Service Connection (Workload Identity Federation)

1. In Azure DevOps: **Project Settings → Service connections → New service connection**
2. Select **Azure Resource Manager → App registration (automatic) → Workload identity federation**
3. Choose **Subscription** as the scope level, select your subscription
4. Name it `cloud-project-connection` (matches `serviceConnection` in `pipelines/azure-pipelines.yml`)
5. Save

Azure DevOps automatically creates an App Registration / Service Principal in
Microsoft Entra ID **and** the federated credential trust — no client secret
is ever generated or stored. This is the modern replacement for the
"Service Principal with a client secret" approach.

> Why not do this in Terraform? Creating the Service Connection itself
> requires the `azuredevops` Terraform provider plus a Personal Access
> Token, which is its own secret to manage - working against the goal of
> staying secret-less. Azure DevOps' "automatic" option avoids that
> entirely, so we use it here instead of re-implementing it in HCL.

---

## 3. Grant the Service Principal access to the subscription

The new Service Principal needs permission to create/manage resources.
Find its name (same as the Service Connection name, by default) and run:

```bash
az role assignment create \
  --assignee "<service-principal-object-id-or-app-id>" \
  --role "Contributor" \
  --scope "/subscriptions/<your-subscription-id>"
```

The Object ID is visible on the Service Connection's "Manage Service
Principal" link in Azure DevOps, or in **Microsoft Entra ID → App registrations**.

---

## 4. Set pipeline variables

In Azure DevOps: **Pipelines → Edit → Variables**, add:

| Variable                  | Value                                   | Example                      |
|----------------------------|------------------------------------------|-------------------------------|
| `TF_STATE_RESOURCE_GROUP`  | output from step 1                        | `rg-cloudproject-tfstate`    |
| `TF_STATE_STORAGE_ACCOUNT` | output from step 1                        | `sttfstatecloudproject482910`|
| `RESOURCE_GROUP_NAME`      | `rg-<project_name>-<environment>`         | `rg-cloudproject-dev`        |
| `APP_SERVICE_NAME`         | `app-<project_name>-<environment>`        | `app-cloudproject-dev`       |

---

## 5. Run the pipeline

Point Azure DevOps at `pipelines/azure-pipelines.yml` and run it. The first
run will fail at `TerraformApply` if the `production` environment requires
approval - go to **Pipelines → Environments → production** to approve it
(or remove the approval check for a student project where that ceremony
isn't needed).

---

## Identity summary (for the project write-up)

| Identity                                | Type                              | Access granted |
|------------------------------------------|------------------------------------|-----------------|
| Developer (`az login`)                   | Azure CLI user (Microsoft Entra)   | Key Vault Administrator (RBAC) on the Key Vault |
| Azure DevOps pipeline                     | Service Principal, Workload Identity Federation (OIDC, no secret) | Contributor on the subscription (to run Terraform) |
| App Service                               | System-Assigned Managed Identity   | Storage Blob Data Contributor on the Storage Account; Key Vault Secrets User on the Key Vault |
