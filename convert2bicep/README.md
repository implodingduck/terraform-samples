# Terraform vs Bicep

Table of nuances:

|   | Terraform | Bicep |
|---|-----------| ----- |
| Plan | `terraform plan` | `az deployment sub create --what-if` |
| Apply | `terraform apply` | `az deployment sub create` | 
| Azure Resources | [AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) or [AzApi Provider](https://learn.microsoft.com/en-us/azure/developer/terraform/overview-azapi-provider) | [Only ARM api spec](https://learn.microsoft.com/en-us/azure/templates/) |
| Non Azure Resources | Potentially another provider to use or `null_resource` | [Deployment Script](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-script-bicep) |
| State Management | Uses a separate state file as the source of truth | No state file, only compares to what is existing in Azure | 
| Modules | Yes, custom modules are supported | Yes, custom modules are supported |
| Target Scoping | Provider block, allows for aliasing other subscriptions | https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-functions-scope |


# Converting Terraform to Bicep

There is not an "easy" way to convert from Terraform to Bicep, rework is going to be required.


## via Powershell

The `Export-BicepResource` is in the preview release: https://github.com/PSBicep/PSBicep#installation

`Install-Module -Name Bicep -AllowPrerelease -Force`

`$mybicep = Export-BicepResource -ResourceId $ResourceId -AsString`

[terraform2bicep.ps1](https://github.com/implodingduck/terraform-samples/tree/main/convert2bicep/terraform2bicep.ps1) is a sample script for reading the resources managed by terraform from state and then export them into bicep

The sample script does not differentiate the `targetScope` so some refactoring might need to be done but it at least will give you a baseline to start with.

```
az deployment sub create --location $LOCATION --template-file armexport.bicep
# OR
az deployment group create --resource-group $GROUP --template-file armexport.bicep
```

## via ARM

Creates bicep but is messier with its naming and sometimes fails due to what the decompile thinks is circular dependencies

```
az group export -g $GROUP > armexport.json

az bicep decompile --file armexport.json
```



