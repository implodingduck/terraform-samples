terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.52.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "=1.5.0"
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
  name = "aca-${random_string.unique.result}"
  tags = {
    "managed_by" = "terraform"
    "repo"       = "terraform-samples"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "rg-container-apps-${random_string.unique.result}"
  location = "EastUS"
  tags     = local.tags
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

