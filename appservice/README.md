# App Service on Azure Arc

## Prerequisites

Azure CLI extensions:

```
az extension add --name connectedk8s
az extension add --name k8s-extension
az extension add --name customlocation
az extension remove --name appservice-kube
az extension add --upgrade --yes --name appservice-kube
```

Register providers:

```bash
az provider register --namespace Microsoft.ExtendedLocation --wait
az provider register --namespace Microsoft.Web --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
```

⚠️ Ensure a working kubeconfig to check the pods that land on the cluster

Set variables for resource group and cluster. For example:

```bash
rg=rg-arc
clu=arcaks
```

Connect your Kubernetes cluster:

```bash
az group create -g $rg -l LOCATION
az connectedk8s connect --resource-group $rg --name $clu
```
## Log Analytics

Create a Log Analytics workspace:

```bash
ws=arcws

az monitor log-analytics workspace create \
    --resource-group $rg \
    --workspace-name $ws
```

Get the workspace ID and shared key for the workspace:

```bash
logAnalyticsWorkspaceId=$(az monitor log-analytics workspace show \
    --resource-group $rg \
    --workspace-name $ws \
    --query customerId \
    --output tsv)
logAnalyticsWorkspaceIdEnc=$(printf %s $logAnalyticsWorkspaceId | base64 -w0)
logAnalyticsKey=$(az monitor log-analytics workspace get-shared-keys \
    --resource-group $rg \
    --workspace-name $ws \
    --query primarySharedKey \
    --output tsv)
logAnalyticsKeyEnc=$(printf %s $logAnalyticsKey | base64 -w0) 
```

## Install the App Service Extension

Set some variables for the extension:
- extensionName: this is the name of the extension to install; for App Service, this is "appservice-ext"
- namespace: choose a namespace for your extension
- kubeEnvironmentName: choose a name for the App Service Kubernetes environment

```bash
extensionName="appservice-ext"
namespace="appservice-ns"
kubeEnvironmentName="kube-appenv"
```

Install the extension using the Azure CLI. This is recommended over following the wizard in the portal.

⚠️ Replace STORAGECLASS with the Kubernetes storage class the extension will use. For AKS this can be "managed-premium" but also "default". Use `kubectl get sc` to see the available storage classes. On other clusters besides AKS, always check the storage classes and use the one that is appropriate.

⚠️ The configuration setting `envoy.annotations.service.beta.kubernetes.io/azure-load-balancer-resource-group` is specific for AKS; if you deploy the extension to other Kubernetes clusters, like K8S in Digital Ocean, you do not need to set this.

⚠️ The log analytics configuration is optional; if you do not want to use it, comment out the lines below.

```bash
# set below variable to the resource group that contains physical cluster resources of AKS
# if not specified or not set, the extension should still install successfully :-)
aksClusterGroupName="MC_rg-aks_kub001_westeurope"

az k8s-extension create \
    --resource-group $rg \
    --name $extensionName \
    --cluster-type connectedClusters \
    --cluster-name $clu \
    --extension-type 'Microsoft.Web.Appservice' \
    --release-train stable \
    --auto-upgrade-minor-version true \
    --scope cluster \
    --release-namespace $namespace \
    --configuration-settings "Microsoft.CustomLocation.ServiceAccount=default" \
    --configuration-settings "appsNamespace=${namespace}" \
    --configuration-settings "clusterName=${kubeEnvironmentName}" \
    --configuration-settings "keda.enabled=true" \
    --configuration-settings "buildService.storageClassName=default" \
    --configuration-settings "buildService.storageAccessMode=ReadWriteOnce" \
    --configuration-settings "customConfigMap=${namespace}/kube-environment-config" \
    --configuration-settings "envoy.annotations.service.beta.kubernetes.io/azure-load-balancer-resource-group=${aksClusterGroupName}" \
    --configuration-settings "logProcessor.appLogs.destination=log-analytics" \
    --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.customerId=${logAnalyticsWorkspaceIdEnc}" \
    --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.sharedKey=${logAnalyticsKeyEnc}"
```

The above command creates the extension, which is just an ARM resource. Azure Arc for Kubernetes will check for these extensions and start installing the extension with Helm.

Get the extension Id with the following command:

```bash
extensionId=$(az k8s-extension show \
    --cluster-type connectedClusters \
    --cluster-name $clu \
    --resource-group $rg \
    --name $extensionName \
    --query id \
    --output tsv)
```

Now wait for the installation to be complete with `az resource wait --ids $extensionId --custom "properties.installState!='Pending'" --api-version "2020-07-01-preview"`

When the extension is installed, you can proceed with the creation of a custom location.

## Custom Location

Later, you will install the App Service Kubernetes environment. The environment needs a custom location. 

First, set the location name and retrieve the Id of the connected cluster:

```bash
customLocationName="geba-home" # Name of the custom location

connectedClusterId=$(az connectedk8s show --resource-group $rg --name $clu --query id --output tsv)
```

Now you can create the custom location:

```bash
az customlocation create \
    --resource-group $rg \
    --name $customLocationName \
    --host-resource-id $connectedClusterId \
    --namespace $namespace \
    --cluster-extension-ids $extensionId
```

Check the custom location with `az customlocation show --resource-group $rg --name $customLocationName`

Save the custom location Id. You need it to create the App Service Kubernetes environment.

```bash
customLocationId=$(az customlocation show \
    --resource-group $rg \
    --name $customLocationName \
    --query id \
    --output tsv)
```

## Create App Service Kubernetes Environment

Use the following command to create the environment:

```bash
az appservice kube create \
    --resource-group $rg \
    --name $kubeEnvironmentName \
    --custom-location $customLocationId
```

Verify successful creation with `az appservice kube show --resource-group $rg --name $kubeEnvironmentName`

The above command just creates the environment to create web apps on Kubernetes.

## Creating a sample web app and deploy code

Use the following command:

```bash
az webapp create \
    --resource-group $rg \
    --name gebaapp \
    --custom-location $customLocationId \
    --runtime 'NODE|12-lts'
```

Note: find the Linux runtimes to use with `az webapp list-runtimes --linux`

⚠️ The name you use in --name needs to result in a unique name. Include random characters or initials. If you get `Unable to retrieve details of the existing app.` error, try a different name.

When the command succeeds, there will be a new pod in the App Service namespace called `gebaapp-...`. Check the hostNames section in the output of the command, it contains the URL to access the app. You will need to use this URL to access the app as asked below.

Deploy code (ensure zip is installed with `sudo apt-get install zip`))

```bash
git clone https://github.com/Azure-Samples/nodejs-docs-hello-world
cd nodejs-docs-hello-world
zip -r package.zip .
az webapp deployment source config-zip --resource-group $rg --name gebaapp --src package.zip
```

When you navigate to the web app, you should see a `Hello World!` message.

