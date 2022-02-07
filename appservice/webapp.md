# Web apps

## Creating an App Service Plan

You can create App Service Plans on an App Service Kubernetes environment. App Service Plans on Kubernetes are a logical construct because the underlying hardware does not change. There is only one SKU: K1.

To create a plan:

```
plan="myplan"

az appservice plan create --name $plan --resource-group $rg --custom-location $customLocationId --is-linux --per-site-scaling --sku K1
```

## Creating a web app

To deploy a web app, use the following command:

```
webappname=unique-name

az webapp create \
    --resource-group $rg \
    --name $webappname \
    --custom-location $customLocationId \
    --runtime 'NODE|12-lts'
```

The above command will create a new plan. To deploy the web app in the plan we created, use:

```
az webapp create \
    --resource-group $rg \
    --name $webappname \
    --custom-location $customLocationId \
    --runtime 'NODE|12-lts' --plan $plan
```

## Deploying a container

Let's deploy a web app that uses a container. Use az webapp create again and deploy to the same plan. If you do not specify a plan, a new plan is created.

If you use the same webappname, the previous app will be overwritten.

```
webappname=other-unique-name

az webapp create \
    --resource-group $rg \
    --name $webappname \
    --custom-location $customLocationId \
    --deployment-container-image-name ghcr.io/gbaeke/super:latest --plan $plan
```

Try to connect to the web app. Does it work?

In cases where it does not work, or you need to set configuration values, use the following command:

```
az webapp config appsettings set -g $rg -n $webappname --settings WEBSITES_PORT=8080 WELCOME="Hello from App Service on K8S!"
```

The web app will be restarted. Check if you see the new welcome message.

Hit the app on /source. The headers should provide some indication you are running the app on Kubernetes:
- Envoy headers
- X-K8se headers

