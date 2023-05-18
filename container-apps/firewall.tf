resource "azurerm_public_ip" "fw" {
  name                = "pip-fw-${local.name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "fwm" {
  name                = "pip-fwm-${local.name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}


resource "azurerm_firewall" "this" {
  name                = "fw-${local.name}"
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
    name                 = "managementconfiguration"
    subnet_id            = azurerm_subnet.fwm.id
    public_ip_address_id = azurerm_public_ip.fwm.id
  }
}


resource "azurerm_firewall_policy" "this" {
  name                = "fwpolicy-${local.name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
}

resource "azurerm_firewall_policy_rule_collection_group" "this" {
  name               = "fwpolicy-rcg-${local.name}"
  firewall_policy_id = azurerm_firewall_policy.this.id

  priority = 100
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
      destination_fqdns = ["mcr.microsoft.com", "*.azureedge.net", "*.ubuntu.com", "*.docker.io"]
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
  target_resource_id             = azurerm_firewall.this.id
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