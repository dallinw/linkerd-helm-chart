#!/usr/bin/env zsh

# Small util script to redeploy a whole cluster from scratch. It is for local use and of course not an ideal solution.

# Point at docker-desktop, make sure to not point at any other cluster
kubectl config use-context docker-desktop

# Prep, delete old data if it exists
kubectl delete namespace linkerd
kubectl delete namespace ambassador
kubectl delete namespace services
kubectl delete namespace linkerd-viz

# remove temp files, if they exist
rm -Rf linkerd-control-plane
rm ca.key
rm ca.crt

# Ambassador ingress
helm repo add datawire https://app.getambassador.io
helm repo update

# Create the namespace, and the remote CRD's have coded inside namespace designators.
kubectl create namespace ambassador
kubectl apply -f https://app.getambassador.io/yaml/edge-stack/latest/aes-crds.yaml

# Brittle but works for local so it's all good, goes up and over to the ambassador project
helm upgrade -i edge-stack \
--namespace ambassador \
datawire/edge-stack \
--set emissary-ingress.createDefaultListeners=true \
--set emissary-ingress.agent.cloudConnectToken=$AMBASSADOR_CLOUD_TOKEN \
-f ../ambassador-helm-chart/values.yaml

# Cert manager, used for intra-service mTLS
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

# Install linkerd CRD's
helm install linkerd-crds linkerd/linkerd-crds -n linkerd --create-namespace

# Create local seed cert CA
step certificate create root.linkerd.cluster.local ca.crt ca.key \
    --profile root-ca --no-password --insecure

kubectl create secret tls \
linkerd-trust-anchor \
--cert=ca.crt \
--key=ca.key \
--namespace=linkerd

# Apply the special linkerd to cert manager tie-in
kubectl apply -f setup/certificates.yaml

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

# Linkerd Dashboard
helm upgrade -i linkerd-viz linkerd/linkerd-viz --namespace linkerd-viz --create-namespace

# Post config
kubectl create namespace services
kubectl annotate namespace services "linkerd.io/inject=enabled" --overwrite
kubectl config set-context --current --namespace=services
