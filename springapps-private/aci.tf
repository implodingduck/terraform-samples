resource "azurerm_container_group" "aci" {
  name                = "aci-${local.name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_address_type     = "Public"
  os_type             = "Linux"
  subnet_ids          = [azurerm_subnet.aci.id]

  container {
    name   = "utils"
    image  = "bjd145/utils:3.7"
    cpu    = "0.5"
    memory = "1.5"

  }
  
  tags = local.tags
}