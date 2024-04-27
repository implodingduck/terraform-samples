terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.101.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
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


data "azurerm_management_group" "root" {
  display_name = "Tenant Root Group"
}


resource "azurerm_role_definition" "sample" {
  name        = "my-custom-tfrole"
  scope       = data.azurerm_management_group.root.id
  description = "This is a custom role created via Terraform"

  permissions {
    actions     = ["*/read"]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_management_group.root.id, 
  ]
}