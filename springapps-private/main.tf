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
      source = "azure/azapi"
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
  name = "asa-${random_string.unique.result}"
  tags = {
    "managed_by" = "terraform"
    "repo"       = "terraform-samples"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "rg-spring-apps-${random_string.unique.result}"
  location = "EastUS"
  tags = local.tags
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_role_assignment" "azure-spring-app-resource-provider" {
  scope                = azurerm_virtual_network.default.id
  role_definition_name = "Owner"
  principal_id         = "e8de9221-a19c-4c81-b814-fd37c6caf9d2"
}

resource "azurerm_spring_cloud_service" "this" {
  depends_on = [
    azurerm_subnet_route_table_association.apps,
    azurerm_subnet_route_table_association.service-runtime,
  ]
  name                = local.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "B0"

  network {
    app_subnet_id = azurerm_subnet.apps.id
    service_runtime_subnet_id = azurerm_subnet.service-runtime.id
    cidr_ranges = ["10.252.0.0/16", "10.253.0.0/16", "10.254.0.1/16"]
  }
  tags = local.tags
}

