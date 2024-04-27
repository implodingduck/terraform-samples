terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.92.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = "=4.0.4"
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
    cluster_name = "akstest${random_string.test.result}"
    tags = {
        "managed_by" = "terraform"
        "purpose" = "testing AKS OIDC Issuer"
    }

    backend_address_pool_name      = "${azurerm_virtual_network.default.name}-beap"
    frontend_port_name             = "${azurerm_virtual_network.default.name}-feport"
    frontend_ip_configuration_name = "${azurerm_virtual_network.default.name}-feip"
    http_setting_name              = "${azurerm_virtual_network.default.name}-be-htst"
    listener_name                  = "${azurerm_virtual_network.default.name}-httplstn"
    request_routing_rule_name      = "${azurerm_virtual_network.default.name}-rqrt"
}


data "azurerm_client_config" "current" {}

resource "random_string" "test" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-terraformtest-aksoidcissuer-${random_string.test.result}"
  location = "East US"
  tags = local.tags
}


resource "azurerm_virtual_network" "default" {
  name                = "${local.cluster_name}-vnet-eastus"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]

  tags = local.tags
}


resource "azurerm_subnet" "default" {
  name                 = "default-subnet-eastus"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "gw" {
  name                 = "gw-subnet-eastus"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.0.1.0/24"]
}


resource "azurerm_subnet" "cluster" {
  name                 = "${local.cluster_name}-subnet-eastus"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.0.2.0/23"]

}

resource "azurerm_subnet" "cluster2" {
  name                 = "${local.cluster_name}2-subnet-eastus"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.0.4.0/23"]

}

resource "azurerm_subnet" "aci" {
  name                 = "aci-subnet-eastus"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.0.6.0/24"]
  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }

  }

}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&?"
}
resource "azurerm_container_group" "this" {
  name                = "aci-${local.cluster_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  ip_address_type     = "Private"
  subnet_ids          = [azurerm_subnet.aci.id]

  container {
    name   = "bastion"
    image  = "ghcr.io/implodingduck/az-tf-util-image:latest"
    cpu    = "0.5"
    memory = "1"
    ports {
      port     = 80
      protocol = "TCP"
    }
    environment_variables = {
      TF_VAR_random_string = random_string.test.result
      ARM_USE_MSI          = "true"
      ARM_SUBSCRIPTION_ID  = data.azurerm_client_config.current.subscription_id
      VM_PASSWORD          = random_password.password.result
      RESOURCE_GROUP       = azurerm_resource_group.rg.name
      CLUSTER              = local.cluster_name
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

resource azurerm_role_assignment "aci" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_container_group.this.identity.0.principal_id
}

data "azurerm_kubernetes_service_versions" "current" {
  location = azurerm_resource_group.rg.location
}
resource "tls_private_key" "rsa-4096-example" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                    = local.cluster_name
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  dns_prefix              = local.cluster_name
  kubernetes_version      = data.azurerm_kubernetes_service_versions.current.latest_version
  private_cluster_enabled = true
  default_node_pool {
    name            = "default"
    node_count      = 1
    vm_size         = "Standard_B4ms"
    os_disk_size_gb = "128"
    vnet_subnet_id  = azurerm_subnet.cluster.id


  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    service_cidr       = "10.255.252.0/22"
    dns_service_ip     = "10.255.252.10"
    #outbound_type      = "userDefinedRouting"
  }

  role_based_access_control_enabled = true

  identity {
    type = "SystemAssigned"
  }
  
  oidc_issuer_enabled = true
  

  

  tags = local.tags
}


resource "azurerm_role_assignment" "example" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity.0.principal_id
}

resource "azurerm_public_ip" "gw" {
  name                = "pip-gw-${local.cluster_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "test" {
  name                = "gw-${local.cluster_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.gw.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.gw.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
    priority                   = 10
  }
}




output "issuer_url" {
  value = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "enabled" {
  value = azurerm_kubernetes_cluster.aks.oidc_issuer_enabled
}