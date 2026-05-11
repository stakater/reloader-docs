# Reloader OSS Installation

Reloader OSS is free and open source. It is distributed via:

- [Helm chart](#helm-recommended) — recommended for production
- [Kubernetes manifests](#kubernetes-manifests) — single `kubectl apply`
- [Kustomize](#kustomize)

---

## Requirements

- Kubernetes >= 1.19
- Helm v3+ (if using Helm)

---

## Helm (recommended)

### Step 1 — Add the Stakater Helm repository

```bash
helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update
```

### Step 2 — Install Reloader

Install with a generated release name, watching all namespaces:

```bash
helm install reloader stakater/reloader --generate-name
```

Or install into a dedicated namespace:

```bash
helm install reloader stakater/reloader \
  --namespace reloader \
  --create-namespace
```

### Step 3 — Verify the installation

```bash
kubectl get pods -n reloader
kubectl logs -n reloader -l app=reloader
```

You should see a running pod and log output confirming Reloader has started.

---

## Kubernetes manifests

Apply the latest manifest directly from the repository:

```bash
kubectl apply -f https://raw.githubusercontent.com/stakater/Reloader/master/deployments/kubernetes/reloader.yaml
```

This deploys Reloader with default settings into the `default` namespace.

---

## Kustomize

Apply using the built-in Kustomize support in `kubectl`:

```bash
kubectl apply -k https://github.com/stakater/Reloader/deployments/kubernetes
```

To manage namespace or other overrides, create a local `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - https://github.com/stakater/Reloader/deployments/kubernetes

namespace: reloader
```

Then apply:

```bash
kubectl apply -k .
```

---

## Common configurations

### Watch a single namespace only

By default Reloader watches all namespaces. To restrict it to the namespace it is deployed in:

```bash
helm install reloader stakater/reloader \
  --namespace my-app \
  --set reloader.watchGlobally=false
```

### Watch only specific namespaces

```bash
helm install reloader stakater/reloader \
  --set reloader.namespaceSelector="environment=production"
```

### Watch only resources with specific labels

```bash
helm install reloader stakater/reloader \
  --set reloader.resourceLabelSelector="reloader-enabled=true"
```

When both `namespaceSelector` and `resourceLabelSelector` are set, both conditions must be satisfied for a resource to be watched.

### Enable Argo Rollouts support

```bash
helm install reloader stakater/reloader \
  --set reloader.isArgoRollouts=true
```

### Enable OpenShift DeploymentConfig support

Reloader auto-detects whether it is running on OpenShift by probing the cluster API at startup. No manual configuration is required in most cases.

If auto-detection does not work in your environment, you can force it on:

```bash
helm install reloader stakater/reloader \
  --set reloader.isOpenshift=true
```

### Enable CSI Driver integration

Required when using the Secrets Store CSI Driver with file-based secrets (no Kubernetes `Secret` object created).

```bash
helm install reloader stakater/reloader \
  --set reloader.enableCSIIntegration=true
```

### Reload on resource creation

By default Reloader only reacts to changes (updates). To also trigger reloads when a ConfigMap or Secret is created:

```bash
helm install reloader stakater/reloader \
  --set reloader.reloadOnCreate=true
```

### Enable High Availability

HA mode enables leader election so multiple replicas can run safely. Requires `reloadOnCreate: true` for `syncAfterRestart` to work.

```bash
helm install reloader stakater/reloader \
  --set reloader.enableHA=true \
  --set reloader.deployment.replicas=2 \
  --set reloader.reloadOnCreate=true \
  --set reloader.syncAfterRestart=true
```

### Auto-reload all workloads

Treat every workload in the cluster as if it has `reloader.stakater.com/auto: "true"`. Individual workloads can still opt out by setting the annotation to `"false"`.

```bash
helm install reloader stakater/reloader \
  --set reloader.autoReloadAll=true
```

### Ignore Jobs and CronJobs

```bash
helm install reloader stakater/reloader \
  --set reloader.ignoreJobs=true \
  --set reloader.ignoreCronJobs=true
```

### Change the reload strategy

By default Reloader patches a dummy environment variable on the pod template to force a rolling update. To use annotation-based patching instead (preferred when using GitOps tools such as Argo CD):

```bash
helm install reloader stakater/reloader \
  --set reloader.reloadStrategy=annotations
```

| Strategy | Behaviour |
|---|---|
| `default` | Patches a dummy environment variable on the pod template |
| `env-vars` | Same as `default` |
| `annotations` | Adds `reloader.stakater.com/last-reloaded-from` to the pod template — produces less GitOps drift |

---

## Helm values reference

| Value | Description | Default |
|---|---|---|
| `reloader.watchGlobally` | Watch all namespaces (`true`) or only the deployment namespace (`false`) | `true` |
| `reloader.autoReloadAll` | Treat all workloads as if they have `auto: "true"` | `false` |
| `reloader.isArgoRollouts` | Enable Argo Rollouts support | `false` |
| `reloader.isOpenshift` | Enable OpenShift DeploymentConfig support | `false` |
| `reloader.enableCSIIntegration` | Enable Secrets Store CSI Driver integration | `false` |
| `reloader.ignoreSecrets` | Ignore all Secrets | `false` |
| `reloader.ignoreConfigMaps` | Ignore all ConfigMaps | `false` |
| `reloader.ignoreJobs` | Ignore Jobs | `false` |
| `reloader.ignoreCronJobs` | Ignore CronJobs | `false` |
| `reloader.reloadOnCreate` | Trigger reload when a resource is created (not just updated) | `false` |
| `reloader.reloadOnDelete` | Trigger reload when a resource is deleted | `false` |
| `reloader.reloadStrategy` | Reload strategy: `default`, `env-vars`, or `annotations` | `default` |
| `reloader.namespaceSelector` | Label selector to restrict which namespaces are watched | `""` |
| `reloader.ignoreNamespaces` | Comma-separated list of namespaces to exclude | `""` |
| `reloader.resourceLabelSelector` | Label selector to restrict which ConfigMaps/Secrets are watched | `""` |
| `reloader.enableHA` | Enable leader election for multi-replica deployments | `false` |
| `reloader.syncAfterRestart` | On leader election, new leader reloads all tracked workloads | `false` |
| `reloader.logFormat` | Log format: `json` or empty (text) | `""` |
| `reloader.logLevel` | Log level: `trace`, `debug`, `info`, `warning`, `error`, `fatal`, `panic` | `info` |
| `reloader.deployment.replicas` | Number of replicas (keep at 1 unless HA is enabled) | `1` |
| `reloader.enableHA` | Enable HA mode with leader election | `false` |
| `reloader.rbac.enabled` | Create RBAC ClusterRole and ClusterRoleBinding | `true` |
| `reloader.serviceAccount.create` | Create a ServiceAccount for Reloader | `true` |
| `reloader.podMonitor.enabled` | Create a Prometheus PodMonitor for metrics scraping | `false` |
| `reloader.webhookUrl` | Send a webhook notification instead of triggering a restart | `""` |
| `reloader.readOnlyRootFileSystem` | Enforce read-only root filesystem on the container | `false` |

### Resource requests and limits

No resource requests or limits are set by default (`resources: {}`). Set them explicitly for production:

```bash
helm install reloader stakater/reloader \
  --set reloader.deployment.resources.requests.cpu=10m \
  --set reloader.deployment.resources.requests.memory=128Mi \
  --set reloader.deployment.resources.limits.cpu=150m \
  --set reloader.deployment.resources.limits.memory=512Mi
```

Or via values file:

```yaml
reloader:
  deployment:
    resources:
      requests:
        cpu: 10m
        memory: 128Mi
      limits:
        cpu: 150m
        memory: 512Mi
```

---

## OpenShift notes

On OpenShift 4.13.3 and later, users must run within dynamically assigned UID ranges. To allow OpenShift to assign the UID automatically:

```bash
helm install reloader stakater/reloader \
  --set reloader.deployment.securityContext.runAsUser=null
```

---

## Uninstall

```bash
helm uninstall reloader -n reloader
```

To also remove the namespace:

```bash
kubectl delete namespace reloader
```
