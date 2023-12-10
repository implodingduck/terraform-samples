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
  func_name = "pelab${random_string.unique.result}"
  loc_for_naming = "eastus"
  tags = {
    "managed_by" = "terraform"
    "repo"       = "terraform-samples"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.func_name}-${local.loc_for_naming}"
  location = local.loc_for_naming
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


resource "azurerm_virtual_network" "default" {
  name                = "vnet-${local.func_name}-${local.loc_for_naming}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.4.0.0/16"]

  tags = local.tags
}

resource "azurerm_subnet" "fw" {
  name                  = "AzureFirewallSubnet"
  resource_group_name   = azurerm_virtual_network.default.resource_group_name
  virtual_network_name  = azurerm_virtual_network.default.name
  address_prefixes      = ["10.4.1.0/26"]

}

resource "azurerm_subnet" "fwmgmt" {
  name                  = "AzureFirewallManagementSubnet"
  resource_group_name   = azurerm_virtual_network.default.resource_group_name
  virtual_network_name  = azurerm_virtual_network.default.name
  address_prefixes      = ["10.4.1.64/26"]

}

resource "azurerm_subnet" "pe" {
  name                  = "snet-privateendpoints-${local.loc_for_naming}"
  resource_group_name   = azurerm_virtual_network.default.resource_group_name
  virtual_network_name  = azurerm_virtual_network.default.name
  address_prefixes      = ["10.4.2.0/24"]

  private_endpoint_network_policies_enabled = true

}

resource "azurerm_subnet" "aci" {
  name                  = "snet-aci-${local.loc_for_naming}"
  resource_group_name   = azurerm_virtual_network.default.resource_group_name
  virtual_network_name  = azurerm_virtual_network.default.name
  address_prefixes      = ["10.4.3.0/24"]
  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  
  }
 
}

resource "azurerm_subnet" "other" {
  name                  = "snet-other-${local.loc_for_naming}"
  resource_group_name   = azurerm_virtual_network.default.resource_group_name
  virtual_network_name  = azurerm_virtual_network.default.name
  address_prefixes      = ["10.4.4.0/24"]
 
}

resource "azurerm_private_dns_zone" "blob" {
  name                      = "privatelink.blob.core.windows.net"
  resource_group_name       = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "file" {
  name                      = "privatelink.file.core.windows.net"
  resource_group_name       = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "queue" {
  name                      = "privatelink.queue.core.windows.net"
  resource_group_name       = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "table" {
  name                      = "privatelink.table.core.windows.net"
  resource_group_name       = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "blob"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.default.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "file" {
  name                  = "file"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.file.name
  virtual_network_id    = azurerm_virtual_network.default.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "table" {
  name                  = "table"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.table.name
  virtual_network_id    = azurerm_virtual_network.default.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "queue" {
  name                  = "queue"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.queue.name
  virtual_network_id    = azurerm_virtual_network.default.id
}

resource "azurerm_container_group" "bastion" {
  name                = "aci-bastion-${local.func_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  ip_address_type     = "Private"
  subnet_ids          = [ azurerm_subnet.aci.id ]

  container {
    name   = "bastion"
    image  =  "ghcr.io/implodingduck/az-tf-util-image:latest"
    cpu    = "0.5"
    memory = "1"
    ports {
      port     = 80
      protocol = "TCP"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

resource "azurerm_role_assignment" "owner" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Owner"
  principal_id         = azurerm_container_group.bastion.identity.0.principal_id
}


resource "azurerm_public_ip" "fw" {
  name                = "pip-fw${local.func_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}


resource "azurerm_public_ip" "fwmgmt" {
  name                = "pip-fwmgmt${local.func_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "fw" {
  name                = "fw${local.func_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  firewall_policy_id  = azurerm_firewall_policy.this.id
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.fw.id
    public_ip_address_id = azurerm_public_ip.fw.id
  }

  management_ip_configuration {
    name                 = "mgmt-configuration"
    subnet_id            = azurerm_subnet.fwmgmt.id
    public_ip_address_id = azurerm_public_ip.fwmgmt.id
  }
}

resource "azurerm_firewall_policy" "this" {
  name                = "fwpolicy${local.func_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
}

resource "azurerm_firewall_policy_rule_collection_group" "this" {
  name               = "rulecollection${local.func_name}"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 500
  network_rule_collection {
    name     = "network_rule_collection1"
    priority = 300
    action   = "Allow"
    rule {
      name = "allow443servicetags"
      source_addresses = [
        "*",
      ]

      destination_ports = [
        "443",
      ]

      destination_addresses = [
        "AzureCloud",
        "AzureContainerRegistry",
        "Storage",
        "EventHub",
        "AzureFrontDoor.FirstParty",
      ]

      protocols = [
        "TCP"
      ]
    }
    rule {
      name = "allow445servicetags"

      source_addresses = [
        "*",
      ]

      destination_ports = [
        "445",
      ]

      destination_addresses = [
        "Storage",
      ]

      protocols = [
        "TCP"
      ]
    }
    rule {
      name = "allowubuntuntp"

      source_addresses = [
        "*",
      ]

      destination_ports = [
        "123",
      ]

      destination_addresses = [
        "*",
      ]

      protocols = [
        "UDP"
      ]
    }
  }

  application_rule_collection {
    name     = "app_rule_collection1"
    priority = 500
    action   = "Allow"
    rule {
      name = "app_rule_collection1_rule1"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["mcr.microsoft.com", "*.azureedge.net", "*.ubuntu.com", "*.docker.io", "*.docker.com"]
    }
    rule {
      name = "app_rule_collection1_rule2"
      protocols {
        type = "Http"
        port = 80
      }
      source_addresses  = ["*"]
      destination_fqdns = ["crl.microsoft.com", "azure.archive.ubuntu.com"]
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "fw" {
  name                           = "allTheLogs"
  target_resource_id             = azurerm_firewall.fw.id
  log_analytics_destination_type = "AzureDiagnostics"
  log_analytics_workspace_id     = data.azurerm_log_analytics_workspace.default.id

  enabled_log  {
    category = "AzureFirewallApplicationRule"
    retention_policy {
      days    = 0
      enabled = false
    }
  }

  enabled_log {
    category = "AzureFirewallNetworkRule"

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  enabled_log {
    category = "AzureFirewallDnsProxy"

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  enabled_log {
    category = "AZFWApplicationRule"

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  enabled_log {
    category = "AZFWApplicationRuleAggregation"

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  enabled_log {
    category = "AZFWDnsQuery"

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  enabled_log {
    category = "AZFWFqdnResolveFailure"

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  enabled_log {
    category = "AZFWIdpsSignature"

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  enabled_log {
    category = "AZFWNatRule"

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  enabled_log {
    category = "AZFWNatRuleAggregation"

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  enabled_log {
    category = "AZFWNetworkRule"

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  enabled_log {
    category = "AZFWNetworkRuleAggregation"

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  enabled_log {
    category = "AZFWThreatIntel"

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = false

    retention_policy {
      days    = 0
      enabled = false
    }
  }

}