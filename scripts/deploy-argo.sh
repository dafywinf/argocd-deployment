#!/bin/bash

ARGO_CHART_VERSION="5.51.0"
ARGO_APP_NAME="argocd-helm"
ARGO_NAMESPACE="argocd"
ARGO_HELM_CHART_PATH="https://github.com/dafywinf/argocd-deployment/blob/main/argo-apps/base/argocd-helm.yaml"

message() {
  echo -e "\n######################################################################"
  echo "# $1"
  echo "######################################################################"
}

verifyDependencies() {
[[ ! -x "$(command -v kubectl)" ]] && echo "kubectl not found, you need to install kubectl" && exit 1
[[ ! -x "$(command -v helm)" ]] && echo "helm not found, you need to install helm" && exit 1
[[ ! -x "$(command -v argocd)" ]] && echo "argocd not found, you need to install argocd-cli" && exit 1
}

installArgoCD() {
  message ">>> deploying ArgoCD"

  # Install chart
  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo update
  helm uninstall $ARGO_APP_NAME --namespace=$ARGO_NAMESPACE
  helm install $ARGO_APP_NAME argo/argo-cd --create-namespace --namespace=$ARGO_NAMESPACE --version $ARGO_CHART_VERSION \
    --set fullnameOverride=argocd \
    --set applicationSet.enabled=false \
    --set notifications.enabled=false \
    --set dex.enabled=false \
    --set configs.cm."kustomize\.buildOptions"="--load-restrictor LoadRestrictionsNone"

  kubectl -n argocd rollout status deployment/argocd-server
}

setupSelfManagedArgoCD() {
  kubectl apply -f $ARGO_HELM_CHART_PATH
  message ">>> Awaiting ArgoCD to sync..."
  export ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
  until argocd login --core --username admin --password $ARGOCD_PWD --insecure; do :; done
  kubectl config set-context --current --namespace=$ARGO_NAMESPACE
  until argocd app sync $ARGO_APP_NAME; do echo "awaiting argocd to be sync..." && sleep 10; done
  kubectl -n argocd rollout status deployment/argocd-repo-server
}

installArgoApplications() {
  message ">>> deploying ArgoCD infra-applications"
  kubectl apply -f argo-apps-infra.yaml
  kubectl apply -f argo-apps.yaml
  until argocd app sync argo-apps-infra; do echo "awaiting applications-infra to be sync..." && sleep 10; done
}

verifyDependencies
#installArgoCD
setupSelfManagedArgoCD
# installArgoApplications

#message ">>> username: 'admin', password: '$ARGOCD_PWD'"

# kubectl port-forward service/argocd-server -n argocd 8080:443
