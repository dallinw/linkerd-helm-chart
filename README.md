# Linkerd Service Mesh Setup

The setup for linkerd is fairly straightforward. There are two installation paths you will follow, depending no use case and deployment.

## Requirements
- Kubernetes cluster
- No service mesh already installed in it
- Kubectl with a configured context to connect to the cluster
- Helm v3+

For local development, you will need to follow the documentation here to get get started. Note however that if you choose to generate your own mTLS certs, you must take charge of issuing, and refreshing them on your own.

The recommended approach is the one in this link.

https://linkerd.io/2.12/tasks/automatically-rotating-control-plane-tls-credentials/

The only method we should install, and upgrade, deployment in Kubernetes is Helm. For documentation into the why and hows of doing so, please refer to the DevOps documentation in Confluence.

You can also run kubectl apply to the given certificate file, after cert-manager is installed to Kubernetes, to configure the certificate issuance for you.

## Post-Install

Just because you installed it, doesn't mean the services are using it or configured to do so. This is done on a per namespace basis.

To do so you simple run `kubectl annotate <created-namespace> "linkerd.io/inject=enabled"`

#### Reference
https://linkerd.io/2.12/features/proxy-injection/
