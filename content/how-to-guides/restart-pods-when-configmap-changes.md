# Restart Pods When ConfigMap Changes in Kubernetes

Applications in Kubernetes often load configuration from **ConfigMaps**.  
However, when a ConfigMap is updated, running pods **do not automatically reload the new configuration**.

This guide explains why this happens and how to ensure pods restart automatically when configuration changes.

---

## The Problem

Updating a ConfigMap does not trigger a rollout of workloads that use it.

Example:

```bash
kubectl apply -f configmap.yaml
```

Result:

```bash
ConfigMap updated
↓
Pods continue running
↓
Application still uses old configuration
```

This happens because Kubernetes only performs a rollout when the **PodSpec changes**, not when referenced resources such as ConfigMaps change.

---

## Common Approaches

There are several ways to handle configuration updates in Kubernetes.

### 1. Manual Rollout Restart

A simple solution is to manually restart the workload.

```bash
kubectl rollout restart deployment my-app
```

This forces Kubernetes to create new pods that read the updated ConfigMap.

#### Limitations

* Requires manual intervention
* Easy to forget in busy environments
* Difficult to scale when many workloads depend on the same ConfigMap

---

### 2. Checksum Annotations (Helm)

Some Helm charts implement checksum annotations that trigger a rollout when configuration changes.

Example:

```yaml
metadata:
  annotations:
    checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

When the ConfigMap content changes, the checksum changes as well, causing the Deployment to restart.

#### Limitations

* Requires modifying Helm charts
* Only works when Helm performs an upgrade
* Does not react to runtime updates outside Helm

---

## Automatic Restart with Reloader

A more automated solution is to use **Reloader**, a Kubernetes controller that watches for changes in ConfigMaps and Secrets.

When a watched resource changes, Reloader triggers a rolling restart of workloads that reference it.

Workflow:

```bash
ConfigMap updated
↓
Reloader detects change
↓
Deployment patched
↓
Kubernetes rolling restart triggered
```

This ensures applications automatically reload updated configuration.

---

## Step-by-Step Example

### 1. Create a ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_MESSAGE: "Hello world"
```

Apply it:

```bash
kubectl apply -f configmap.yaml
```

---

### 2. Create a Deployment Using the ConfigMap

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
        - name: APP_MESSAGE
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: APP_MESSAGE
```

---

### 3. Enable Reloader for the Deployment

Add the following annotation to the Deployment:

```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
```

This tells Reloader to watch configuration resources referenced by this workload.

---

### 4. Update the ConfigMap

Modify the value:

```yaml
APP_MESSAGE: "Hello Kubernetes"
```

Apply the change:

```bash
kubectl apply -f configmap.yaml
```

Result:

```bash
ConfigMap updated
↓
Reloader detects change
↓
Deployment patched
↓
New pod created
↓
Application loads updated configuration
```

---

## Verifying the Restart

You can observe the rollout with:

```bash
kubectl rollout status deployment demo-app
```

Or watch the pods:

```bash
kubectl get pods -w
```

A new pod will be created automatically after the ConfigMap changes.

---

## When This Pattern Is Useful

Automatically restarting pods when ConfigMaps change is useful when:

* applications load configuration at startup
* configuration updates occur frequently
* multiple workloads share the same ConfigMap
* teams want reliable automation

---

## Summary

Updating a ConfigMap does not automatically restart pods in Kubernetes.

Manual restarts and checksum annotations can help, but they often require extra operational steps.

Using Reloader allows Kubernetes workloads to **automatically restart when configuration changes**, ensuring applications always run with the latest configuration.

---

## FAQ

### Do ConfigMap changes automatically restart pods?

No. Kubernetes does not restart pods when ConfigMaps change.

### Why does Kubernetes behave this way?

Kubernetes only triggers rollouts when the Pod specification changes, not when referenced configuration resources change.

### How can I automate restarts when configuration changes?

You can use a controller such as Reloader to detect ConfigMap updates and trigger rolling restarts automatically.
