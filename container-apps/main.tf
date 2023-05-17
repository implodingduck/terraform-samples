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

data "azurerm_log_analytics_workspace" "default" {
  name                = "DefaultWorkspace-${data.azurerm_client_config.current.subscription_id}-EUS"
  resource_group_name = "DefaultResourceGroup-EUS"
}

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

resource "azapi_resource" "env" {
  type = "Microsoft.App/managedEnvironments@2022-11-01-preview"
  name = "acaenv-${local.name}"
  location = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id
  tags = local.tags
  body = jsonencode({
    properties = {
      appLogsConfiguration = {
        destination = "log-analytics"
        logAnalyticsConfiguration = {
          customerId = data.azurerm_log_analytics_workspace.default.workspace_id
          sharedKey = data.azurerm_log_analytics_workspace.default.primary_shared_key
        }
      }
      vnetConfiguration = {
        dockerBridgeCidr = "172.16.0.0/16"
        infrastructureSubnetId = jsondecode(azapi_resource.snet-apps.output).id #azurerm_subnet.apps.id
        internal = true
        platformReservedCidr = "192.168.0.0/16"
        platformReservedDnsIP = "192.168.0.0"
      }
      workloadProfiles = [
        {
          name = "Dedicated-D4"
          workloadProfileType = "Dedicated-D4"
        }
      ]
      zoneRedundant = false
    }
  })
  response_export_values = ["*"]
}

resource "azurerm_container_app" "example" {
  name                         = "${local.name}"
  container_app_environment_id = jsondecode(azapi_resource.env.output).id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "examplecontainerapp"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }
  tags                         = local.tags
}