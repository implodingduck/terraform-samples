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
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Owner"
  principal_id         = "a0f6d82f-c084-4c08-bce5-d50b143d0e88"
}

resource "azurerm_role_assignment" "azure-spring-cloud-resource-provider" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Owner"
  principal_id         = "77e44c53-4911-427e-83c2-e2a52f569dee"
}

# resource "azurerm_spring_cloud_service" "this" {
#   depends_on = [
#     azurerm_subnet_route_table_association.apps,
#     azurerm_subnet_route_table_association.service-runtime,
#   ]
#   name                = local.name
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   sku_name            = "B0"

#   network {
#     app_subnet_id = azurerm_subnet.apps.id
#     service_runtime_subnet_id = azurerm_subnet.service-runtime.id
#     cidr_ranges = ["10.252.0.0/16", "10.253.0.0/16", "10.254.0.1/16"]
#   }
#   tags = local.tags
# }


resource "azapi_resource" "azurespringapps" {
  depends_on = [
    azurerm_subnet_route_table_association.apps,
    azurerm_subnet_route_table_association.service-runtime,
    azurerm_firewall_network_rule_collection.this
  ]
  type = "Microsoft.AppPlatform/Spring@2022-12-01"
  name = local.name
  location = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id
  tags = local.tags
  body = jsonencode({
    properties = {
      networkProfile = {
        appSubnetId = azurerm_subnet.apps.id
        outboundType = "userDefinedRouting"
        serviceCidr = "10.252.0.0/16,10.253.0.0/16,10.254.0.1/16"
        serviceRuntimeSubnetId = azurerm_subnet.service-runtime.id
      }
      vnetAddons = {
        logStreamPublicEndpoint = false
      }
      zoneRedundant = false
    }
    sku = {
      name = "S0"
    }
  })
}

