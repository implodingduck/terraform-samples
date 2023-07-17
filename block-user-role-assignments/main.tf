terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.56.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
    azapi = {
      source = "Azure/azapi"
      version = "=1.7.0"
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


resource "azurerm_policy_definition" "example" {
  name         = "implodingduck-block-user-role-assignments"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "implodingduck-block-user-role-assignments"

  policy_rule = <<POLICY_RULE
{
  "if": {
    "allOf": [
      {
        "field": "type",
        "equals": "Microsoft.Authorization/roleAssignments"
      },
      {
        "anyOf": [
          {
            "field": "Microsoft.Authorization/roleAssignments/principalType",
            "equals": "User"
          },
          {
            "field": "Microsoft.Authorization/roleAssignments/principalType",
            "exists": false
          }
        ]
      }
    ]
  },
  "then": {
    "effect": "deny"
  }
}
POLICY_RULE

}

resource "azurerm_resource_group_policy_assignment" "example" {
  name                 = "example-block-user-role-assignments"
  resource_group_id    = azurerm_resource_group.example.id
  policy_definition_id = azurerm_policy_definition.example.id
}

resource "azurerm_resource_group" "example" {
    name = "rg-terraform-samples-block-user-role-assignments"
    location = "eastus"
}

resource "azurerm_user_assigned_identity" "example" {
  location            = azurerm_resource_group.example.location
  name                = "uai-example"
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_role_assignment" "example" {
  depends_on = [ azurerm_resource_group_policy_assignment.example ]
  scope                = azurerm_resource_group.example.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.example.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "spn" {
  depends_on = [ azurerm_resource_group_policy_assignment.example ]
  scope                = azurerm_resource_group.example.id
  role_definition_name = "Reader"
  principal_id         = var.spn_principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "user" {
  depends_on = [ azurerm_resource_group_policy_assignment.example ]
  scope                = azurerm_resource_group.example.id
  role_definition_name = "Reader"
  principal_id         = var.user_principal_id
  skip_service_principal_aad_check = true
}

data "azurerm_role_definition" "reader" {
  name = "Reader"
}

resource "random_uuid" "myuserroleassignment" {
}

resource "azapi_resource" "userroleassignment" {
  depends_on = [ azurerm_resource_group_policy_assignment.example ]
  type = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name = random_uuid.myuserroleassignment.result
  parent_id = azurerm_resource_group.example.id
  body = jsonencode({
    properties = {
      description = "this should fail"
      principalId = var.user_principal_id
      principalType = "User"
      roleDefinitionId = data.azurerm_role_definition.reader.id
    }
  })
}

resource "random_uuid" "myuserroleassignment2" {
}

resource "azapi_resource" "userroleassignment2" {
  depends_on = [ azurerm_resource_group_policy_assignment.example ]
  type = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name = random_uuid.myuserroleassignment2.result
  parent_id = azurerm_resource_group.example.id
  body = jsonencode({
    properties = {
      description = "this should fail too"
      principalId = var.user_principal_id
      principalType = "Group"
      roleDefinitionId = data.azurerm_role_definition.reader.id
    }
  })
}

resource "random_uuid" "mygrouproleassignment" {
}


resource "azapi_resource" "grouproleassignment" {
  depends_on = [ azurerm_resource_group_policy_assignment.example ]
  type = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name = random_uuid.mygrouproleassignment.result
  parent_id = azurerm_resource_group.example.id
  body = jsonencode({
    properties = {
      description = "this should work (group)"
      principalId = var.group_principal_id
      principalType = "Group"
      roleDefinitionId = data.azurerm_role_definition.reader.id
    }
  })
}