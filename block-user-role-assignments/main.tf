terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.56.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
  }
}

resource "azurerm_resource_group" "example" {
    name = "rg-terraform-samples-block-user-role-assignments"
    location = "eastus"
}

resource "azurerm_user_assigned_identity" "example" {
  location            = azurerm_resource_group.example.location
  name                = "uai-example"
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_role_assignment" "example" {
  scope                = azurerm_resource_group.example.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.example.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "spn" {
  scope                = azurerm_resource_group.example.id
  role_definition_name = "Reader"
  principal_id         = var.spn_principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "user" {
  scope                = azurerm_resource_group.example.id
  role_definition_name = "Reader"
  principal_id         = var.user_principal_id
  skip_service_principal_aad_check = true
}