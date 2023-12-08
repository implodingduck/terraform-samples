# NSG - Children

## The Problem
The problem is that NSGs cannot be inherited/nested, but sometimes you want to have a parent rule that all NSGs are based off of. 

## The Solution
This terraform example has a ["parent" nsg](../nsg-parent) and is referenced as a data source. The key is having a `for_each` loop over the data source NSG rules and add them to the "child" nsg

```
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

```

