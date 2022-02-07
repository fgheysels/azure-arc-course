# Create ZIP archive

⚠️ Install zip with apt-get or use Windows to zip via GUI

zip -r gebala.zip .

# Create New Logic App

Add the Logic Apps extension to Azure CLU:

```
az extension add --yes --source "https://aka.ms/logicapp-latest-py2.py3-none-any.whl"
```

Add environment variables:

```
rg=rg-arc
storagename=lastorage88282
customlocationname=geba-home
```

Create storage account:

```
az storage account create --name $storagename --location westeurope --resource-group $rg --sku Standard_LRS
```

Get custom location id:

```
customLocationId=$(az customlocation show \
    --resource-group $rg \
    --name $customlocationname \
    --query id \
    --output tsv)
```

Create Logic App:

```
logicappname=gebala88282

az logicapp create --name $logicappname \
   --resource-group $rg \
   --storage-account $storagename --custom-location $customLocationId
```

Get Logic App details:

```
az logicapp show --name $logicappname --resource-group $rg
```

Deploy workflow with zip:

```
az logicapp deployment source config-zip --name $logicappname \
   --resource-group $rg \
   --src gebala.zip
```

Check if there is a workflow called **ArcSample** in the Logic App. Calling the workflow URL should return: Hello

Or with curl:

```
curl 'https://gebala88282.kube-appenv-ajbc2gpbqz7g.westeurope.k4apps.io:443/api/ArcSample/triggers/manual/invoke?api-version=2020-05-01-preview&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=HU-KEC1nm8w2b0kGFTLRZXusLJGBb6cbQd5eqQtnj4Y'

Hello
```

