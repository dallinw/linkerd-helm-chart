#!/usr/bin/env zsh

# Prep
rm -Rf linkerd-control-plane
rm ca.key
rm ca.crt

# Point at docker-desktop
kubectl config use-context docker-desktop

# Ambassador ingress
helm repo add datawire https://app.getambassador.io
helm repo update

kubectl create namespace ambassador
kubectl apply -f https://app.getambassador.io/yaml/edge-stack/latest/aes-crds.yaml

# Brittle but works for local so it's all good, goes up and over to the ambassador project
helm upgrade -i edge-stack \
--namespace ambassador \
datawire/edge-stack \
--set emissary-ingress.createDefaultListeners=true \
--set emissary-ingress.agent.cloudConnectToken=$AMBASSADOR_CLOUD_TOKEN \
-f ../ambassador-helm-chart/values.yaml

# Cert manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade -i \
    cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --version v1.10.0 \
    --set installCRDs=true

# Linkerd service mesh
helm repo add linkerd https://helm.linkerd.io/stable
helm repo update

helm install linkerd-crds linkerd/linkerd-crds -n linkerd --create-namespace

step certificate create root.linkerd.cluster.local ca.crt ca.key \
    --profile root-ca --no-password --insecure &&
kubectl create secret tls \
linkerd-trust-anchor \
--cert=ca.crt \
--key=ca.key \
--namespace=linkerd

helm fetch --untar linkerd/linkerd-control-plane && \
helm upgrade -i \
    --namespace linkerd \
    --create-namespace \
    linkerd-control-plane \
    linkerd/linkerd-control-plane \
    --set-file identityTrustAnchorsPEM=ca.crt \
    --set identity.issuer.scheme=kubernetes.io/tls \
    -f values.yaml \
    --atomic

kubectl apply -f setup/certificate.yaml

# Linkerd Dashboard

helm upgrade -i linkerd-viz linkerd/linkerd-viz --namespace linkerd-viz --create-namespace

# Post config
kubectl create namespace services
kubectl annotate namespace services "linkerd.io/inject=enabled"
kubectl config set-context --current --namespace=services
