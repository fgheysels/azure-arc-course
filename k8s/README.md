# Azure Arc for Kubernetes

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

⚠️ Although confusing, you can use the same name for the AKS cluster and the Azure Arc representation of it.

## Cluster Connect

With kubectl connected to your cluster, run the following commands:

```
AAD_ENTITY_OBJECT_ID=$(az ad signed-in-user show --query objectId -o tsv)

kubectl create clusterrolebinding admin-user-binding --clusterrole cluster-admin --user=$AAD_ENTITY_OBJECT_ID
```

The above commands do the following:
- obtain the objectId of the signed-in user
- create a clusterrolebinding with the cluster-admin role and the signed-in user as the user to bind to the role


After running the above commands, use `az connectedk8s proxy -n $clu -g $rg`. You can now run `kubectl` commands in another window. For instance:

- kubectl get nodes
- kubectl get ns

When the proxy is closed, and you issue kubectl commands, you will see something like below:

```
The connection to the server 127.0.0.1:47011 was refused - did you specify the right host or port?
```

You can also run `az connectedk8s proxy -n $clu -g $rg &` to run the proxy in the background. Wait until you see the response of the command and then continue in the same session. This approach is useful on Azure DevOps agents or GitHub Actions. To bring the proxy back to the foreground, use `fg`.


⚠️ Instead of AAD, cluster connect also allows you to connect to the cluster with a service account token. For example:

```
kubectl create serviceaccount admin-user
kubectl create clusterrolebinding admin-user-binding --clusterrole cluster-admin --serviceaccount default:admin-user

SECRET_NAME=$(kubectl get serviceaccount admin-user -o jsonpath='{$.secrets[0].name}')

TOKEN=$(kubectl get secret ${SECRET_NAME} -o jsonpath='{$.data.token}' | base64 -d | sed $'s/$/\\\n/g')

az connectedk8s proxy -n $clu -g $rg --token $TOKEN
```

The above commands do the following:
- create a serviceaccount with the name admin-user
- create a clusterrolebinding with the cluster-admin role and the serviceaccount as the user to bind to the role
- obtain the name of the secret that was created for the service account; it contains a JWT token to present to the Kubernetes API server
- decode the token and remove the newline characters
- use the token to connect to the cluster with the --token parameter

After running `az connectedk8s proxy`, there will be a context with the name of the Azure Arc resource. You should now be able to issue `kubectl` commands against the cluster.

## Resource Viewer

Generate a JWT token as shown above. For reference, here are the commands again:

```
kubectl create serviceaccount admin-user
kubectl create clusterrolebinding viewer-binding --clusterrole cluster-admin --serviceaccount default:admin-user
SECRET_NAME=$(kubectl get serviceaccount admin-user -o jsonpath='{$.secrets[0].name}')
TOKEN=$(kubectl get secret ${SECRET_NAME} -o jsonpath='{$.data.token}' | base64 -d | sed $'s/$/\\\n/g')
```

When the portal prompts for a token to use resource viewer, past the contents of the TOKEN variable.

You can now view:
- Namespaces
- Workloads
- Services and Ingresses
- Storage
- Configuration

Try to find the container image name of the clusteridentityoperator via Resource Viewer. There are several ways to do this.

Can you modify resources on the cluster via Resource Viewer?

## Extensions

Extensions can be created from the portal:
- extensions section of the Azure Arc-enabled Kubernetes cluster
- specific sections like Insights (Azure Monitor for Containers), Azure Policy

Or use the Azure CLI. For example:

```
az k8s-extension create --name azuremonitor-containers  \
	--extension-type Microsoft.AzureMonitor.Containers \
	--scope cluster --cluster-name $clu \
	--resource-group $rg \
	--cluster-type connectedClusters
```

Also install the flux extension:

```
az k8s-extension create --name flux  \
	--extension-type microsoft.flux \
	--scope cluster --cluster-name $clu \
	--resource-group $rg \
	--cluster-type connectedClusters
```

Above:
- --name is a name you choose yourself
- --extension-type needs to be set to the specific extension type
- most extensions are cluster-scoped

Check the extensions in the Azure Portal page of the Azure Arc cluster:
- what's the install status?
- is auto upgrade minor version enabled? (semantic versioning: MAJOR.MINRO.PATCH)

Check the pods on your cluster (e.g., with k9s). Can you find the pods for both extensions?
- there should be two extra namespaces for the extensions
- list the Helm releases in each namespace (quick tip: list the secrets in each namespace)
- are there pods in the Azure Monitor for Containers namespace? What else can you find in that namespace?

Can you remove the flux extension from the portal? Try it. Check the logs of extension-manager to see what happens under the hood. After a while, the resources in the flux-system namespace should be removed.

List extensions with `az k8s-extension list -c $clu -g $rg -t connectedClusters -o table`:

```
Name                     ExtensionType                      Version            ProvisioningState   
-----------------------  ---------------------------------  -----------------  -------------------  
eventgrid-ext            Microsoft.EventGrid                1.0.0-arc-preview  Succeeded            
appservice-ext           microsoft.web.appservice           0.12.0             Succeeded            
azuremonitor-containers  microsoft.azuremonitor.containers  2.9.0              Succeeded            
```

Above, the following extension types were added:
- Microsoft.EventGrid: Event Grid for Kubernetes
- microsoft.web.appservice: App Services for Azure Arc
- microsoft.azuremonitor.containers: Azure Monitor for Containers

Look at the details of a particular extension with `az k8s-extension show -n azuremonitor-containers -c $clu -g $rg -t connectedClusters`. The result (example for App Service):

```json
{
  "aksAssignedIdentity": null,
  "autoUpgradeMinorVersion": true,
  "configurationProtectedSettings": {
    "logProcessor.appLogs.logAnalyticsConfig.customerId": "",
    "logProcessor.appLogs.logAnalyticsConfig.sharedKey": ""
  },
  "configurationSettings": {
    "Microsoft.CustomLocation.ServiceAccount": "default",
    "appsNamespace": "appservice-ns",
    "buildService.storageAccessMode": "ReadWriteOnce",
    "buildService.storageClassName": "default",
    "clusterName": "kube-appenv",
    "customConfigMap": "appservice-ns/kube-environment-config",
    "envoy.annotations.service.beta.kubernetes.io/azure-load-balancer-resource-group": "",
    "keda.enabled": "true",
    "logProcessor.appLogs.destination": "log-analytics"
  },
  "customLocationSettings": null,
  "errorInfo": null,
  "extensionType": "microsoft.web.appservice",
  "id": "/subscriptions/d1d3dadc-bc2a-4495-b8dd-70443d1c70d1/resourceGroups/rg-arc/providers/Microsoft.Kubernetes/connectedClusters/arcaks/providers/Microsoft.KubernetesConfiguration/extensions/appservice-ext",
  "identity": {
    "principalId": "86a3f81a-ebd9-4e17-a07b-6ae224af7d6d",
    "tenantId": null,
    "type": "SystemAssigned"
  },
  "location": null,
  "name": "appservice-ext",
  "packageUri": null,
  "provisioningState": "Succeeded",
  "releaseTrain": "stable",
  "resourceGroup": "rg-arc",
  "scope": {
    "cluster": {
      "releaseNamespace": "appservice-ns"
    },
    "namespace": null
  },
  "statuses": [],
  "systemData": {
    "createdAt": "2022-01-29T14:31:07.641191+00:00",
    "createdBy": null,
    "createdByType": null,
    "lastModifiedAt": "2022-01-29T14:31:07.641191+00:00",
    "lastModifiedBy": null,
    "lastModifiedByType": null
  },
  "type": "Microsoft.KubernetesConfiguration/extensions",
  "version": "0.12.0"
}
```


Get information about extensions for multiple clusters with Resource Graph:

```
az extension add --name resource-graph

az graph query -q 'kubernetesconfigurationresources | limit 20'
```

⚠️ Tip: use project to show specific properties; e.g., `az graph query -q 'kubernetesconfigurationresources | project name,location'`

