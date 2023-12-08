terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.83.0"
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
  name = "nsgchild${random_string.unique.result}"
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

resource "azurerm_network_security_group" "example" {
  name                = "nsg-${local.name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

}

data "azurerm_network_security_group" "parent" {
  name                = "nsg-nsgparentufz48u90"
  resource_group_name = "rg-nsgparentufz48u90-eastus"
}

resource "azurerm_network_security_rule" "r" {
  for_each = { for sr in data.azurerm_network_security_group.parent.security_rule : "${sr.priority}-${sr.direction}" => sr }
  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.example.name
}

resource "azurerm_network_security_rule" "customr" {
  name                        = "c1i"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8888"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.example.name
}