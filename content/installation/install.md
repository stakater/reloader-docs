# Reloader Enterprise (RE) Installation

Reloader Enterprise (RE) is distributed through **GitHub Container Registry (`GHCR`)**. Access to enterprise images is granted **through GitHub**, using a private package-proxy repository.

To install Reloader Enterprise, customers must:

1. Have an active Reloader Enterprise subscription  
1. Receive access to the private package registry  
1. Authenticate their Kubernetes cluster to pull the enterprise image  
1. Install using the OSS Helm chart with enterprise overrides  

This section explains how access is granted and how to perform the installation.

## How Access to Reloader Enterprise Is Granted?

Stakater provides access to Reloader Enterprise through a **private GitHub package proxy repository**.

When you are added as a customer:

- You receive the **`read`** role  
- You can **pull** Reloader Enterprise images  
- You can view contributors  
- You **cannot** create branches, modify the code, or view other collaborators  

The repository acts as a **proxy** to private build sources.  
It does **not** build artifacts itself.

Access is available only to active Reloader Enterprise customers.

## Installation Overview

After access is granted, you may install Reloader Enterprise in one of two ways:

### **Option A — Use Your GitHub User**

You provide Stakater with your GitHub username.  
This user is added as a collaborator to the enterprise package repository.

### **Option B — Use a Token Provided by Stakater**

Stakater issues a dedicated `reloader-enterprise` access token.

Both methods require creating a Kubernetes registry secret and running a Helm install.

## Installation Method A — Using Your GitHub User

### Step 1 — Become a collaborator

Stakater adds your GitHub user to the private enterprise package proxy.  
You must accept the GitHub invitation.

### Step 2 — Create a GitHub Personal Access Token (PAT)

Create a token with the following scope:

- `read:packages`

### Step 3 — Store the PAT in Kubernetes

```bash
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-token>
```

### Step 4 — Install Reloader Enterprise via Helm

```bash
helm install stakater/reloader \
  --set image.repository=ghcr.io/stakater/reloader-enterprise \
  --set image.tag=<version> \
  --set "global.imagePullSecrets[0].name=regcred" \
  --generate-name
```

## Installation Method B — Using a Token Provided by Stakater

### Step 1 — Request a Stakater-issued token

This token is tied to the `reloader-enterprise` GitHub service account.

### Step 2 — Store the token in Kubernetes

```bash
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=reloader-enterprise \
  --docker-password=<token-from-stakater>
```

### Step 3 — Install the enterprise image via Helm

```bash
helm install stakater/reloader \
  --set image.repository=ghcr.io/stakater/reloader-enterprise \
  --set image.tag=<version> \
  --set "global.imagePullSecrets[0].name=regcred" \
  --generate-name
```

## Checking Available Versions

Reloader Enterprise uses the same image tags as the open-source version,
but only versions that have passed enterprise-grade validation are published.

### View versions in GitHub Packages

[https://github.com/stakater/reloader-enterprise-package-proxy/pkgs/container/reloader-enterprise](https://github.com/stakater/reloader-enterprise-package-proxy/pkgs/container/reloader-enterprise)

### Or via GitHub API

```bash
curl -L \
 -H "Accept: application/vnd.github+json" \
 -H "Authorization: Bearer <token>" \
 -H "X-GitHub-Api-Version: 2022-11-28" \
 https://api.github.com/orgs/stakater/packages/container/reloader-enterprise/versions
```

## Access Requirements

Access to the enterprise package repository is granted **only** to organizations with an active Reloader Enterprise subscription.
If the subscription expires, access is automatically revoked.
