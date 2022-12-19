terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.36.0"
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

resource "azurerm_servicebus_namespace" "sb" {
  name                = "sbsample${random_string.unique.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Premium"
  capacity            = 1
  identity {
    type = "SystemAssigned"
  }
  tags = local.tags
}

resource "azurerm_servicebus_topic" "topic" {
  name         = "mytopic"
  namespace_id = azurerm_servicebus_namespace.sb.id
}

resource "azurerm_eventgrid_system_topic" "sbst" {
  name                   = "servicebussystemtopic${random_string.unique.result}"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  source_arm_resource_id = azurerm_servicebus_namespace.sb.id
  topic_type             = "Microsoft.ServiceBus.Namespaces"
}

resource "azurerm_logic_app_workflow" "lasbtoeg" {
  name                = "la-sb-to-eg-st"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

resource "azurerm_eventgrid_topic" "topic" {
  name                = "customegtopic${random_string.unique.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = local.tags
}

resource "azurerm_logic_app_workflow" "lasbtola" {
  name                = "la-sb-to-la"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

resource "azurerm_logic_app_workflow" "custom-eg-to-la" {
  name                = "la-custom-eg-to-la"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

resource "azurerm_role_assignment" "salasbtoeg" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_logic_app_workflow.lasbtoeg.identity.0.principal_id
}

resource "azurerm_role_assignment" "salasbtola" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_logic_app_workflow.lasbtola.identity.0.principal_id
}

resource "azurerm_role_assignment" "sacustom-eg-to-la" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_logic_app_workflow.custom-eg-to-la.identity.0.principal_id
}