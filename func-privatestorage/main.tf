terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.43.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  func_name = "funcpriv${random_string.unique.result}"
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

data "http" "ip" {
  url = "https://ifconfig.me/ip"
}
resource "azurerm_virtual_network" "default" {
  name                = "vnet-${local.func_name}-${local.loc_for_naming}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.4.0.0/24"]

  tags = local.tags
}

resource "azurerm_subnet" "pe" {
  name                  = "snet-privateendpoints-${local.loc_for_naming}"
  resource_group_name   = azurerm_virtual_network.default.resource_group_name
  virtual_network_name  = azurerm_virtual_network.default.name
  address_prefixes      = ["10.4.0.0/26"]

  private_endpoint_network_policies_enabled = true

}

resource "azurerm_subnet" "functions" {
  name                  = "snet-functions-${local.loc_for_naming}"
  resource_group_name   = azurerm_virtual_network.default.resource_group_name
  virtual_network_name  = azurerm_virtual_network.default.name
  address_prefixes      = ["10.4.0.64/26"]
  delegation {
    name = "serverfarm-delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
    }
  }
 
}

resource "azurerm_private_dns_zone" "blob" {
  name                      = "privatelink.blob.core.windows.net"
  resource_group_name       = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "file" {
  name                      = "privatelink.file.core.windows.net"
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

# resource "azurerm_private_endpoint" "peblob" {
#   name                = "pe-blob-sa${local.func_name}"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   subnet_id           = azurerm_subnet.pe.id

#   private_service_connection {
#     name                           = "pe-connection-blob-sa${local.func_name}"
#     private_connection_resource_id = azurerm_storage_account.sa.id
#     is_manual_connection           = false
#     subresource_names              = ["blob"]
#   }
#   private_dns_zone_group {
#     name                 = azurerm_private_dns_zone.blob.name
#     private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
#   }
# }

# resource "azurerm_private_endpoint" "pefile" {
#   name                = "pe-file-sa${local.func_name}"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   subnet_id           = azurerm_subnet.pe.id

#   private_service_connection {
#     name                           = "pe-connection-file-sa${local.func_name}"
#     private_connection_resource_id = azurerm_storage_account.sa.id
#     is_manual_connection           = false
#     subresource_names              = ["file"]
#   }
#   private_dns_zone_group {
#     name                 = azurerm_private_dns_zone.file.name
#     private_dns_zone_ids = [azurerm_private_dns_zone.file.id]
#   }
# }

resource "azurerm_storage_account" "sa" {
  name                     = "sa${local.func_name}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = local.tags
}


# resource "azurerm_storage_account_network_rules" "runner" {
#   storage_account_id = azurerm_storage_account.sa.id

#   default_action             = "Deny"
#   ip_rules                   = [data.http.ip.response_body]
#   #virtual_network_subnet_ids = [azurerm_subnet.functions.id]
#   bypass                     = ["AzureServices"]
# }

# resource "azurerm_storage_container" "hosts" {
#   name                  = "azure-webjobs-hosts"
#   storage_account_name  = azurerm_storage_account.sa.name
#   container_access_type = "private"
# }

# resource "azurerm_storage_container" "secrets" {
#   name                  = "azure-webjobs-secrets"
#   storage_account_name  = azurerm_storage_account.sa.name
#   container_access_type = "private"
# }

# resource "azurerm_storage_share" "func" {
#   name                 = local.func_name
#   storage_account_name = azurerm_storage_account.sa.name
#   quota                = 1
# }
resource "azurerm_service_plan" "asp" {
  name                = "asp-${local.func_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "func" {
#   depends_on = [
#     azurerm_private_endpoint.peblob,
#     azurerm_private_endpoint.pefile,
#     azurerm_private_dns_zone_virtual_network_link.blob,
#     azurerm_private_dns_zone_virtual_network_link.file,
#     #azurerm_storage_share.func,
#     azurerm_storage_container.hosts,
#     azurerm_storage_container.secrets
#   ]
  name                = local.func_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  storage_account_name       = azurerm_storage_account.sa.name
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key
  service_plan_id            = azurerm_service_plan.asp.id
  #virtual_network_subnet_id  = azurerm_subnet.functions.id
  functions_extension_version = "~4"
  site_config {
    always_on                = true
    #vnet_route_all_enabled    = true
    application_stack {
      node_version = "16"
    }
  }
  app_settings = {

    #"WEBSITE_CONTENTOVERVNET"         = "1"
    #"WEBSITE_CONTENTAZUREFILECONNECTIONSTRING"       = azurerm_storage_account.sa.primary_connection_string
    #"WEBSITE_CONTENTSHARE"                           = "${local.func_name}"
  }
  identity {
    type         = "SystemAssigned"
  }
}