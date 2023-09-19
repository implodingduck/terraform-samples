$tfstate = terraform show -json | ConvertFrom-Json -Depth 100



# ForEach ($object in $tfstate.PsObject.Properties) {
#     Write-Output $object.name
#     Write-Output $object.value
# }

#Write-Output "---------"


$resourceIds = New-Object System.Collections.Generic.List[String]
$bicep = New-Object System.Collections.Generic.List[String]

ForEach ($resource in $tfstate.values.root_module.resources){
    if ($resource.values.id -ne $null){
        if($resource.values.id.StartsWith("/subscriptions/")){
            if(!$resource.address.StartsWith("data.")){
                #Write-Output "$($resource.address) -- $($resource.values.id)"
                $resourceIds.Add($resource.values.id)
                $mybicep = Export-BicepResource -ResourceId $resource.values.id -AsString
                $bicep.Add($mybicep)
                $bicep.Add("")
            } 
        }
    } 
}
# Write-Output "---------"

# Write-Output $resourceIds
Write-Output $bicep
