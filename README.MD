## Step 1 - Gerar roles com permissao para criar os recursos no Azure

```powershell
az ad sp create-for-rbac --name SERVICE_PRINCIPAL --role Contributor --scopes /subscriptions/SUBSCRIPTION_ID
```

### Result:

```
{
"appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
"displayName": "Pay-As-You-Go",
"password": "xxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
"tenant": "xxxxxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxxxxxxxxx"
}

```
---

## Step 2 - Criar secrets no GithubActions

| Variables | Values|
|--------------------|-------|
|AZURE_AD_CLIENT_ID | appId |
|AZURE_AD_CLIENT_SECRET | password
|AZURE_AD_TENANT_ID | tenant |
|AZURE_SUBSCRIPTION_ID | subscription_id |
|ARM_ACCESS_KEY | StorageAccountKey |

---

## Step 3 - Criar infra para o backend

```
terraform -chdir=terraform-manifest init
terraform -chdir=terraform-manifest plan
terraform -chdir=terraform-manifest apply -auto-approve
```
## Step 4 - Criar o main.tf

main.tf
```terraform
# Configure Azure Provider
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = var.name
  location = var.region
}

resource "azurerm_storage_account" "example" {
  name                     = var.storagename
  resource_group_name      = azurerm_resource_group.example.name
  location                 = var.region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "example" {
  name                  = var.containername
  storage_account_name  = azurerm_storage_account.example.name
  container_access_type = "private"
}
```
## Step 4 - Criar arquivo de variaveis do tf

variables.tf
```terraform
variable "name" {
  type    = string
  default = "rg-terraform-github-actions-state"
}

variable "region" {
  type        = string
  description = "Azure Region where all these resources will be provisioned"
  default     = "Central US"
}

variable "storagename" {
  type    = string
  default = "terraformgithubactionsid"
}

variable "containername" {
  type    = string
  default = "tfstate"
}
```

main.tf
```terraform
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0"
    }
  }

  # Update this block with the location of your terraform state file
  backend "azurerm" {
    resource_group_name  = "rg-terraform-github-actions-state"
    storage_account_name = "terraformgithubactionsid"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}
}

# Create Resource Group 
resource "azurerm_resource_group" "my_demo_rg1" {
  location = var.location
  name     = var.name

  tags = {
    "environment"  = "k8sdev"
    "environment1" = "k8sde2v"
  }

}
```

variables.tf
```terraform
variable "name" {
  type    = string
}
variable "location" {
  type        = string
  description = "Azure Region where all these resources will be provisioned"
  default     = "Central US"
}
```

var.tfvars
```terraform
name = "#{TF_VAR_STORAGE_ACCOUNT_NAME}#"
```

```githubactions
name: 'terraform-deploy'
on: 
  push:
    branches: [ "none" ]
  workflow_dispatch:
    inputs:
      name:
        description: 'StorageAccount Name'
        required: true
        default: ''

jobs:
  TerraformApply:
    name: 'TerraformApply'
    env:
      ARM_CLIENT_ID: ${{ secrets.AZURE_AD_CLIENT_ID }}
      ARM_CLIENT_SECRET: ${{ secrets.AZURE_AD_CLIENT_SECRET }}
      ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      ARM_TENANT_ID: ${{ secrets.AZURE_AD_TENANT_ID }}
      ARM_ACCESS_KEY: ${{ secrets.ARM_ACCESS_KEY }}
      TF_VAR_STORAGE_ACCOUNT_NAME: ${{ github.event.inputs.name}}
    runs-on: ubuntu-latest
    #environment: production
 
    # Use the Bash shell regardless whether the GitHub Actions runner is ubuntu-latest, macos-latest, or windows-latest
    defaults:
      run:
        shell: bash
    steps:
    - name: Checkout
      uses: actions/checkout@v3
    - uses: cschleiden/replace-tokens@v1
      with:
        tokenPrefix: '#{'
        tokenSuffix: '}#'
        files: '["**/*.tfvars"]'
    - name: Terraform Init
      run: |
        terraform -chdir=manifest/ init
    - name: Terraform Validate
      run: terraform -chdir=manifest/ validate -no-color
    - name: Terraform Plan
      run: terraform -chdir=manifest/ plan -var-file=var.tfvars -no-color -input=false
      continue-on-error: true
    - name: Terraform Plan Status
      if: steps.plan.outcome == 'failure'
      run: exit 1
    - name: Terraform Apply
      run: terraform -chdir=manifest/ apply -var-file=var.tfvars -auto-approve -no-color -input=false
      continue-on-error: true

  TerraformDestroy:
    name: 'Terraform Destroy'
    env:
      ARM_CLIENT_ID: ${{ secrets.AZURE_AD_CLIENT_ID }}
      ARM_CLIENT_SECRET: ${{ secrets.AZURE_AD_CLIENT_SECRET }}
      ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      ARM_TENANT_ID: ${{ secrets.AZURE_AD_TENANT_ID }}
      ARM_ACCESS_KEY: ${{ secrets.ARM_ACCESS_KEY }}
      TF_VAR_STORAGE_ACCOUNT_NAME: ${{ github.event.inputs.name}}
    needs: [TerraformApply]
    environment: 
      name: EnvApproval
    runs-on: ubuntu-latest
    steps:
    - name: Checkout
      uses: actions/checkout@v3
    - uses: cschleiden/replace-tokens@v1
      with:
        tokenPrefix: '#{'
        tokenSuffix: '}#'
        files: '["**/*.tfvars"]'
    - name: Terraform Apply
      run: |
        terraform -chdir=manifest/ init
        terraform -chdir=manifest/ plan -var-file=var.tfvars -no-color
        sleep 30
        terraform -chdir=manifest/ destroy -var-file=var.tfvars -auto-approve -no-color
```