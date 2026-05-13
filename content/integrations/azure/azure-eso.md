# How to Use Reloader with Azure Key Vault and External Secrets Operator

This guide explains how to sync secrets from Azure Key Vault into Kubernetes using External Secrets Operator (ESO), and use Stakater Reloader to automatically restart pods when those secrets change.

## Authentication Options

ESO supports two authentication methods for Azure Key Vault:

| Method | Description | Use Case |
|--------|-------------|----------|
| [**Workload Identity**](#option-1-workload-identity) | Azure managed identity bound to a Kubernetes ServiceAccount | Recommended for AKS — no static credentials |
| [**Client Secret**](#option-2-client-secret) | Azure App Registration client ID and secret stored in a K8s Secret | Any cluster — simpler but requires secret rotation |

## Overview

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Kubernetes Cluster                                 │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                    External Secrets Operator                            │ │
│  │                                                                         │ │
│  │  ┌─────────────────┐         ┌──────────────────────────────────────┐  │ │
│  │  │  SecretStore    │         │  ExternalSecret                      │  │ │
│  │  │                 │         │                                      │  │ │
│  │  │  - Vault URL    │         │  - refreshInterval: 1h               │  │ │
│  │  │  - Auth method  │────────►│  - Maps AKV secret to K8s Secret     │  │ │
│  │  │  - Tenant ID    │         │  - Adds Reloader annotation          │  │ │
│  │  └─────────────────┘         └──────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                       │
│                                      ▼                                       │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐       │
│  │   K8s Secret     │    │  Stakater        │    │  Application     │       │
│  │   (app-secrets)  │───►│  Reloader        │───►│  Pod             │       │
│  │   match: "true"  │    │  watches secret  │    │  rolling restart │       │
│  └──────────────────┘    └──────────────────┘    └──────────────────┘       │
│            ▲                                                                 │
│   ┌─────────────────┐                                                       │
│   │  Azure Key Vault│                                                       │
│   └─────────────────┘                                                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Kubernetes cluster (v1.19+)
- Helm v3+
- Azure subscription with an existing Key Vault
- Azure CLI configured locally
- Stakater Reloader installed
- External Secrets Operator installed

### Create secrets in Azure Key Vault

```bash
# Set your Key Vault name
VAULT_NAME=my-key-vault

# Create individual secrets
az keyvault secret set \
  --vault-name $VAULT_NAME \
  --name myapp-username \
  --value "admin-user"

az keyvault secret set \
  --vault-name $VAULT_NAME \
  --name myapp-password \
  --value "super-secret-password"
```

### Install Stakater Reloader

```bash
helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update
helm install reloader stakater/reloader --namespace reloader --create-namespace
```

### Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --wait
```

Verify:

```bash
kubectl get pods -n external-secrets
```

---

## Option 1: Workload Identity

Azure Workload Identity lets a Kubernetes ServiceAccount authenticate to Azure services without storing credentials. It is the recommended approach for AKS clusters.

### Workload Identity: Step 1 — Enable Workload Identity on your AKS cluster

```bash
az aks update \
  --name my-cluster \
  --resource-group my-rg \
  --enable-oidc-issuer \
  --enable-workload-identity
```

Get the OIDC issuer URL:

```bash
OIDC_ISSUER=$(az aks show \
  --name my-cluster \
  --resource-group my-rg \
  --query "oidcIssuerProfile.issuerUrl" \
  --output tsv)
```

### Workload Identity: Step 2 — Create an Azure managed identity

```bash
az identity create \
  --name eso-identity \
  --resource-group my-rg \
  --location eastus

IDENTITY_CLIENT_ID=$(az identity show \
  --name eso-identity \
  --resource-group my-rg \
  --query clientId \
  --output tsv)

IDENTITY_OBJECT_ID=$(az identity show \
  --name eso-identity \
  --resource-group my-rg \
  --query principalId \
  --output tsv)
```

### Workload Identity: Step 3 — Grant Key Vault access to the managed identity

```bash
VAULT_ID=$(az keyvault show \
  --name $VAULT_NAME \
  --query id \
  --output tsv)

# Assign the Key Vault Secrets User role (read-only access to secret values)
az role assignment create \
  --assignee-object-id $IDENTITY_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" \
  --scope $VAULT_ID
```

> If your Key Vault still uses the legacy access policy model instead of Azure RBAC, use:
> ```bash
> az keyvault set-policy \
>   --name $VAULT_NAME \
>   --object-id $IDENTITY_OBJECT_ID \
>   --secret-permissions get list
> ```

### Workload Identity: Step 4 — Create namespace and Kubernetes ServiceAccount

```bash
kubectl create namespace azure-eso-test

kubectl create serviceaccount eso-sa -n azure-eso-test \
  --dry-run=client -o yaml | \
  kubectl annotate --local -f - \
    "azure.workload.identity/client-id=${IDENTITY_CLIENT_ID}" \
    --dry-run=client -o yaml | kubectl apply -f -
```

Or create the manifest directly:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: eso-sa
  namespace: azure-eso-test
  annotations:
    azure.workload.identity/client-id: "<IDENTITY_CLIENT_ID>"
```

### Workload Identity: Step 5 — Create the federated identity credential

This binds the Kubernetes ServiceAccount to the Azure managed identity:

```bash
az identity federated-credential create \
  --name eso-federated-credential \
  --identity-name eso-identity \
  --resource-group my-rg \
  --issuer "$OIDC_ISSUER" \
  --subject "system:serviceaccount:azure-eso-test:eso-sa" \
  --audience api://AzureADTokenExchange
```

### Workload Identity: Step 6 — Create SecretStore

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: azure-secret-store
  namespace: azure-eso-test
spec:
  provider:
    azurekv:
      authType: WorkloadIdentity
      vaultUrl: "https://my-key-vault.vault.azure.net"
      serviceAccountRef:
        name: eso-sa
```

Apply and verify:

```bash
kubectl apply -f secret-store.yaml
kubectl get secretstore -n azure-eso-test
```

Should show `STATUS: Valid` and `READY: True`.

Now proceed to [Create ExternalSecret](#create-externalsecret).

---

## Option 2: Client Secret

Use an Azure App Registration client secret stored in a Kubernetes Secret. Works with any Kubernetes cluster, not just AKS.

### Client Secret: Step 1 — Create an App Registration

```bash
APP_ID=$(az ad app create \
  --display-name eso-app \
  --query appId \
  --output tsv)

# Create a service principal for the app
az ad sp create --id $APP_ID

TENANT_ID=$(az account show --query tenantId --output tsv)

# Create a client secret (note the value — it is shown only once)
CLIENT_SECRET=$(az ad app credential reset \
  --id $APP_ID \
  --query password \
  --output tsv)
```

### Client Secret: Step 2 — Grant Key Vault access to the App Registration

```bash
SP_OBJECT_ID=$(az ad sp show --id $APP_ID --query id --output tsv)

VAULT_ID=$(az keyvault show --name $VAULT_NAME --query id --output tsv)

az role assignment create \
  --assignee-object-id $SP_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" \
  --scope $VAULT_ID
```

> For Key Vaults using access policies:
> ```bash
> az keyvault set-policy \
>   --name $VAULT_NAME \
>   --spn $APP_ID \
>   --secret-permissions get list
> ```

### Client Secret: Step 3 — Store credentials in a Kubernetes Secret

```bash
kubectl create namespace azure-eso-test

kubectl create secret generic azure-credentials -n azure-eso-test \
  --from-literal=client-id="$APP_ID" \
  --from-literal=client-secret="$CLIENT_SECRET"
```

### Client Secret: Step 4 — Create SecretStore

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: azure-secret-store
  namespace: azure-eso-test
spec:
  provider:
    azurekv:
      authType: ServicePrincipal
      vaultUrl: "https://my-key-vault.vault.azure.net"
      tenantId: "<TENANT_ID>"
      authSecretRef:
        clientId:
          name: azure-credentials
          key: client-id
        clientSecret:
          name: azure-credentials
          key: client-secret
```

Apply and verify:

```bash
kubectl apply -f secret-store.yaml
kubectl get secretstore -n azure-eso-test
```

Should show `STATUS: Valid` and `READY: True`.

Now proceed to [Create ExternalSecret](#create-externalsecret).

---

## Common Configuration

The following steps apply to both authentication methods.

## Create ExternalSecret

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: azure-eso-test
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: azure-secret-store
    kind: SecretStore
  target:
    name: app-secrets
    creationPolicy: Owner
    template:
      metadata:
        annotations:
          reloader.stakater.com/match: "true"
  data:
    - secretKey: username
      remoteRef:
        key: myapp-username
    - secretKey: password
      remoteRef:
        key: myapp-password
```

Apply and verify:

```bash
kubectl apply -f external-secret.yaml
kubectl get externalsecret -n azure-eso-test
```

Should show `STATUS: SecretSynced` and `READY: True`.

## Deploy Application

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: azure-eso-test-app
  namespace: azure-eso-test
  annotations:
    reloader.stakater.com/search: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: azure-eso-test-app
  template:
    metadata:
      labels:
        app: azure-eso-test-app
    spec:
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
```

Apply:

```bash
kubectl apply -f deployment.yaml
```

## Verify the Setup

```bash
# SecretStore
kubectl get secretstore -n azure-eso-test

# ExternalSecret
kubectl get externalsecret -n azure-eso-test

# Secret (created by ESO)
kubectl get secret app-secrets -n azure-eso-test

# Pod
kubectl get pods -n azure-eso-test

# Verify secret contents
kubectl get secret app-secrets -n azure-eso-test -o jsonpath='{.data.password}' | base64 -d

# Check app logs
kubectl logs -n azure-eso-test -l app=azure-eso-test-app
```

## Test Secret Rotation

### Update the secret in Azure Key Vault

```bash
az keyvault secret set \
  --vault-name $VAULT_NAME \
  --name myapp-password \
  --value "new-rotated-password"
```

Azure Key Vault retains all previous versions. ESO always reads the **latest enabled version** unless a specific version is pinned in the `ExternalSecret`.

### Wait and verify

To force an immediate ESO sync without waiting for `refreshInterval`:

```bash
kubectl annotate externalsecret app-secrets -n azure-eso-test \
  force-sync=$(date +%s) --overwrite
```

Then verify:

```bash
# Check secret was updated
kubectl get secret app-secrets -n azure-eso-test -o jsonpath='{.data.password}' | base64 -d

# Check pod was restarted
kubectl get pods -n azure-eso-test -l app=azure-eso-test-app

# Check app logs show new password
kubectl logs -n azure-eso-test -l app=azure-eso-test-app --tail=5
```

---

## Configuration Reference

### SecretStore — Workload Identity

| Field | Description |
|-------|-------------|
| `provider.azurekv.authType` | `WorkloadIdentity` |
| `provider.azurekv.vaultUrl` | Full URL of the Azure Key Vault (e.g. `https://my-vault.vault.azure.net`) |
| `provider.azurekv.serviceAccountRef.name` | Kubernetes ServiceAccount annotated with the managed identity client ID |

### SecretStore — Client Secret

| Field | Description |
|-------|-------------|
| `provider.azurekv.authType` | `ServicePrincipal` |
| `provider.azurekv.vaultUrl` | Full URL of the Azure Key Vault |
| `provider.azurekv.tenantId` | Azure Active Directory tenant ID |
| `provider.azurekv.authSecretRef.clientId` | K8s Secret and key containing the App Registration client ID |
| `provider.azurekv.authSecretRef.clientSecret` | K8s Secret and key containing the client secret value |

### ExternalSecret

| Field | Description |
|-------|-------------|
| `refreshInterval` | How often ESO polls Azure for changes (e.g. `1h`, `5m`) |
| `secretStoreRef` | Reference to the SecretStore |
| `target.name` | Name of the K8s Secret to create |
| `target.template.metadata.annotations` | Annotations to add to the created Secret |
| `data[].secretKey` | Key name in the K8s Secret |
| `data[].remoteRef.key` | Azure Key Vault secret name |
| `data[].remoteRef.version` | (Optional) Specific secret version. Omit to use the latest. |

### Reloader Annotations

| Resource | Annotation |
|----------|------------|
| Deployment | `reloader.stakater.com/search: "true"` |
| Secret (via ExternalSecret template) | `reloader.stakater.com/match: "true"` |

---

## Comparison: Workload Identity vs Client Secret

| Aspect | Workload Identity | Client Secret |
|--------|-------------------|---------------|
| **Credentials** | No static secret — short-lived federated tokens | Long-lived client secret |
| **Security** | No credentials to leak or rotate | Client secret must be rotated before expiry |
| **Cluster requirement** | AKS with OIDC issuer + Workload Identity enabled | Any Kubernetes cluster |
| **Setup complexity** | Requires managed identity + federated credential binding | Just an App Registration + K8s Secret |
| **Best for** | Production on AKS | Development, non-AKS clusters |
