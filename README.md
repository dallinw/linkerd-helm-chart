# Linkerd Service Mesh Setup

The setup for linkerd is fairly straightforward. There are two installation paths you will follow, depending no use case and deployment.

## Requirements
- Kubernetes cluster
- No service mesh already installed in it
- Kubectl with a configured context to connect to the cluster
- Helm v3+

For local development, you will need to follow the documentation here to get get started. Note however that if you choose to generate your own mTLS certs, you must take charge of issuing, and refreshing them on your own.

The recommended approach is the one in this link, which will automatically rotate the certs.

https://linkerd.io/2.12/tasks/automatically-rotating-control-plane-tls-credentials/

The only method we should install, and upgrade, deployment in Kubernetes is Helm. For documentation into the why and hows of doing so, please refer to kubernetes CI/CD and management best practices.

## Installation

It is recommended, since we must use mTLS between the services in the cluster, to configure an automatic certificate rotation and management service to do so for you. The command you can follow in the above link along with the `cert-manager` helm installation documentation, but is essentially this command.

```
helm install \
    cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --version v1.10.0 \
    --set installCRDs=true
```
Afterworks when we have this baseline automation in place, we begin by installing the Linkerd kubernetes custom resource definitions. It is a single command install.

```
helm install linkerd-crds linkerd/linkerd-crds -n linkerd --create-namespace 
```

This however only sets up the customer resources to be used. We must then install and configure the service mesh control plane like so, beginning with initial certificate generation.

```
step certificate create root.linkerd.cluster.local ca.crt ca.key \
    --profile root-ca --no-password --insecure &&
    kubectl create secret tls \
    linkerd-trust-anchor \
    --cert=ca.crt \
    --key=ca.key \
    --namespace=linkerd
```

This `step` command will spit out two files into your current directory, the certificate and the private key, which will then be stored in a secret inside the cluster. Please delete these files after generation and control plane install.

You can then install the app like so.

```
helm upgrade -i \
    --namespace linkerd \
    --create-namespace \
    linkerd-control-plane \
    linkerd/linkerd-control-plane \
    -f values.yaml \
    --atomic
```

You can also run kubectl apply to the given certificate file conveniently provided in the `setup` directory, after cert-manager is installed to Kubernetes, to configure the certificate issuance for you.

`kubectl apply -f setup/certificate.yaml`

## Post-Install

Just because you installed it, doesn't mean the services are using it or configured to do so. This is done on a per namespace basis.

To do so you simple run `kubectl annotate <created-namespace> "linkerd.io/inject=enabled"`

#### Reference
https://linkerd.io/2.12/features/proxy-injection/
