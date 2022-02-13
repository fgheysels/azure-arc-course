# Event Grid

## Install extension via Portal

You can install the extension via the Azure Portal. You will need to provide the following information in the wizard:

Basics:
- Extension name: a name you choose
- Release namespace: namespace on K8S cluster; it will be created if it does not exist
- Service type: use ClusterIP; we will talk to Event Grid from inside the cluster
    - ⚠️ ClusterIP is the only option during preview
- Storage class name: you can use **azurefile** as fast block storage is not required
    - Storage size in GiB: 5 Gib (default is 1Gib, size depends on event ingestion rate)
- Memory limit: 1Gi (it will be the memory limit for the pod)
- Memory request: 200 Mib

Configuration:
- in production, you should enable HTTPS and provide certificate information
- for now, select **Enable HTTP (not secure) communication**

Monitoring:
- select **Enable metrics**
- metrics are exposed as Prometheus metrics and not sent to Azure

Continue the wizard and click **Create** at the end.

Event Grid will be installed. You need to check the following pods on Kubernetes to check if the installation is complete (in **eventgrid-system** namespace):
- Event Grid broker
- Event Grid operator

When the pods are ready, proceed with the custom location.

## Install with Azure CLI

Create a settings-extension.json file:

```
echo "{
    \"Microsoft.CustomLocation.ServiceAccount\":\"eventgrid-operator\",
    \"eventgridbroker.service.serviceType\": \"ClusterIP\",
    \"eventgridbroker.dataStorage.storageClassName\": \"azurefile\",
    \"eventgridbroker.diagnostics.metrics.reporterType\":\"prometheus\",
    \"eventgridbroker.service.supportedProtocols[0]\":\"http\"
}" > settings-extension.json
```

Install the extension:

```
clu=arcclustername
rg=rg-arc
egname=eventgrid-ext



az k8s-extension create --cluster-type connectedClusters --cluster-name $clu \
  --resource-group $rg --name $egname --extension-type Microsoft.EventGrid \
  --scope cluster --auto-upgrade-minor-version true --release-train Stable \
  --release-namespace eventgrid-system --configuration-settings-file settings-extension.json
```

The result of creation is JSON like below:

```json
{
  "aksAssignedIdentity": null,
  "autoUpgradeMinorVersion": true,
  "configurationProtectedSettings": {},
  "configurationSettings": {
    "Microsoft.CustomLocation.ServiceAccount": "eventgrid-operator",
    "eventgridbroker.dataStorage.storageClassName": "azurefile",
    "eventgridbroker.diagnostics.metrics.reporterType": "prometheus",
    "eventgridbroker.service.serviceType": "ClusterIP",
    "eventgridbroker.service.supportedProtocols[0]": "http"
  },
  "customLocationSettings": null,
  "errorInfo": null,
  "extensionType": "microsoft.eventgrid",
  "id": "/subscriptions/d1d3dadc-bc2a-4495-b8dd-70443d1c70d1/resourceGroups/rg-arc/providers/Microsoft.Kubernetes/connectedClusters/arcaks/providers/Microsoft.KubernetesConfiguration/extensions/eventgrid-ext",
  "identity": {
    "principalId": "8dd452f8-78c5-4a70-84e8-efa04428dcac",
    "tenantId": null,
    "type": "SystemAssigned"
  },
  "location": null,
  "name": "eventgrid-ext",
  "packageUri": null,
  "provisioningState": "Succeeded",
  "releaseTrain": "Stable",
  "resourceGroup": "rg-arc",
  "scope": {
    "cluster": {
      "releaseNamespace": "eventgrid-system"
    },
    "namespace": null
  },
  "statuses": [],
  "systemData": {
    "createdAt": "2022-02-08T14:35:21.104103+00:00",
    "createdBy": null,
    "createdByType": null,
    "lastModifiedAt": "2022-02-08T14:35:21.104103+00:00",
    "lastModifiedBy": null,
    "lastModifiedByType": null
  },
  "type": "Microsoft.KubernetesConfiguration/extensions",
  "version": "1.0.0-arc-preview"
}
```

⚠️ The extension is cluster-scoped. Only one instance of Event Grid can be deployed to the cluster.

## Custom location

Can we use the custom location we used for the App Services extension? It appears that that is not the case, with the following error message:

```
Failed to perform operation on resource in extended location. Reason: Operation returned an invalid status code 'Forbidden'
```

In the portal, when you navigate to the custom location, you will see that the only Arc-enabled service for the location is **appservice-ext** (if you followed the course in order). You can add the **eventgrid-ext** extension to list. Event Grid topics and subscriptions will be saved in the same namespace than the App Service extension.

⚠️ It is possible to create multiple custom locations that use the same Arc-enabled cluster but different namespaces.

## Create an event grid topic

In the Azure Portal, search for Event Grid Topics (search bar) and add a new topic with **Create**:

Basics:
- select your custom location in the **Region** dropdown
- select or create a resource group and type the **name of the topic** (e.g., arctopic)

Networking:
- not much choice 😉

Advanced:
- not much choice either 😉

Click **Review and Create** and then **Create**

The topic will be created in your custom location. Check the topic in the portal. It will be of kind **AzureArc**.

In Kubernetes, the namespace associated to the custom location, will contain an object of kind **Topic** and apiVersion **eventgrid.microsoft.com/v1alpha1** (at this point in time).

Instead of creating the topic in the portal, you can use the Azure CLI. An example below:

```
az eventgrid topic create -g $rg --name $topicname --kind azurearc --extended-location-name $customlocationid --extended-location-type customlocation --input-schema CloudEventSchemaV1_0 --location westeurope
```

⚠️ --location westeurope is required for Azure to keep the metadata for the topic


## Deploy a web app to view events pushed to the topic

The following link deploys a web app to view events pushed to the topic:  https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure-Samples%2Fazure-event-grid-viewer%2Fmaster%2Fazuredeploy.json

The web app will have an endpoint we can use to send events to: https://webappname.azurewebsites.net/api/updates.

## Create a subscription

Now, we can create a subscription to the topic that pushes events to the web app you created.

First obtain the topic id:

```
rg=rg-arc
topicname=arctopic

topicid=$(az eventgrid topic show --name $topicname --resource-group $rg --query id -o tsv)
```

Next, create a subscription:

```
sub=subname
endpoint="https://WEBAPPNAME.azurewebsites.net/api/updates"

az eventgrid event-subscription create --name $sub --source-resource-id $topicid --endpoint $endpoint
```

In the Azure Portal, check that the subscription to the topic was created.

You will see an event subscription of type webhook.


## Send events

Obtain the Event Grid topic Kubernetes endpoint and the key:

```
az eventgrid topic show --name $topicname -g $rg --query "endpoint" --output tsv

az eventgrid topic key list --name $topicname -g $rg --query "key1" --output tsv
```

⚠️ If the client is internal (pod in cluster), the endpoint is of the form: http://eventgrid.eventgrid-system:80/topics/TOPICNAME/api/events?api-version=2018-01-01

⚠️ If you use the `event-ingress.yaml` in this folder and apply it to the `eventgrid-system` namespace, you can use curl from your machine to send the event. Be sure to set the host in the ingress to a value with the IP of your Traefik service. 

Issue the following curl command from inside the cluster. Replace KEY and ENDPOINT with the values obtained above.

```bash
curl  -k -X POST -H "Content-Type: application/cloudevents-batch+json" -H "aeg-sas-key: KEY" -g ENDPOINT \
-d  '[{ 
      "specversion": "1.0",
      "type" : "orderCreated",
      "source": "myCompanyName/be/secureOrderSystem",
      "id" : "eventId-n",
      "time" : "2022-02-10T20:54:07+00:00",
      "subject" : "account/acct-123224/order/o-123456",
      "dataSchema" : "1.0",
      "data" : {
         "orderId" : "123",
         "orderType" : "PO",
         "reference" : "https://www.myCompanyName.com/orders/123"
      }
}]'
```

Check that the Event Viewer web app shows the event. Click the event to see the details.

## Optional - subscription with Service Bus queue

Create a **Service Bus Namespace** (Basic tier) and **queue**.

On the topic, create a new **subscription**. Instead of a webhook, use a Service Bus queue and select the namespace and queue you just created.

Send a few messages with curl.

In the Azure Portal, open the page for the queue and use **Service Bus Explorer** to peek at the messages. Each message should contain the payload in the CloudEvents format. The messages also have custom properties that start with **aeg** for **Azure Event Grid**. For example:

- aeg-event-type: Notification
- aeg-subscription-name: the name of the subscription to the Event Grid topic

Subscriptions are resources of kind **EventSubscription** and apiVersion **eventgrid.microsoft.com/v1alpha1**. The resources are created in the namespace associated to the custom location. To authenticate to Service Bus, the **spec** of the Event Subscription contains a **connectionString** property. It contains a value in the form of:

```
Endpoint=sb://arcgeba.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=SHAREDACCESSKEY;EntityPath=arc
```

For example:

```yaml
spec:
  properties:
    destination:
      endpointType: ServiceBusQueue
      properties:
        connectionString: Endpoint=sb://arcgeba.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=SHAREDACCESSKEY;EntityPath=arc
    eventDeliverySchema: CloudEventSchemaV1_0
    filter:
      isSubjectCaseSensitive: false
    persistencePolicy: {}
    retryPolicy:
      eventExpiryInMinutes: 1440
      maxDeliveryAttempts: 30
    topic: arctopic
```