# Restart Pods When External Secrets Change in Kubernetes

Many Kubernetes platforms use external secret management systems to store sensitive data such as API keys, database credentials, and tokens.

These systems typically synchronize secrets into Kubernetes using a controller. When the external secret changes, the controller updates the corresponding **Kubernetes Secret**.

However, even after the Secret is updated, **running pods usually continue using the old values**.

This guide explains how to automatically restart pods when externally managed secrets change.

---

## The Problem

In Kubernetes, updating a Secret does **not automatically restart pods** that reference it.

Example workflow:

```bash
External secret updated
↓
Secret synchronization controller updates Kubernetes Secret
↓
Pods still running
↓
Application continues using old credentials
```

Unless the application supports dynamic secret reload, the new value will not be used until the pod restarts.

---

## Common External Secret Workflows

External secret systems typically follow a pattern like this:

```bash
Secret stored in external system
↓
Secret synchronization controller runs
↓
Kubernetes Secret created or updated
↓
Application consumes the Secret
```

Examples of external secret sources include:

* Vault systems
* cloud secret managers
* centralized credential stores
* automation pipelines

These systems ensure that Kubernetes Secrets remain up to date with external sources.

However, they usually **do not restart workloads when secrets change**.

---

## Why This Matters

Secrets often change due to:

* credential rotation
* security policies
* automation pipelines
* short-lived credentials

If applications continue running with outdated credentials, this can cause:

* authentication failures
* service disruptions
* expired credential errors

Automating workload restarts helps ensure applications always use the latest credentials.

---

## Automatic Restart with Reloader

Reloader is a Kubernetes controller that watches for changes in:

* Secrets
* ConfigMaps

When a Secret changes, Reloader automatically triggers a rolling restart of workloads that reference it.

Example workflow:

```bash
External secret updated
↓
Secret synchronization controller updates Kubernetes Secret
↓
Reloader detects change
↓
Deployment patched
↓
Pods restart automatically
```

This ensures applications restart and load the updated credentials.

---

## Step-by-Step Example

### 1. Create a Secret (Simulating External Sync)

In a real environment, this Secret would usually be created by an external secret controller.

Example Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-secret
type: Opaque
stringData:
  API_TOKEN: initial-token
```

Apply the Secret:

```bash
kubectl apply -f secret.yaml
```

---

### 2. Create a Deployment Using the Secret

Example Deployment consuming the Secret as an environment variable:

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
        - name: API_TOKEN
          valueFrom:
            secretKeyRef:
              name: api-secret
              key: API_TOKEN
```

---

### 3. Enable Automatic Restart

Add the Reloader annotation to the Deployment:

```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
```

This tells Reloader to watch configuration resources used by this workload.

---

### 4. Simulate an External Secret Update

Update the Secret value:

```yaml
stringData:
  API_TOKEN: rotated-token
```

Apply the change:

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
Application loads updated credentials
```

---

## Verifying the Restart

You can observe the rollout using:

```bash
kubectl rollout status deployment demo-app
```

Or watch pods restart:

```bash
kubectl get pods -w
```

A new pod will be created automatically after the Secret changes.

---

## When This Pattern Is Useful

Automatically restarting pods when external secrets change is useful when:

* credentials rotate regularly
* external secret systems synchronize values into Kubernetes
* applications require restart to pick up updated credentials
* multiple workloads depend on the same Secret

---

## Summary

External secret systems keep Kubernetes Secrets synchronized with external sources.

However, updating a Secret does not automatically restart pods that use it.

Using Reloader allows workloads to **automatically restart when externally managed secrets change**, ensuring applications always run with the latest credentials.

---

## FAQ

### Do external secret controllers restart pods when secrets change?

Usually not. Most controllers only update the Kubernetes Secret but do not restart workloads.

### Why don't pods automatically pick up new secrets?

Most applications load secrets at startup and do not watch for changes.

### How can I automate pod restarts when external secrets update?

You can use a controller such as Reloader to detect Secret updates and trigger rolling restarts automatically.
