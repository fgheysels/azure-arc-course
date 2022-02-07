# APIM

## Deploy the extension with Azure CLI

If you want to deploy via the portal, skip to the next section.

⚠️ In contrast with App Services, you do not need a custom location to deploy the self-hosted gateway. This is because the gateway can be deployed on any cluster, regardless of being Azure Arc-enabled

Deploy the extension with the command below. This immediately deploys the self-hosted gateway.

```
endpoint="YOUR ENDPOINT URL"
key="YOUR AUTH KEY"

az k8s-extension create --cluster-type connectedClusters --cluster-name arcaks \
  --resource-group rg-arc --name apim  --extension-type Microsoft.ApiManagement.Gateway \
  --scope namespace --target-namespace apim \
  --configuration-settings gateway.endpoint=$endpoint \
  --configuration-protected-settings gateway.authKey=$key \
  --configuration-settings service.type='LoadBalancer' --release-train preview
```

## Deployment via portal

In the Kubernetes Azure Arc resource, navigate to extensions and add the API Management extension. The extension will not ask you to run a script. The extension will be deployed directly.

In the deployment via CLI, we did not configure metrics. The portal will ask for this and deploy the gateway with monitoring enabled to a chosen Log Analytics workspace.

Log Analytics settings:
- monitoring.customResourceId: resource ID of API Management instance (management plane)
- monitoring.workspaceId: Id of Log Analytics workspace
- monitoring.ingestionKey: ingestion key of Log Analytics workspace


## Testing the gateway

Deploy a **toy API** with the commands below. This requires a working kube config for kubectl.

```
kubectl create deployment super --image ghcr.io/gbaeke/super:latest
kubectl expose deployment super --port 80 --target-port 8080 --type=ClusterIP
```

Now create an API in API Management. We assume you know how to create it.
- give the API a unique name
- the web service URL is: http://super.default (we assume that the super service above was created in the default namespace; if not, replace default with the name of the namespace you used)
- add a custom header (inbound processing)

When the API is created, ensure that your gateway uses it. Next, connect to the self-hosted gatewway with curl:

```
curl http://IP:5000/API/source

...
HTTP header: YOURCUSTOMHEADER=[value]
...
```

Above, replace IP with the public IP address use by the LoadBalancer service created by the extension.

Replace API with the name of the API you created in Azure API Management.

Using the /source endpoint on the toy API, prints all headers. The custom header you created earlier should be shown.