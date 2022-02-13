# Deploy template

```
rg=rg-arc
customLocationName=loc-arc
customLocationId=$(az customlocation show \
    --resource-group $rg \
    --name $customLocationName \
    --query id \
    --output tsv)

az deployment group create \
  --resource-group $rg \
  --template-file topic.bicep \
  --parameters customLocation=$customLocationId
```