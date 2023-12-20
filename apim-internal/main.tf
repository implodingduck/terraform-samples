terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.84.0"
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
  name      = "apiminternal${random_string.unique.result}"
  loc_for_naming = "eastus"
  loc_short = "${upper(substr(local.loc_for_naming, 0, 1))}US"
  tags = {
    "managed_by" = "terraform"
    "repo"       = "terraform-samples"
  }
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.name}-${local.loc_for_naming}"
  location = local.loc_for_naming
}

data "azurerm_client_config" "current" {}

data "azurerm_log_analytics_workspace" "default" {
  name                = "DefaultWorkspace-${data.azurerm_client_config.current.subscription_id}-${local.loc_short}"
  resource_group_name = "defaultresourcegroup-${local.loc_short}"
}

resource "azurerm_virtual_network" "default" {
  name                = "vnet-${local.name}-${local.loc_for_naming}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.5.0.0/16"]

  tags = local.tags
}

resource "azurerm_subnet" "apim" {
  name                 = "snet-apim"
  resource_group_name  = azurerm_virtual_network.default.resource_group_name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.5.1.0/24"]

}


resource "azurerm_public_ip" "apim" {
  name                = "pip-apkm-${local.name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"

  tags = local.tags
}

resource "azurerm_api_management" "apim" {
  depends_on = [ azurerm_subnet_network_security_group_association.apim ]
  name                 = "apim-${local.name}"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  publisher_name       = "openai-python-enterprise-logging"
  publisher_email      = "something@nothing.com"
  public_ip_address_id = azurerm_public_ip.apim.id
  virtual_network_type = "Internal"
  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim.id
  }
  policy = [
    {
      xml_content = <<-EOT
<policies>
    <inbound>
        <cors allow-credentials="true">
            <allowed-origins>
                <origin>https://apim-${local.name}.developer.azure-api.net</origin>
            </allowed-origins>
            <allowed-methods preflight-result-max-age="300">
                <method>*</method>
            </allowed-methods>
            <allowed-headers>
                <header>*</header>
            </allowed-headers>
            <expose-headers>
                <header>*</header>
            </expose-headers>
        </cors>
    </inbound>
    <backend>
        <forward-request buffer-response="false" />
    </backend>
    <outbound>
        <set-header name="X-OperationName" exists-action="override">
            <value>@( context.Operation.Name )</value>
        </set-header>
        <set-header name="X-OperationMethod" exists-action="override">
            <value>@( context.Operation.Method )</value>
        </set-header>
        <set-header name="X-OperationUrl" exists-action="override">
            <value>@( context.Operation.UrlTemplate )</value>
        </set-header>
        <set-header name="X-ApiName" exists-action="override">
            <value>@( context.Api.Name )</value>
        </set-header>
        <set-header name="X-ApiPath" exists-action="override">
            <value>@( context.Api.Path )</value>
        </set-header>
    </outbound>
    <on-error>
        <set-header name="X-OperationName" exists-action="override">
            <value>@( context.Operation.Name )</value>
        </set-header>
        <set-header name="X-OperationMethod" exists-action="override">
            <value>@( context.Operation.Method )</value>
        </set-header>
        <set-header name="X-OperationUrl" exists-action="override">
            <value>@( context.Operation.UrlTemplate )</value>
        </set-header>
        <set-header name="X-ApiName" exists-action="override">
            <value>@( context.Api.Name )</value>
        </set-header>
        <set-header name="X-ApiPath" exists-action="override">
            <value>@( context.Api.Path )</value>
        </set-header>
        <set-header name="X-LastErrorMessage" exists-action="override">
            <value>@( context.LastError.Message )</value>
        </set-header>
    </on-error>
</policies>
EOT
      xml_link    = null
    },
  ]
  zones    = []
  sku_name = "Developer_1"

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

resource "azurerm_network_security_group" "apim" {
  name                = "nsg-apim"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-3443-Inbound"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "3443"
  }

  security_rule {
    name                       = "Allow-443-Inbound"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "443"
  }

  security_rule {
    name                       = "Allow-3443-Outbound"
    priority                   = 1030
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "3443"
  }

  tags = local.tags
}

resource "azurerm_subnet_network_security_group_association" "apim" {
  subnet_id                 = azurerm_subnet.apim.id
  network_security_group_id = azurerm_network_security_group.apim.id
}
