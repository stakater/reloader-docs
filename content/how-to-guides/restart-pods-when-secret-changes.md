# Restart Pods When Secret Changes in Kubernetes

Applications running in Kubernetes often depend on **Secrets** for sensitive configuration such as database credentials, API tokens, or encryption keys.

When a Secret is updated, running pods **do not automatically restart**. This means applications may continue using outdated credentials until the pods are restarted.

This guide explains how to ensure pods automatically restart when Secrets change.

---

## The Problem

Updating a Secret does not trigger a rollout of workloads that reference it.

Example:

```bash
kubectl apply -f secret.yaml
```

Result:

```bash
Secret updated
↓
Pods continue running
↓
Application still uses old credentials
```

This behavior exists because Kubernetes only performs a rollout when the **Pod specification changes**, not when referenced Secrets are modified.

---

## Why This Matters

Secrets often change during normal operations.

Examples include:

* database password rotation
* API key updates
* token refresh
* TLS certificate updates

If pods are not restarted, applications may continue using **expired or invalid credentials**, which can lead to service outages.

---

## Common Approaches

### 1. Manual Restart

A common solution is to manually restart the workload.

```bash
kubectl rollout restart deployment my-app
```

Result:

```bash
Secret updated
↓
Operator restarts deployment
↓
New pods created
↓
Application loads new secret
```

**Limitations**

* Requires manual intervention
* Easy to forget
* Difficult to manage across many workloads

---

### 2. Helm Checksum Annotations

Helm charts sometimes include checksum annotations that trigger restarts when secrets change.

Example:

```yaml
metadata:
  annotations:
    checksum/secret: {{ include (print $.Template.BasePath "/secret.yaml") . | sha256sum }}
```

When the secret changes and Helm runs again, the checksum changes and the deployment rolls out.

**Limitations**

* Requires modifying Helm charts
* Only works when Helm upgrades occur
* Does not react to runtime secret updates

---

## Automatic Restart with Reloader

A more reliable solution is to use **Reloader**, a Kubernetes controller that watches for changes in:

* Secrets
* ConfigMaps

When one of these resources changes, Reloader automatically triggers a rolling restart of workloads that reference them.

Workflow:

```bash
Secret updated
↓
Reloader detects change
↓
Deployment patched
↓
Kubernetes rolling restart triggered
```

This ensures applications restart and load the latest credentials.

---

## Step-by-Step Example

### 1. Create a Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-secret
type: Opaque
stringData:
  DB_PASSWORD: supersecret
```

Apply the secret:

```bash
kubectl apply -f secret.yaml
```

---

### 2. Create a Deployment Using the Secret

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
      - name: app
        image: nginx
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: DB_PASSWORD
```

---

### 3. Enable Reloader

Add the following annotation to the Deployment:

```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
```

This enables automatic restarts when referenced configuration resources change.

---

### 4. Update the Secret

Modify the secret:

```yaml
DB_PASSWORD: newpassword
```

Apply the update:

```bash
kubectl apply -f secret.yaml
```

Result:

```bash
Secret updated
↓
Reloader detects change
↓
Deployment patched
↓
New pod created
↓
Application loads new credentials
```

---

## Verifying the Restart

You can observe the rollout with:

```bash
kubectl rollout status deployment demo-app
```

Or monitor pods:

```bash
kubectl get pods -w
```

You will see a new pod created automatically when the Secret changes.

---

## When This Pattern Is Useful

Automatically restarting pods when Secrets change is useful when:

* credentials rotate regularly
* tokens or API keys expire
* certificate secrets are updated
* external secret managers synchronize secrets

---

## Summary

Updating a Secret in Kubernetes does not automatically restart pods that use it.

Manual restarts and Helm-based checksums can help, but they require additional operational steps.

Using Reloader allows workloads to **automatically restart when Secrets change**, ensuring applications always run with the latest credentials.

---

## FAQ

### Do Secret changes automatically restart pods in Kubernetes?

No. Kubernetes does not automatically restart pods when Secrets change.

### Why doesn't Kubernetes restart pods when Secrets update?

Kubernetes only triggers rollouts when the Pod specification changes, not when referenced resources change.

### How can I automatically restart pods when Secrets change?

You can use a controller such as Reloader to watch for Secret updates and trigger rolling restarts automatically.
