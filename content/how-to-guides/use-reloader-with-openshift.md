# How to Use Reloader on OpenShift

Reloader runs on OpenShift without additional configuration in most cases. It auto-detects the cluster type at startup and enables `DeploymentConfig` support when running on OpenShift. All standard Kubernetes workload types (Deployment, StatefulSet, Daemonset, Argo Rollouts) are supported alongside `DeploymentConfig`.

This guide covers:

- What Reloader supports on OpenShift
- Installing Reloader OSS on OpenShift
- Installing Reloader Enterprise with the UBI image
- Security context configuration for OpenShift
- Annotating DeploymentConfigs

---

## What Reloader supports on OpenShift

| Workload | Support |
|---|---|
| `Deployment` | ✅ Full support |
| `StatefulSet` | ✅ Full support |
| `Daemonset` | ✅ Full support |
| `DeploymentConfig` | ✅ OpenShift only; auto-detected at startup |
| `Argo Rollout` | ✅ Requires `reloader.isArgoRollouts: true` |
| `CronJob` | ✅ Supported |

Reloader watches `ConfigMaps` and `Secrets` and triggers rolling restarts of matching workloads, regardless of whether they are standard Kubernetes resources or OpenShift-specific ones.

---

## Install Reloader OSS on OpenShift

The standard Helm install works on OpenShift. One security context change is required for OpenShift 4.13.3 and later.

### Step 1 — Add the Stakater Helm repo

```bash
helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update
```

### Step 2 — Install with OpenShift-compatible security context

On OpenShift 4.13.3 and later, pods must run within dynamically assigned UID ranges. The default Reloader chart sets `runAsUser: 65534`, which conflicts with OpenShift's dynamic UID assignment. Set it to `null` to let OpenShift assign the UID:

```bash
helm install reloader stakater/reloader \
  --namespace reloader \
  --create-namespace \
  --set reloader.deployment.securityContext.runAsUser=null
```

Or in a values file:

```yaml
reloader:
  deployment:
    securityContext:
      runAsUser: null
      runAsNonRoot: true
      seccompProfile:
        type: RuntimeDefault
```

```bash
helm install reloader stakater/reloader \
  --namespace reloader \
  --create-namespace \
  --values values.yaml
```

### DeploymentConfig auto-detection

Reloader probes the cluster API at startup to detect OpenShift. If the `apps.openshift.io/v1` API is present, it automatically enables `DeploymentConfig` support and adds the required RBAC rule:

```yaml
- apiGroups: ["apps.openshift.io"]
  resources: ["deploymentconfigs"]
  verbs: ["list", "get", "update", "patch"]
```

If auto-detection does not work in your environment (for example, if API discovery is restricted), force it on explicitly:

```bash
helm install reloader stakater/reloader \
  --namespace reloader \
  --create-namespace \
  --set reloader.deployment.securityContext.runAsUser=null \
  --set reloader.isOpenshift=true
```

---

## Install Reloader Enterprise on OpenShift

Reloader Enterprise is recommended for OpenShift environments that require Red Hat certified workloads, regulated industries, or commercial SLA coverage. The Enterprise UBI (Red Hat Universal Base Image) variant satisfies Red Hat certification requirements.

### Step 1 — Create the image pull secret

Reloader Enterprise images are hosted on GitHub Container Registry. Authenticate using your GitHub credentials or the token provided by Stakater:

```bash
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=<github-username-or-reloader-enterprise> \
  --docker-password=<github-token-or-stakater-token> \
  --namespace reloader
```

### Step 2 — Install with the UBI image

```bash
helm install reloader stakater/reloader \
  --namespace reloader \
  --create-namespace \
  --set image.repository=ghcr.io/stakater/reloader-enterprise \
  --set image.tag=<version>-ubi \
  --set "global.imagePullSecrets[0].name=regcred" \
  --set reloader.deployment.securityContext.runAsUser=null
```

Or in a values file:

```yaml
image:
  repository: ghcr.io/stakater/reloader-enterprise
  tag: <version>-ubi

global:
  imagePullSecrets:
    - name: regcred

reloader:
  deployment:
    securityContext:
      runAsUser: null
      runAsNonRoot: true
      seccompProfile:
        type: RuntimeDefault
```

The `-ubi` suffix selects the UBI variant. The standard variant (`ghcr.io/stakater/reloader-enterprise:<version>`) is also available if UBI is not required.

See the [Enterprise installation guide](../installation/install.md) for the full access and subscription setup.

---

## Annotating DeploymentConfigs

Reloader uses the same annotation patterns on `DeploymentConfig` as on standard Kubernetes workloads.

**Auto — watch all referenced ConfigMaps and Secrets:**

```yaml
apiVersion: apps.openshift.io/v1
kind: DeploymentConfig
metadata:
  name: myapp
  namespace: default
  annotations:
    reloader.stakater.com/auto: "true"
spec:
  replicas: 2
  selector:
    app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: app
          image: myapp:latest
          envFrom:
            - secretRef:
                name: app-secrets
```

**Named — watch a specific Secret or ConfigMap by name:**

```yaml
metadata:
  annotations:
    secret.reloader.stakater.com/reload: "app-secrets"
    configmap.reloader.stakater.com/reload: "app-config"
```

**Search and match — resource-owner controlled:**

```yaml
# On the DeploymentConfig
metadata:
  annotations:
    reloader.stakater.com/search: "true"

# On the Secret
metadata:
  annotations:
    reloader.stakater.com/match: "true"
```

All three patterns work identically across `Deployment`, `StatefulSet`, `Daemonset`, and `DeploymentConfig`.

---

## Security context reference

The default pod security context Reloader sets:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65534
  seccompProfile:
    type: RuntimeDefault
```

For OpenShift 4.13.3 and later, override `runAsUser` to `null`:

```yaml
reloader:
  deployment:
    securityContext:
      runAsUser: null
      runAsNonRoot: true
      seccompProfile:
        type: RuntimeDefault
```

This allows OpenShift to assign a UID from the namespace's allowed UID range, which is required by the `restricted` and `restricted-v2` Security Context Constraints (SCCs). No custom SCC is needed.

To additionally harden the container:

```yaml
reloader:
  deployment:
    containerSecurityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
          - ALL
      readOnlyRootFilesystem: true
```

When `readOnlyRootFilesystem: true` is set, the chart automatically mounts an `emptyDir` at `/tmp/` so Reloader can write temporary files.

---

## Verify the installation

```bash
# Check Reloader is running
kubectl get pods -n reloader

# Confirm DeploymentConfig RBAC was added
kubectl describe clusterrole reloader-reloader-role | grep deploymentconfig

# Test a reload by patching a Secret
kubectl patch secret app-secrets -n default \
  --type='json' \
  -p='[{"op":"replace","path":"/data/example","value":"bmV3dmFsdWU="}]'

# Watch for the rollout
kubectl rollout status dc/myapp -n default
```

Check Reloader logs to confirm the event was processed:

```bash
kubectl logs -n reloader -l app=reloader-reloader --tail=20
```

Expected output:

```text
Changes detected in 'app-secrets' of type 'Secret' in namespace 'default'
Updated 'myapp' of type 'DeploymentConfig' in namespace 'default'
```

---

## OSS vs Enterprise on OpenShift

| | Reloader OSS | Reloader Enterprise |
|---|---|---|
| DeploymentConfig support | ✅ | ✅ |
| Standard workload types | ✅ | ✅ |
| UBI image variant | ❌ | ✅ |
| Red Hat certified image | ❌ | ✅ |
| Hardened, CVE-scanned image | ❌ | ✅ |
| Commercial support and SLA | ❌ | ✅ |
| Suitable for regulated environments | ❌ | ✅ |

To get Reloader Enterprise, open a ticket at the [Stakater support portal](https://support.stakater.com/) or contact your Stakater account team.
