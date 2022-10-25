terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.19.1"
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
  tags = {
    "managed_by" = "terraform"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "rg-slackbot"
  location = "EastUS"
}

resource "azurerm_user_assigned_identity" "mai" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  name = "uai-mai-slackchannel"
}


resource "azurerm_bot_channels_registration" "example" {
  name                = "slackbot-example-reg-123123"
  location            = "global"
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "F0"
  microsoft_app_id    = azurerm_user_assigned_identity.mai.client_id
}

resource "azapi_resource" "slackchannel" {
  type = "Microsoft.BotService/botServices/channels@2022-06-15-preview"
  name = "SlackChannel"
  location = azurerm_bot_channels_registration.example.location
  parent_id = azurerm_bot_channels_registration.example.id
  tags = {
    tagName1 = "tagValue1"
    tagName2 = "tagValue2"
  }
  body = jsonencode({
    properties = {
      channelName = "SlackChannel"
      properties = {
        clientId = "string"
        clientSecret = "string"
        isEnabled = true
        landingPageUrl = "string"
        registerBeforeOAuthFlow = true
        scopes = "string"
        signingSecret = "string"
        verificationToken = "string"
      }
    }
    sku = {
      name = "F0"
    }
  })
}