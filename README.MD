## Step 1 - Gerar roles com permissao para criar os recursos no Azure

```
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
```
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
```
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