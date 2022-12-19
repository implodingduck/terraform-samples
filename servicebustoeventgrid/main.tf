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

# resource "azurerm_eventgrid_system_topic_event_subscription" "sbstsub" {
#   name                = "subsbsttola"
#   system_topic        = azurerm_eventgrid_system_topic.sbst.name
#   resource_group_name = azurerm_resource_group.rg.name

#   webhook_endpoint {
#     url =
#   }
# }

data "template_file" "sbtoegstjson" {
  template = "${file("${path.module}/la-sb-to-eg-st.json")}"
  vars = {
    subscription_id = data.azurerm_client_config.current.subscription_id
  }
}