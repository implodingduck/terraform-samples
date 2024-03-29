terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.41.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "1.7.0"
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
  func_name = "lasami${random_string.unique.result}"
  location  = "eastus"
  gh_repo   = "terraform-samples"
  tags = {
    "managed_by" = "terraform"
    "repo"       = local.gh_repo
  }
}

data "azurerm_client_config" "current" {}

data "azurerm_log_analytics_workspace" "default" {
  name                = "DefaultWorkspace-${data.azurerm_client_config.current.subscription_id}-EUS"
  resource_group_name = "DefaultResourceGroup-EUS"
}

data "http" "ip" {
  url = "https://ifconfig.me/ip"
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.func_name}-${local.location}"
  location = local.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "default" {
  name                = "vnet-${local.func_name}-${local.location}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.4.0.0/24"]

  tags = local.tags
}

resource "azurerm_subnet" "pe" {
  name                 = "snet-privateendpoints-${local.location}"
  resource_group_name  = azurerm_virtual_network.default.resource_group_name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.4.0.0/26"]

  private_endpoint_network_policies_enabled = true

}

resource "azurerm_subnet" "logicapps" {
  name                 = "snet-logicapps-${local.location}"
  resource_group_name  = azurerm_virtual_network.default.resource_group_name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.4.0.64/26"]
  service_endpoints = [
    "Microsoft.Web",
    "Microsoft.Storage"
  ]
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
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}



# resource "azurerm_private_endpoint" "pe" {
#   name                = "pe-sa${local.func_name}"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   subnet_id           = azurerm_subnet.pe.id

#   private_service_connection {
#     name                           = "pe-connection-sa${local.func_name}"
#     private_connection_resource_id = azurerm_storage_account.sa.id
#     is_manual_connection           = false
#     subresource_names              = ["blob"]
#   }
#   private_dns_zone_group {
#     name                 = azurerm_private_dns_zone.blob.name
#     private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
#   }
# }

# resource "azurerm_private_endpoint" "pe-file" {
#   name                = "pe-sa${local.func_name}-file"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   subnet_id           = azurerm_subnet.pe.id

#   private_service_connection {
#     name                           = "pe-connection-sa${local.func_name}-file"
#     private_connection_resource_id = azurerm_storage_account.sa.id
#     is_manual_connection           = false
#     subresource_names              = ["file"]
#   }
#   private_dns_zone_group {
#     name                 = azurerm_private_dns_zone.file.name
#     private_dns_zone_ids = [azurerm_private_dns_zone.file.id]
#   }
# }


# resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
#   name                  = "pdns-blob"
#   resource_group_name   = azurerm_resource_group.rg.name
#   private_dns_zone_name = azurerm_private_dns_zone.blob.name
#   virtual_network_id    = azurerm_virtual_network.default.id
# }

# resource "azurerm_private_dns_zone_virtual_network_link" "file" {
#   name                  = "pdns-file"
#   resource_group_name   = azurerm_resource_group.rg.name
#   private_dns_zone_name = azurerm_private_dns_zone.file.name
#   virtual_network_id    = azurerm_virtual_network.default.id
# }

resource "azurerm_storage_account" "sa" {
  name                     = "sa${local.func_name}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = local.tags
}

# resource "azurerm_storage_container" "hosts" {
#   depends_on = [
#     azapi_resource_action.resource_access_rule
#   ]
#   name                  = "azure-webjobs-hosts"
#   storage_account_name  = azurerm_storage_account.sa.name
#   container_access_type = "private"
# }

# resource "azurerm_storage_container" "secrets" {
#   depends_on = [
#     azapi_resource_action.resource_access_rule
#   ]
#   name                  = "azure-webjobs-secrets"
#   storage_account_name  = azurerm_storage_account.sa.name
#   container_access_type = "private"
# }

# resource "azurerm_storage_share" "share" {
#   depends_on = [
#     azapi_resource_action.resource_access_rule
#   ]
#   name                 = "la-${local.func_name}-content"
#   storage_account_name = azurerm_storage_account.sa.name
#   quota                = 1
# }


# resource "azapi_resource_action" "resource_access_rule" {
#   type        = "Microsoft.Storage/storageAccounts@2022-05-01"
#   resource_id = azurerm_storage_account.sa.id
#   method      = "PUT"

#   body = jsonencode({
#     location = local.location
#     properties = {
#       networkAcls = {
#         resourceAccessRules = [
#           {
#             resourceId = "${azurerm_resource_group.rg.id}/providers/Microsoft.Logic/workflows/*"
#             tenantId   = data.azurerm_client_config.current.tenant_id
#           }
#         ]
#         bypass = "AzureServices"
#         virtualNetworkRules = [
#           {
#             id     = azurerm_subnet.logicapps.id
#             action = "Allow"
#           }

#         ]
#         ipRules = [
#           {
#             action = "Allow"
#             value  = data.http.ip.response_body
#           }
#         ]
#         defaultAction = "Deny"
#       }
#     }
#   })
# }

resource "azurerm_service_plan" "asp" {
  name                = "asp-${local.func_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Windows"
  sku_name            = "WS1"
  tags                = local.tags
}


resource "azurerm_logic_app_standard" "example" {
  name                       = "la-${local.func_name}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_service_plan.asp.id
  storage_account_name       = azurerm_storage_account.sa.name
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key
  virtual_network_subnet_id  = azurerm_subnet.logicapps.id
  version = "~4"
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"     = "node"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~16"
    # "FUNCTIONS_EXTENSION_VERSION"  = "~4"
    # "AzureFunctionsJobHost__extensionBundle__version" = "[3.*, 4.0.0)"
    "AzureWebJobStorage__accountName" = azurerm_storage_account.sa.name
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.this.connection_string
  }

  site_config {
    dotnet_framework_version  = "v6.0"
    use_32_bit_worker_process = true
    vnet_route_all_enabled    = true
    ftps_state                = "Disabled"
  }

  identity {
    type = "SystemAssigned"
  }
  tags = local.tags
}

resource "azurerm_role_assignment" "system" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_logic_app_standard.example.identity.0.principal_id
}

resource "azurerm_role_assignment" "appinsights" {
  scope                = azurerm_application_insights.this.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_logic_app_standard.example.identity.0.principal_id
}


resource "azurerm_application_insights" "this" {
  name                          = "${local.func_name}-insights"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  workspace_id                  = data.azurerm_log_analytics_workspace.default.id
  application_type              = "other"
  local_authentication_disabled = true
}
