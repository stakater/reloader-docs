# How to Use Reloader with OpenBao CSI Driver Pattern

This guide demonstrates integrating OpenBao with Stakater Reloader using the Secrets Store CSI Driver with the OpenBao CSI Provider.

## Overview

The CSI (Container Storage Interface) pattern mounts secrets from OpenBao directly into pods as volume files. Using the `secretObjects` feature, secrets are also synced to Kubernetes Secrets, enabling Reloader integration.

```text
┌─────────────────────────────────────────────────────────────────────┐
│                         Kubernetes Cluster                          │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    Application Namespace                       │  │
│  │                                                                │  │
│  │  ┌─────────────────┐    ┌──────────────────────────────────┐  │  │
│  │  │ SecretProvider  │    │         Application Pod          │  │  │
│  │  │     Class       │    │  ┌────────────────────────────┐  │  │  │
│  │  │                 │    │  │  CSI Volume Mount          │  │  │  │
│  │  │ - provider:     │    │  │  /mnt/secrets/             │  │  │  │
│  │  │   openbao       │    │  │    ├── username            │  │  │  │
│  │  │ - secretObjects │    │  │    └── password            │  │  │  │
│  │  │ - parameters    │    │  └────────────────────────────┘  │  │  │
│  │  └────────┬────────┘    └──────────────────────────────────┘  │  │
│  │           │                              ▲                     │  │
│  │           │                              │                     │  │
│  │           │              ┌───────────────┴───────────────┐    │  │
│  │           │              │                               │    │  │
│  │           ▼              │     Secrets Store CSI         │    │  │
│  │  ┌────────────────┐      │         Driver                │    │  │
│  │  │ K8s Secret     │◄─────┤  (syncs to K8s Secret via     │    │  │
│  │  │ (app-secrets)  │      │   secretObjects)              │    │  │
│  │  │                │      │                               │    │  │
│  │  │ annotations:   │      └───────────────┬───────────────┘    │  │
│  │  │  reloader...   │                      │                    │  │
│  │  │  match: true   │                      │                    │  │
│  │  └───────┬────────┘                      │                    │  │
│  │          │                               │                    │  │
│  └──────────┼───────────────────────────────┼────────────────────┘  │
│             │                               │                       │
│             ▼                               ▼                       │
│  ┌─────────────────────┐         ┌─────────────────────┐           │
│  │  Stakater Reloader  │         │  OpenBao CSI        │           │
│  │                     │         │    Provider         │           │
│  │  Watches secrets    │         │                     │           │
│  │  with match: true   │         │  Fetches secrets    │           │
│  │                     │         │  from OpenBao       │           │
│  └─────────────────────┘         └──────────┬──────────┘           │
│                                             │                       │
└─────────────────────────────────────────────┼───────────────────────┘
                                              │
                                              ▼
                                   ┌─────────────────────┐
                                   │      OpenBao        │
                                   │                     │
                                   │  KV v2 Secrets      │
                                   │  secret/myapp       │
                                   │                     │
                                   │  Kubernetes Auth    │
                                   └─────────────────────┘
```

## Prerequisites

Complete the common setup steps from the [Overview](index.md):

- OpenBao installed, initialized, and unsealed
- OpenBao CLI configured (`BAO_ADDR` and `BAO_TOKEN` exported)
- KV v2 secrets engine enabled
- Test secrets written to `secret/myapp`
- Stakater Reloader installed with search mode enabled

Additionally required:

- Secrets Store CSI Driver installed with syncSecret and rotation enabled
- OpenBao CSI Provider installed (included in OpenBao Helm chart)

> **Note:** All `bao` commands below assume `BAO_ADDR` and `BAO_TOKEN` are set from [Overview Step 3](index.md#step-3-configure-openbao-cli).

## Step 1: Install Secrets Store CSI Driver

Install with syncSecret and rotation enabled:

```bash
helm repo add secrets-store-csi-driver \
  https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo update

helm install csi-secrets-store \
  secrets-store-csi-driver/secrets-store-csi-driver \
  -n kube-system \
  --set syncSecret.enabled=true \
  --set enableSecretRotation=true \
  --set rotationPollInterval=30s
```

## Step 2: Enable OpenBao CSI Provider

If not already enabled, upgrade OpenBao installation:

```bash
helm upgrade openbao openbao/openbao \
  -n openbao \
  --set csi.enabled=true \
  --reuse-values
```

Verify the CSI provider is running:

```bash
kubectl get pods -n openbao -l app.kubernetes.io/name=openbao-csi-provider
```

## Step 3: Configure OpenBao

### Create Read Policy

```bash
bao policy write myapp-read - <<EOF
path "secret/data/myapp" {
  capabilities = ["read"]
}
EOF
```

### Enable Kubernetes Auth

```bash
bao auth enable kubernetes

bao write auth/kubernetes/config \
    kubernetes_host='https://kubernetes.default.svc.cluster.local'
```

### Create Auth Role

```bash
bao write auth/kubernetes/role/openbao-csi-role \
    bound_service_account_names=openbao-csi-sa \
    bound_service_account_namespaces=openbao-csi-test \
    policies=myapp-read \
    ttl=1h
```

### Write Test Secret

```bash
bao kv put secret/myapp username=myuser password=mypassword
```

## Step 4: Create Application Namespace and ServiceAccount

```bash
kubectl create namespace openbao-csi-test
```

```yaml
# serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: openbao-csi-sa
  namespace: openbao-csi-test
```

## Step 5: Create SecretProviderClass

The `secretObjects` section syncs secrets to a Kubernetes Secret with the Reloader annotation:

```yaml
# secret-provider-class.yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: openbao-secrets
  namespace: openbao-csi-test
spec:
  provider: openbao
  secretObjects:
    - secretName: app-secrets
      type: Opaque
      annotations:
        reloader.stakater.com/match: "true"
      data:
        - objectName: username
          key: username
        - objectName: password
          key: password
  parameters:
    vaultAddress: "http://openbao.openbao.svc.cluster.local:8200"
    roleName: openbao-csi-role
    objects: |
      - objectName: "username"
        secretPath: "secret/data/myapp"
        secretKey: "username"
      - objectName: "password"
        secretPath: "secret/data/myapp"
        secretKey: "password"
```

**Key Configuration:**

- `provider: openbao` - Uses OpenBao CSI provider (not "vault")
- `secretObjects` - Syncs mounted secrets to Kubernetes Secret
- `annotations` - Reloader annotation for automatic restarts
- `parameters.vaultAddress` - Points to OpenBao service
- `parameters.roleName` - Kubernetes auth role name

## Step 6: Deploy Application

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openbao-csi-test-app
  namespace: openbao-csi-test
  annotations:
    reloader.stakater.com/search: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openbao-csi-test-app
  template:
    metadata:
      labels:
        app: openbao-csi-test-app
    spec:
      serviceAccountName: openbao-csi-sa
      containers:
        - name: app
          image: busybox:latest
          command:
            - "sh"
            - "-c"
            - |
              while true; do
                echo "Username: $APP_USERNAME"
                echo "Password: $APP_PASSWORD"
                sleep 30
              done
          env:
            - name: APP_USERNAME
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: username
            - name: APP_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: password
          volumeMounts:
            - name: secrets-store
              mountPath: "/mnt/secrets"
              readOnly: true
      volumes:
        - name: secrets-store
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: openbao-secrets
```

**Key Configuration:**

- `reloader.stakater.com/search: "true"` - Enables Reloader search mode
- `serviceAccountName` - Must match the auth role binding
- `volumeMounts` - Mounts secrets as files (optional but required for sync)
- `env` - References the synced Kubernetes Secret

## Step 7: Verify Setup

Apply manifests:

```bash
kubectl apply -f serviceaccount.yaml
kubectl apply -f secret-provider-class.yaml
kubectl apply -f deployment.yaml
```

Check pod is running:

```bash
kubectl get pods -n openbao-csi-test
```

Verify synced secret:

```bash
kubectl get secret app-secrets -n openbao-csi-test -o yaml
```

Check pod logs:

```bash
kubectl logs -n openbao-csi-test -l app=openbao-csi-test-app
```

## Step 8: Test Secret Rotation

Record current pod:

```bash
kubectl get pods -n openbao-csi-test -l app=openbao-csi-test-app
```

Update secret in OpenBao:

```bash
bao kv put secret/myapp username=myuser password=rotated-password
```

Wait for CSI rotation (based on rotationPollInterval) and Reloader:

```bash
# After ~30-60 seconds
kubectl get pods -n openbao-csi-test -l app=openbao-csi-test-app
kubectl logs -n openbao-csi-test -l app=openbao-csi-test-app --tail=5
```

The pod should show a new name and the updated password.

## How It Works

1. **CSI Driver mounts secrets** - When the pod starts, the CSI driver authenticates to OpenBao using Kubernetes auth and mounts secrets as files
1. **secretObjects sync** - The CSI driver creates/updates the Kubernetes Secret with the Reloader annotation
1. **Rotation polling** - CSI driver periodically polls OpenBao for changes (based on rotationPollInterval)
1. **Secret update** - When secrets change, CSI driver updates the Kubernetes Secret
1. **Reloader triggers restart** - Reloader detects the Secret change and performs a rolling restart of the Deployment

## Important Notes

### Provider Name

The OpenBao CSI provider uses `openbao` as the provider name, not `vault`:

```yaml
spec:
  provider: openbao  # NOT "vault"
```

### Rotation Settings

The CSI driver must have rotation enabled:

```bash
--set enableSecretRotation=true
--set rotationPollInterval=30s
```

### Volume Mount Required

The CSI volume must be mounted in the pod for `secretObjects` to work. The Kubernetes Secret is only created/updated when the pod is running with the volume mounted.

### Authentication

CSI uses Kubernetes auth with the pod's ServiceAccount. The ServiceAccount must be bound to an OpenBao role with appropriate policies.

## Troubleshooting

### Provider Not Found

```text
provider not found: provider "openbao"
```

Ensure OpenBao CSI provider is installed:

```bash
kubectl get pods -n openbao -l app.kubernetes.io/name=openbao-csi-provider
```

### Secret Not Syncing

1. Check CSI driver has syncSecret enabled
1. Verify pod is running with the CSI volume mounted
1. Check secretObjects configuration matches parameters.objects

### Authentication Errors

1. Verify ServiceAccount exists and is used by the pod
1. Check OpenBao role bindings match the namespace and ServiceAccount
1. Review OpenBao CSI provider logs:

```bash
kubectl logs -n openbao -l app.kubernetes.io/name=openbao-csi-provider -c openbao-csi-provider
```
