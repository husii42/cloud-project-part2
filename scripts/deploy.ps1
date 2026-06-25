<#
.SYNOPSIS
    Builds and deploys the Flask application to the Azure App Service
    created by Terraform (modules/appservice).

.DESCRIPTION
    This is the manual/local equivalent of the "BuildApp" + "DeployApp" jobs
    in pipelines/azure-pipelines.yml. Useful for quick iteration without
    waiting for the full pipeline, or if the pipeline is not available.

    Requires: Azure CLI (az), logged in (`az login`) with access to the
    target subscription/resource group.

.PARAMETER ResourceGroupName
    Resource Group containing the App Service (e.g. rg-cloudproject-dev)

.PARAMETER AppServiceName
    Name of the App Service / Web App (e.g. app-cloudproject-dev)

.EXAMPLE
    .\scripts\deploy.ps1 -ResourceGroupName "rg-cloudproject-dev" -AppServiceName "app-cloudproject-dev"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$AppServiceName
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$appDir = Join-Path $repoRoot "application"
$zipPath = Join-Path $repoRoot "app.zip"

Write-Host "==> Checking Azure CLI login..." -ForegroundColor Cyan
$account = az account show 2>$null
if (-not $account) {
    Write-Host "Not logged in. Running 'az login'..." -ForegroundColor Yellow
    az login
}

Write-Host "==> Verifying App Service exists ($AppServiceName in $ResourceGroupName)..." -ForegroundColor Cyan
$appExists = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --query "name" -o tsv 2>$null
if (-not $appExists) {
    Write-Error "App Service '$AppServiceName' not found in resource group '$ResourceGroupName'. Did you run 'terraform apply' first?"
    exit 1
}

Write-Host "==> Removing old zip (if any)..." -ForegroundColor Cyan
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Write-Host "==> Zipping application folder ($appDir)..." -ForegroundColor Cyan
# Compress-Archive zips the *contents* of -Path when it ends in \*, which is what
# Azure App Service's zip deploy expects (app.py at the zip root, not nested).
Compress-Archive -Path (Join-Path $appDir "*") -DestinationPath $zipPath -Force

Write-Host "==> Enabling build-during-deployment (Oryx)..." -ForegroundColor Cyan
az webapp config appsettings set `
    --name $AppServiceName `
    --resource-group $ResourceGroupName `
    --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true `
    --output none

Write-Host "==> Deploying to App Service (this can take a minute)..." -ForegroundColor Cyan
az webapp deploy `
    --name $AppServiceName `
    --resource-group $ResourceGroupName `
    --src-path $zipPath `
    --type zip

Write-Host "==> Cleaning up..." -ForegroundColor Cyan
Remove-Item $zipPath -Force

$hostname = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --query "defaultHostName" -o tsv
Write-Host ""
Write-Host "Deployment complete: https://$hostname" -ForegroundColor Green
Write-Host "Health check:        https://$hostname/healthz" -ForegroundColor Green
