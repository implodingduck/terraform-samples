resource "azurerm_network_security_group" "basic" {
  name                = "nsg-basic-${local.name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = local.tags
}


resource "azurerm_virtual_network" "default" {
  name                = "vnet-${local.name}-eastus"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.1.0.0/16"]

  tags = local.tags
}

resource "azurerm_subnet" "fw" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_virtual_network.default.resource_group_name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.1.0.0/24"]
}

resource "azurerm_subnet" "fwm" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_virtual_network.default.resource_group_name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "service-runtime" {
  name                  = "snet-service-runtime"
  resource_group_name   = azurerm_virtual_network.default.resource_group_name
  virtual_network_name  = azurerm_virtual_network.default.name
  address_prefixes      = ["10.1.2.0/24"]

}

resource "azurerm_route_table" "service-runtime" {
  name                          = "udr-service-runtime"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name

  route {
    name           = "fw"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.this.ip_configuration.0.private_ip_address
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [
        tags,
        route
    ]
  }
}

resource "azurerm_subnet_route_table_association" "service-runtime" {
  subnet_id      = azurerm_subnet.service-runtime.id
  route_table_id = azurerm_route_table.service-runtime.id
}

resource "azurerm_subnet_network_security_group_association" "service-runtime" {
  subnet_id                 = azurerm_subnet.service-runtime.id
  network_security_group_id = azurerm_network_security_group.basic.id
}


resource "azurerm_subnet" "apps" {
  name                  = "snet-apps"
  resource_group_name   = azurerm_virtual_network.default.resource_group_name
  virtual_network_name  = azurerm_virtual_network.default.name
  address_prefixes      = ["10.1.3.0/24"]

}

resource "azurerm_route_table" "apps" {
  name                          = "udr-apps"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name

  route {
    name           = "fw"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.this.ip_configuration.0.private_ip_address
  }

  tags = local.tags
  lifecycle {
    ignore_changes = [
        tags,
        route
    ]
  }
}

resource "azurerm_subnet_route_table_association" "apps" {
  subnet_id      = azurerm_subnet.apps.id
  route_table_id = azurerm_route_table.apps.id
}

resource "azurerm_subnet_network_security_group_association" "apps" {
  subnet_id                 = azurerm_subnet.apps.id
  network_security_group_id = azurerm_network_security_group.basic.id
}

resource "azurerm_subnet" "aci" {
  name                  = "snet-aci"
  resource_group_name   = azurerm_virtual_network.default.resource_group_name
  virtual_network_name  = azurerm_virtual_network.default.name
  address_prefixes      = ["10.1.4.0/24"]
  delegation {
    name = "aci"
    service_delegation {
      name = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }

}

resource "azurerm_private_dns_zone" "azuremicroservices" {
  name                = "private.azuremicroservices.io"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "azuremicroservices" {
  name                  = "vnet-link-azuremicroservices"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.azuremicroservices.name
  virtual_network_id    = azurerm_virtual_network.default.id
}


