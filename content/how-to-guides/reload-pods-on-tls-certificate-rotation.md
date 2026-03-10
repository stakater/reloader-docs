# Automatically Reload Pods When TLS Certificates Rotate

Many Kubernetes platforms use automated certificate management to keep TLS certificates valid and up to date. When a certificate rotates, the updated certificate is written to a **Kubernetes Secret**.

However, most applications **do not automatically reload TLS certificates** when the Secret changes. As a result, pods may continue using the **old certificate in memory** until they are restarted.

This guide explains how to ensure pods automatically restart when TLS certificates rotate.

---

## The Problem

TLS certificates used by applications are usually stored in Secrets.

Example workflow:

```bash
Certificate expires soon
↓
Certificate manager renews certificate
↓
TLS Secret updated
↓
Application pods still running
↓
Application continues using old certificate
```

Unless the application supports dynamic certificate reload, the new certificate will not be used until the pod restarts.

---

## Why This Matters

TLS certificate rotation happens regularly in modern Kubernetes environments.

Examples include:

* automated certificate renewal
* short-lived certificates
* internal service TLS
* ingress TLS certificates

If applications continue using the old certificate after renewal, you may see:

* TLS handshake errors
* expired certificate warnings
* failed service communication

---

## Common Approaches

### 1. Manual Restart

A simple approach is restarting workloads manually after certificate renewal.

Example:

```bash
kubectl rollout restart deployment my-app
```

Result:

```text
TLS Secret updated
↓
Operator restarts deployment
↓
New pods start
↓
Application loads new certificate
```

#### Limitations

* Requires manual intervention
* Easy to forget
* Difficult to manage when many services use TLS

---

### 2. Application-Level Certificate Reload

Some applications support dynamic certificate reload by:

* watching certificate files
* handling SIGHUP signals
* exposing reload endpoints

Example flow:

```text
TLS Secret updated
↓
Certificate file updated
↓
Application reloads certificate
```

#### Limitations

* Not all applications support this
* Requires application-specific configuration
* Hard to standardize across workloads

---

## Automatic Restart with Reloader

A more reliable approach is to use **Reloader**, which watches for changes in Kubernetes Secrets.

When a TLS Secret changes, Reloader automatically triggers a rolling restart of workloads that reference it.

Workflow:

```text
Certificate renewed
↓
TLS Secret updated
↓
Reloader detects change
↓
Deployment patched
↓
Pods restart
↓
Application loads new certificate
```

This ensures that applications always run with the latest TLS certificates.

---

## Step-by-Step Example

### 1. Create a TLS Secret

Example TLS Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-tls
type: kubernetes.io/tls
data:
  tls.crt: <base64-cert>
  tls.key: <base64-key>
```

Apply the Secret:

```bash
kubectl apply -f tls-secret.yaml
```

---

### 2. Create a Deployment Using the TLS Secret

Example Deployment mounting the TLS certificate:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-tls-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tls-demo
  template:
    metadata:
      labels:
        app: tls-demo
    spec:
      containers:
      - name: app
        image: nginx
        volumeMounts:
        - name: tls-cert
          mountPath: /etc/tls
          readOnly: true
      volumes:
      - name: tls-cert
        secret:
          secretName: app-tls
```

---

### 3. Enable Automatic Restart

Add the following annotation to the Deployment:

```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
```

This tells Reloader to watch Secrets used by the workload.

---

### 4. Rotate the Certificate

Update the TLS Secret:

```bash
kubectl apply -f tls-secret.yaml
```

Result:

```text
TLS Secret updated
↓
Reloader detects change
↓
Deployment patched
↓
New pods created
↓
Application loads new certificate
```

---

## Verifying the Restart

You can monitor the rollout using:

```bash
kubectl rollout status deployment demo-tls-app
```

Or watch pod changes:

```bash
kubectl get pods -w
```

A new pod will be created automatically after the certificate Secret changes.

---

## When This Pattern Is Useful

Automatically restarting pods on certificate rotation is useful when:

* TLS certificates rotate automatically
* applications cannot reload certificates dynamically
* multiple workloads share the same certificate Secret
* teams want reliable automation for certificate updates

---

## Summary

When TLS certificates rotate in Kubernetes, the corresponding Secret is updated but application pods usually **do not restart automatically**.

Manual restarts or application-level reload mechanisms may work, but they require additional operational effort.

Using Reloader ensures that workloads **automatically restart when TLS Secrets change**, allowing applications to pick up renewed certificates without manual intervention.

---

## FAQ

### Do pods automatically reload TLS certificates in Kubernetes?

No. Updating a TLS Secret does not automatically restart pods or reload certificates.

### Why do applications continue using old certificates?

Most applications load certificates at startup and do not watch for changes to certificate files.

### How can I ensure applications use renewed certificates?

You can use a controller such as Reloader to detect Secret changes and trigger rolling restarts automatically.
