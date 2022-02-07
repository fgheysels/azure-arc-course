# Run this function locally

If Function Tools are installed: `func host start`

# Create ZIP archive

⚠️ Install zip with apt-get or use Windows to zip via GUI

zip -r func.zip .

# Create New Function App

Make sure you have the Azure CLI extensions:

```
az extension add --upgrade --yes --name customlocation
az extension remove --name appservice-kube
az extension add --upgrade --yes --name appservice-kube
```

Set variables:

```
rg=rg-arc
customlocationname=geba-home
```

Get location Id:

```
customLocationId=$(az customlocation show \
    --resource-group $rg \
    --name $customlocationname \
    --query id \
    --output tsv)
```

Create storage account and Function App:

```
storagename=arcstorage88282

az storage account create --name $storagename --location westeurope --resource-group $rg --sku Standard_LRS

functionappname=arc-func88282

az functionapp create --resource-group $rg --name $functionappname --custom-location  $customLocationId --storage-account $storagename --functions-version 3 --runtime node --runtime-version 12
```

# Zip deploy the function app

az functionapp deployment source config-zip --resource-group $rg --name $functionappname --src func.zip

