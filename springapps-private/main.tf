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
  tags     = local.tags
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
    azurerm_firewall_policy_rule_collection_group.this
  ]
  type      = "Microsoft.AppPlatform/Spring@2022-12-01"
  name      = local.name
  location  = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id
  tags      = local.tags
  body = jsonencode({
    properties = {
      networkProfile = {
        appSubnetId            = azurerm_subnet.apps.id
        outboundType           = "userDefinedRouting"
        serviceCidr            = "10.252.0.0/16,10.253.0.0/16,10.254.0.1/16"
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
  response_export_values = ["*"]
}

resource "azurerm_spring_cloud_app" "this" {
  name                = "mysampleapp"
  resource_group_name = azurerm_resource_group.rg.name
  service_name        = jsondecode(azapi_resource.azurespringapps.output).name

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_spring_cloud_java_deployment" "this" {
  name                = "deploy1"
  spring_cloud_app_id = azurerm_spring_cloud_app.this.id
  instance_count      = 1
  jvm_options         = "-Xms1024m -Xmx2048m"
  runtime_version     = "Java_11"

  quota {
    cpu    = "1"
    memory = "2Gi"
  }

  environment_variables = {
    "testEnvKey" : "testEnvValue"
  }
}

resource "azurerm_spring_cloud_active_deployment" "this" {
  spring_cloud_app_id = azurerm_spring_cloud_app.this.id
  deployment_name     = azurerm_spring_cloud_java_deployment.this.name
}

data "template_file" "deploy" {
  template = file("deploy.sh.tmpl")
  vars = {
    "RESOURCE_GROUP" = azurerm_resource_group.rg.name
    "SERVICE_NAME"   = jsondecode(azapi_resource.azurespringapps.output).name
    "APP_NAME"       = azurerm_spring_cloud_app.this.name
  }
}

resource "local_file" "deploy" {
  content  = data.template_file.deploy.rendered
  filename = "deploy.sh"
}