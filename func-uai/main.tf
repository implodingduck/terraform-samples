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
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

locals {
  func_name = "funcuai${random_string.unique.result}"
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


resource "azurerm_application_insights" "app" {
  name                = "${local.func_name}-insights"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  application_type    = "other"
  workspace_id        = data.azurerm_log_analytics_workspace.default.id
}

resource "azurerm_storage_account" "sa" {
  name                     = "sa${local.func_name}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = local.tags
}

resource "azurerm_storage_container" "hosts" {
  name                  = "azure-webjobs-hosts"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "secrets" {
  name                  = "azure-webjobs-secrets"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_storage_share" "func" {
  name                 = local.func_name
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 1
}
resource "azurerm_service_plan" "asp" {
  name                = "asp-${local.func_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "func" {
  depends_on = [
    azurerm_storage_container.hosts,
    azurerm_storage_container.secrets,
    azurerm_role_assignment.data
  ]
  name                = local.func_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  storage_account_name       = azurerm_storage_account.sa.name
  storage_uses_managed_identity = "true"
  service_plan_id            = azurerm_service_plan.asp.id

  functions_extension_version = "~4"
  site_config {
    application_insights_key = azurerm_application_insights.app.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.app.connection_string
    application_stack {
      node_version = "16"
    }
  }
  app_settings = {
    "AzureWebJobsStorage__credential" = "managedidentity"
    "AzureWebJobsStorage__clientId" = azurerm_user_assigned_identity.uai.client_id
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "0"
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [ azurerm_user_assigned_identity.uai.id ]
  }
}

resource "azurerm_user_assigned_identity" "uai" {
  location            = azurerm_resource_group.rg.location
  name                = "uai-${local.func_name}"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "data" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.uai.principal_id  
}

resource "local_file" "localsettings" {
    content     = <<-EOT
{
  "IsEncrypted": false,
  "Values": {
    "FUNCTIONS_WORKER_RUNTIME": "node",
    "AzureWebJobsStorage": ""
  }
}
EOT
    filename = "func/local.settings.json"
}

resource "null_resource" "publish_func" {
  depends_on = [
    local_file.localsettings
  ]
  triggers = {
    index = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "cd func && npm install"
  }
}

data "archive_file" "func" {
  depends_on = [
    null_resource.publish_func
  ]
  type        = "zip"
  source_dir  = "func"
  output_path = "func.zip"
}

resource "null_resource" "azdeploy" {
  depends_on = [
    azurerm_linux_function_app.func
  ]
  triggers = {
    index = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "az functionapp deployment source config-zip -g ${azurerm_resource_group.rg.name} -n ${local.func_name} --src ${data.archive_file.func.output_path} --build-remote false"
  }
}


