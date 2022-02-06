# GitOps with Azure Arc

## Introduction

You should use Flux v2 for GitOps with Azure Arc. It is currently in preview. Flux v2 can also be used with Azure Kubernetes Service (AKS). Although Flux v1 on Azure Arc is GA, it will eventually be deprecated. This will happen sooner than later.

Steps:
- ensure providers are registered and Azure CLI extensions are installed
- create one or more `fluxConfigurations`



## Providers and extensions

Ensure the following providers are registered and check the registration state:

```bash
az provider register --namespace Microsoft.Kubernetes
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.KubernetesConfiguration

az provider show -n Microsoft.KubernetesConfiguration -o table
```

The extension is supported in all regions where Azure Arc is supported. The extension needs connectivity to several endpoints:
- https://management.azure.com
- https://<region>.dp.kubernetesconfiguration.azure.com
- https://login.microsoftonline.com
- https://mcr.microsoft.com
- https://azurearcfork8s.azurecr.io


Also enable Azure CLI extensions (first check if you have them already: `az extension list -o table`)

```
az extension add -n k8s-configuration
az extension add -n k8s-extension

az extension update -n k8s-configuration
az extension update -n k8s-extension
```

## Creating a GitOps configuration

You can install the Flux extension in a separate step. If you do not, it will be installed automatically when you create a Flux configuration.

Adding the extension:

```
az k8s-extension create --name flux  \
	--extension-type microsoft.flux \
	--scope cluster --cluster-name $clu \
	--resource-group $rg \
	--cluster-type connectedClusters
```

⚠️ The Flux-related pod in the azure-arc namepace that are part of the Azure Arc agent support logging; the pods installed from the microsoft.flux extension will be in the flux-system namespace. The command above installs Flux cluster-scoped. Namespace-scoped is possible as well; at the time of this writing, the version of the extension was 0.5.1. The pods in flux)system are:
- Azure Flux controllers: fluxconfig-agent, fluxconfig-controller
- OSS Flux controllers: source-controller, kustomize-controller, helm-controller, notification-controller

We will now create a GitOps configuration. The git repository is an example repository: https://github.com/fluxcd/flux2-kustomize-helm-example. Only the manifests in the `infrastructure` and `apps/staging `folders will be deployed. A combination of `kustomize` and `helm` is used to deploy the manifests.

We can deploy a configuration with the following command:

```
az k8s-configuration flux create -g $rg -c $clu -n gitops-demo --namespace gitops-demo \
    -t connectedClusters --scope cluster -u https://github.com/fluxcd/flux2-kustomize-helm-example \
    --branch main  --kustomization name=infra path=./infrastructure prune=true \
    --kustomization name=apps path=./apps/staging prune=true dependsOn=["infra"]
```

Above, two `kustomizations` are defined:
- infra: applies the manifests in the infrastructure folder with pruning on; pruning can lead to deletion of Kubernetes resources when the git repository is updated in that way
- apps: applies the manifests in the apps/staging with pruning on; Flux supports dependencies between kustomizations, so the manifests in the apps folder will only be deployed if the manifests in the infrastructure folder are deployed.


⚠️ If the k8s-configuration extension is not installed, the command `az k8s-configuration flux create` will ask to install it


⚠️ This configuration uses a public repository; private repositories are supported as well but require extra configuration to authenticate properly.

The GitOps Configuration will also show up in the portal, under `GitOps (preview)`. The configuration will have a compliance state. If the state is Compliant, it means that Flux has reconciled the configuration and the resources are in sync with the git repository.

You will be able to see the objects that were created. In this case:
- 1 GitRepository
- 2 Kustomizations (as installed above with az k8s-configuration flux create)
- 2 HelmRepositories
- 3 HelmReleases (one repository, BitNami, is used for 2 of the HelmReleases)

To see the same information (more or less) from the Azure CLI, use `az k8s-configuration flux show -n name -g rg -c cluster -t connectedClusters`. This will show:
- compliance state
- resource id of the fluxConfiguration
- details of all the resources that were created; reconciliation status etc...


You can also use the Flux CLI to view the configuration. See https://fluxcd.io/docs/installation/ for installation instructions.

For example, to show Flux kustomizations on your cluster (when connected with kubectl): `flux get kustomizations --all-namespaces`. The result:

```
NAMESPACE       NAME                    READY   MESSAGE                         REVISION        SUSPENDED
gitops-demo     gitops-demo-apps        True    Applied revision: main/f0c2aae  main/f0c2aae    False
gitops-demo     gitops-demo-infra       True    Applied revision: main/f0c2aae  main/f0c2aae    False
```

You can also use kubectl:
- kubectl get fluxconfigs -A
- kubectl get gitrepositories -A
- kubectl get helmreleases -A
- kubectl get kustomizations -A


To delete a Flux configuration:

```
az k8s-configuration flux delete -g rg -c cluster -n configname -t connectedClusters --yes
```

The above command will remove the configuration. Because of pruning, the resources will be deleted as well. Flux itself will not be removed. To remove flux, remove the extension:

```
az k8s-extension delete -g rg -c clustername -n extensionname -t connectedClusters --yes
```

## Additional controllers

Flux also has additional controllers for image automation:
- image-automation
- image-reflector

See https://fluxcd.io/docs/components/image/ for more information.

## Flux parameters

Above, we deployed a simple GitOps Configuration with a public repository and two Kustomizations. The az k8s-configuration flux create commands takes an enormous amount of parameters. See https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2#work-with-parameters.

Many of the arguments have to do with authentication like:
- HTTPS user and key: e.g., username and PAT token
- SSH private key
- bucket access keys if you use S3



