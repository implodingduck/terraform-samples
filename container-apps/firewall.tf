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
}


resource "azurerm_monitor_diagnostic_setting" "fw" {
  name                           = "allTheLogs"
  target_resource_id             = azurerm_firewall.this.id
  log_analytics_destination_type = "AzureDiagnostics"
  log_analytics_workspace_id     = data.azurerm_log_analytics_workspace.default.id

  log {
    category = "AzureFirewallApplicationRule"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  log {
    category = "AzureFirewallNetworkRule"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  log {
    category = "AzureFirewallDnsProxy"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  log {
    category = "AZFWApplicationRule"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  log {
    category = "AZFWApplicationRuleAggregation"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  log {
    category = "AZFWDnsQuery"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  log {
    category = "AZFWFqdnResolveFailure"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  log {
    category = "AZFWIdpsSignature"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  log {
    category = "AZFWNatRule"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  log {
    category = "AZFWNatRuleAggregation"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  log {
    category = "AZFWNetworkRule"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  log {
    category = "AZFWNetworkRuleAggregation"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  log {
    category = "AZFWThreatIntel"
    enabled  = true

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