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
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"
  
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.fw.id
    public_ip_address_id = azurerm_public_ip.fw.id
  }

  management_ip_configuration {
    name = "managementconfiguration"
    subnet_id = azurerm_subnet.fwm.id
    public_ip_address_id = azurerm_public_ip.fwm.id
  }
}


resource "azurerm_firewall_policy" "this" {
  name                = "fwpolicy-${local.name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_firewall_network_rule_collection" "example" {
  name                = "network-rules-${local.name}"
  azure_firewall_name = azurerm_firewall.this.name
  resource_group_name = azurerm_resource_group.rg.name
  priority            = 100
  action              = "Allow"

  rule {
    name = "allowall"

    source_addresses = [
      "*",
    ]

    destination_ports = [
      "*",
    ]

    destination_addresses = [
      "*"
    ]

    protocols = [
      "TCP",
      "UDP",
    ]
  }
}