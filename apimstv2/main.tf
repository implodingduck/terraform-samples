terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.39.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
    azapi = {
      source = "azure/azapi"
      version = "=1.1.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

locals {
  func_name = "func${random_string.unique.result}"
  location = "eastus"
  gh_repo = "terraform-samples"
  tags = {
    "managed_by" = "terraform"
    "repo"       = local.gh_repo
  }
}


resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}


data "azurerm_client_config" "current" {}

data "azurerm_log_analytics_workspace" "default" {
  name                = "DefaultWorkspace-${data.azurerm_client_config.current.subscription_id}-EUS"
  resource_group_name = "DefaultResourceGroup-EUS"
} 

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.gh_repo}-${random_string.unique.result}-${local.location}"
  location = local.location
  tags = local.tags
}

resource "azurerm_api_management" "resource-apim" {
  name                = "apim${random_string.unique.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = "implodingduck"
  publisher_email     = "something@nothing.com"

  public_network_access_enabled = true

  sku_name = "Premium"

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
  zones = ["1", "2"]
}