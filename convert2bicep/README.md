# Converting Terraform to Bicep

There is not an "easy" way to convert from Terraform to Bicep, rework is going to be required.

```
az deployment sub create --location $LOCATION --template-file armexport.bicep
# OR
az deployment group create --resource-group $GROUP --template-file armexport.bicep

```

If you want to do a `plan` then use the `--what-if` parameter on the `az deployment`

## via Powershell

The `Export-BicepResource` is in the preview release: https://github.com/PSBicep/PSBicep#installation

`Install-Module -Name Bicep -AllowPrerelease -Force`

`$mybicep = Export-BicepResource -ResourceId $ResourceId -AsString`

[terraform2bicep.ps1](https://github.com/implodingduck/terraform-samples/tree/main/convert2bicep/terraform2bicep.ps1) is a sample script for reading the resources managed by terraform from state and then export them into bicep

The sample script does not differentiate the `targetScope` so some refactoring might need to be done but it at least will give you a baseline to start with.

## via ARM

Creates bicep but is messier with its naming and sometimes fails due to what the decompile thinks is circular dependencies

```
az group export -g $GROUP > armexport.json

az bicep decompile --file armexport.json
```



