# ArgoCD Echo Deployment

## Pre-conditions

Local machine must be setup with helm, kubectl, argocd

```bash
brew install helm
brew install kubectl
brew install argocd
```

Kubectl must be configured to have access to the target cluster:

```bash
kubectl cluster-info
```

## ArgoCD installation

Execute:

```bash
sh ./deploy-argo-sh
```

## Installation Explanation

The wrapper script `sh/deploy-argo.sh` is broken down into multiple stages.

### verifyDependencies

Validates the helm, kubectl and argocd are correctly installed on the local machine.

### installArgoCD

The `installArgoCD` function automates the deployment of ArgoCD using Helm and follows these steps:

1. The Argo Helm repository is added and updated to ensure the latest chart versions are available. It refreshes the
   local index (on your development machine) of available charts, which is important to ensure that you're installing or
   upgrading to the latest
   stable versions of ArgoCD and any other components.
2. If an existing ArgoCD release exists in the specified namespace ($ARGO_NAMESPACE), it is uninstalled.
3. ArgoCD is installed with the following custom settings:
    * **Naming Convention:** Sets fullnameOverride=argocd to maintain consistent resource names. Using
      `fullnameOverride=argocd` simplifies the naming of the deployed resources, ensuring consistency and making it
      easier to reference the services.
    * **Disabled Features:** Disables the ApplicationSet controller, notifications, and Dex for resource optimisation.
    * **Custom Kustomize Options:** Removes Kustomize's load restrictions for more flexible handling of manifests.
4. The function monitors the ArgoCD server's deployment status to ensure successful rollout.

### setupSelfManagedArgoCD

Deploy the ArgoCD Application resource. This Helm chart defines an ArgoCD Application resource that automates the
deployment and management of the ArgoCD application itself within a Kubernetes cluster.

1. **Apply the ArgoCD Helm Chart** The chart specifies an ArgoCD Application using the Application CRD provided by
   ArgoCD. This application will manage the deployment of ArgoCD, allowing ArgoCD to manage itself, following a GitOps
   approach. The configuration includes syncing policies, source configurations, and custom Helm values to control how
   the ArgoCD components (such as the repo server, Dex, and Redis) are deployed and configured.
2. After applying the Helm chart, the script retrieves the initial admin password for ArgoCD from the Kubernetes secret
   and decodes it.
3. **Log In to ArgoCD:** The script then logs into ArgoCD using the retrieved admin credentials. It attempts to log in
   until successful.
4. **Synchronise the ArgoCD Application:** The script attempts to synchronise the ArgoCD-managed application, retrying
   every 10 seconds until successful. ArgoCD can automatically synchronise applications without requiring manual
   intervention, and this automatic synchronization can be enabled using automated sync policies. However, in the script
   you provided, the ArgoCD app sync command is being used manually to ensure that the synchronization happens
   explicitly within the script.
5. **Check the Rollout Status of ArgoCD Repository Server:** Lastly, the script monitors the rollout status of the
   ArgoCD repository server to ensure the deployment is complete and successful.

## Echo Example

Create Namespace and ArgoCD application:

```bash
kubectl create namespace echo

argocd app create echo --repo https://github.com/dafywinf/argocd-deployment.git \
  --path argo-apps/echo --dest-server https://kubernetes.default.svc --dest-namespace echo \
  --sync-policy auto
```

Delete ArgoCD application and Namespace:

```bash
argocd app delete echo --yes
kubectl delete namespace echo
```

## Guestbook UI Example

Create Namespace and ArgoCD application:

```bash
kubectl create namespace guestbook

argocd app create guestbook --repo https://github.com/dafywinf/argocd-deployment.git \
  --path argo-apps/guestbook-ui --dest-server https://kubernetes.default.svc --dest-namespace guestbook \
  --sync-policy auto
```

Delete ArgoCD application and Namespace:

```bash
argocd app delete guestbook --yes
kubectl delete namespace guestbook
```

# Appendix

## Technical Background

### Bitnami ArgoCd Resource Presets

**Note:** Use for production workloads is discouraged as may not fully adapt to specific needs.

https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl#L15

```bash
  "nano" (dict 
      "requests" (dict "cpu" "100m" "memory" "128Mi" "ephemeral-storage" "50Mi")
      "limits" (dict "cpu" "150m" "memory" "192Mi" "ephemeral-storage" "2Gi")
   )
  "micro" (dict 
      "requests" (dict "cpu" "250m" "memory" "256Mi" "ephemeral-storage" "50Mi")
      "limits" (dict "cpu" "375m" "memory" "384Mi" "ephemeral-storage" "2Gi")
   )
  "small" (dict 
      "requests" (dict "cpu" "500m" "memory" "512Mi" "ephemeral-storage" "50Mi")
      "limits" (dict "cpu" "750m" "memory" "768Mi" "ephemeral-storage" "2Gi")
   )
  "medium" (dict 
      "requests" (dict "cpu" "500m" "memory" "1024Mi" "ephemeral-storage" "50Mi")
      "limits" (dict "cpu" "750m" "memory" "1536Mi" "ephemeral-storage" "2Gi")
   )
  "large" (dict 
      "requests" (dict "cpu" "1.0" "memory" "2048Mi" "ephemeral-storage" "50Mi")
      "limits" (dict "cpu" "1.5" "memory" "3072Mi" "ephemeral-storage" "2Gi")
   )
  "xlarge" (dict 
      "requests" (dict "cpu" "1.0" "memory" "3072Mi" "ephemeral-storage" "50Mi")
      "limits" (dict "cpu" "3.0" "memory" "6144Mi" "ephemeral-storage" "2Gi")
   )
  "2xlarge" (dict 
      "requests" (dict "cpu" "1.0" "memory" "3072Mi" "ephemeral-storage" "50Mi")
      "limits" (dict "cpu" "6.0" "memory" "12288Mi" "ephemeral-storage" "2Gi")
   )
```

### Rolling vs Immutable Tags

It is strongly recommended to use immutable tags in production so that deployments don't change automatically if the
same tag is updated with a different image.

### Ingress

This chart provides support for Ingress resources. If you have an ingress controller installed on your cluster, such as
nginx-ingress-controller or contour you can utilize the ingress controller to serve your application.To enable Ingress
integration, set server.ingress.enabled to true for the http ingress or server.grpcIngress.enabled to true for the gRPC
ingress.

The most common scenario is to have one host name mapped to the deployment. In this case, the xxx.ingress.hostname
property can be used to set the host name. The xxx.ingress.tls parameter can be used to add the TLS configuration for
this host.

However, it is also possible to have more than one host. To facilitate this, the xxx.ingress.extraHosts parameter (if
available) can be set with the host names specified as an array. The xxx.ingress.extraTLS parameter (if available) can
also be used to add the TLS configuration for extra hosts.

Adding the TLS parameter (where available) will cause the chart to generate HTTPS URLs, and the application will be
available on port 443. The actual TLS secrets do not have to be generated by this chart. However, if TLS is enabled, the
Ingress record will not work until the TLS secret exists.

## References

* https://medium.com/@jojoooo/deploy-infra-stack-using-self-managed-argocd-with-cert-manager-externaldns-external-secrets-op-640fe8c1587b
* https://medium.com/devopsturkiye/self-managed-argo-cd-app-of-everything-a226eb100cf0