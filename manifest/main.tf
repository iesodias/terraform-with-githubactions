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