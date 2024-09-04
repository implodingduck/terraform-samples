terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.0.1"
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


locals {
  name = "afd${random_string.unique.result}"
  loc_for_naming = "eastus"
  tags = {
    "managed_by" = "terraform"
    "repo"       = "terraform-samples"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.name}-${local.loc_for_naming}"
  location = local.loc_for_naming
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}


data "azurerm_client_config" "current" {}

resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = local.name
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard_AzureFrontDoor"

  tags = local.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "this" {
  name                     = local.name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  tags = local.tags
}

resource "azurerm_cdn_frontdoor_firewall_policy" "this" {
  name                = "waf${local.name}"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = azurerm_cdn_frontdoor_profile.this.sku_name
  mode                = "Prevention"

  custom_block_response_status_code = 403
  custom_block_response_body        = "PGh0bWw+CjxoZWFkZXI+PHRpdGxlPkhlbGxvPC90aXRsZT48L2hlYWRlcj4KPGJvZHk+CkhlbGxvIHdvcmxkCjwvYm9keT4KPC9odG1sPg=="

  custom_rule {
    name                           = "Rule1"
    enabled                        = true
    priority                       = 1
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = 10
    type                           = "MatchRule"
    action                         = "Block"

    match_condition {
      match_variable     = "RemoteAddr"
      operator           = "IPMatch"
      negation_condition = false
      match_values       = ["192.168.1.0/24", "10.0.0.0/24"]
    }
  }
}

resource "azurerm_cdn_frontdoor_security_policy" "this" {
  name                     = "policy-${local.name}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.this.id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.this.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}
