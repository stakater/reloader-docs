# Verify and Troubleshoot Reloader

This page explains how to confirm that Reloader is working correctly and how to diagnose common problems.

---

## Verify Reloader is running

Check that the Reloader pod is up:

```bash
kubectl get pods -n reloader -l app=reloader
```

Expected output:

```text
NAME                        READY   STATUS    RESTARTS   AGE
reloader-6d8f9b7c4d-xk9zp   1/1     Running   0          5m
```

---

## Verify a reload was triggered

### Check the logs

After updating a ConfigMap or Secret, check Reloader's logs for confirmation:

```bash
kubectl logs -n reloader -l app=reloader --tail=50
```

A successful reload produces log lines like:

```text
Changes detected in 'database-secret' of type 'SECRET' in namespace: production
Updated 'my-app' of type 'Deployment' in namespace: production
```

| Log field | Meaning |
|---|---|
| `database-secret` | Name of the ConfigMap or Secret that changed |
| `SECRET` | Type of the changed resource (`SECRET` or `CONFIGMAP`) |
| `production` | Namespace where the change was detected |
| `my-app` | Name of the workload that was restarted |
| `Deployment` | Workload type (`Deployment`, `StatefulSet`, `DaemonSet`, etc.) |

If you see no log output after a change, see [Reloader is not reacting to changes](#reloader-is-not-reacting-to-changes) below.

### Check the pod age

After a reload, the workload's pods are replaced. Confirm new pods were created:

```bash
kubectl get pods -n <namespace> -l <your-app-label>
```

The `AGE` column should show the pods were created recently, within seconds or minutes of your ConfigMap or Secret update.

### Check the rollout status

```bash
kubectl rollout status deployment/<deployment-name> -n <namespace>
```

---

## Verify via Prometheus metrics

Reloader exposes a Prometheus metrics endpoint at `/metrics` on port `9090`.

### Reload counters

```text
reloader_reload_executed_total{success="true"}   # number of successful reloads
reloader_reload_executed_total{success="false"}  # number of failed reloads
```

Port-forward to inspect directly:

```bash
kubectl port-forward -n reloader svc/reloader 9090:9090
curl http://localhost:9090/metrics | grep reloader_reload
```

### Reloads broken down by namespace

This is a **separate metric** (`reloader_reload_executed_total_by_namespace`) that is disabled by default because it can have high cardinality in large clusters. Enable it with:

```yaml
reloader:
  enableMetricsByNamespace: true
```

Or via the environment variable `METRICS_COUNT_BY_NAMESPACE=enabled` on the Reloader container.

When enabled:

```text
reloader_reload_executed_total_by_namespace{success="true", namespace="production"}   1
reloader_reload_executed_total_by_namespace{success="false", namespace="staging"}     2
```

---

## Common problems

### Reloader is not reacting to changes

**Check the annotation is present and correct.**

```bash
kubectl get deployment <name> -n <namespace> -o jsonpath='{.metadata.annotations}'
```

The annotation must be on the `Deployment` (or other workload) itself, not on the pod template. Common mistakes:

- Typo in the annotation key (compare against the [Annotation Reference](../reference/annotations.md))
- Annotation placed under `spec.template.metadata.annotations` instead of `metadata.annotations`
- Using `reloader.stakater.com/search: "true"` without `reloader.stakater.com/match: "true"` on the Secret/ConfigMap

**Check the ConfigMap or Secret is not ignored.**

```bash
kubectl get secret <name> -n <namespace> -o jsonpath='{.metadata.annotations}'
```

If `reloader.stakater.com/ignore: "true"` is present, Reloader will skip it entirely.

**Check namespace scope.**

If Reloader is deployed with `watchGlobally: false`, it only watches its own namespace. Confirm with:

```bash
kubectl logs -n reloader -l app=reloader | grep -i namespace
```

**Check label selectors.**

If `namespaceSelector` or `resourceLabelSelector` is configured, the resource or its namespace must match. A resource that matches `resourceLabelSelector` but not `namespaceSelector` is silently ignored.

---

### Reloader is restarting pods it shouldn't

**Check `auto: "true"` scope.**

`reloader.stakater.com/auto: "true"` watches all ConfigMaps and Secrets referenced anywhere in the pod spec. If a shared ConfigMap or Secret changes, every workload referencing it will restart. Use the named annotation instead to limit scope:

```yaml
configmap.reloader.stakater.com/reload: "only-this-configmap"
```

Or use the [search and match pattern](../reference/annotations.md#search-and-match-pattern) to give resource owners explicit control.

**Check `autoReloadAll` mode.**

If `reloader.autoReloadAll: true` is set, all workloads restart on any matching change. To opt a specific workload out:

```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "false"
```

---

### Argo CD shows the app as OutOfSync after a reload

Reloader's default `env-vars` reload strategy injects an environment variable into the pod template. Argo CD compares the live state against Git and flags this as drift.

See the full guide: [Use Reloader with Argo CD](use-reloader-with-argocd.md)

---

### Pod restarts are happening multiple times for one change

A single ConfigMap or Secret update should produce exactly one restart per matching workload. If you are seeing repeated restarts, check:

- Whether the ConfigMap or Secret is being updated multiple times in quick succession (for example by an external sync controller with a short refresh interval)
- Use `deployment.reloader.stakater.com/pause-period` to rate-limit rapid changes:

```yaml
metadata:
  annotations:
    deployment.reloader.stakater.com/pause-period: "2m"
```

---

### Reloader logs show errors

**`failed to update deployment`** — Reloader does not have permission to patch the workload. Verify RBAC:

```bash
kubectl get clusterrole reloader-reloader-role -o yaml
kubectl get clusterrolebinding reloader-reloader-role-binding -o yaml
```

**`unable to create Kubernetes client`** — Reloader cannot reach the Kubernetes API. Check the ServiceAccount and network policies.
