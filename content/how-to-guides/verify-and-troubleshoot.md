# Verify and Troubleshoot Reloader

This page explains how to confirm that Reloader is working correctly and how to diagnose common problems.

---

## Verify Reloader is running

```bash
kubectl get pods -n reloader -l app=reloader-reloader
```

Expected output:

```text
NAME                                 READY   STATUS    RESTARTS   AGE
reloader-reloader-6d8f9b7c4d-xk9zp   1/1     Running   0          5m
```

Check for startup errors:

```bash
kubectl logs -n reloader -l app=reloader-reloader --tail=30
```

Reloader logs its configuration at startup. Look for lines confirming which namespaces it is watching and which features are enabled.

---

## End-to-end test

The fastest way to confirm the full chain is working is to trigger a known change and watch the result.

### Step 1 — Create a test Secret and Deployment

```bash
kubectl create secret generic reloader-test \
  --from-literal=value=v1 \
  --namespace default

kubectl create deployment reloader-test \
  --image=busybox:latest \
  --namespace default \
  -- sh -c 'while true; do sleep 30; done'

kubectl annotate deployment reloader-test \
  secret.reloader.stakater.com/reload=reloader-test \
  --namespace default
```

### Step 2 — Trigger a change

```bash
kubectl patch secret reloader-test \
  --namespace default \
  --type='json' \
  -p='[{"op":"replace","path":"/data/value","value":"djI="}]'
```

(`djI=` is `v2` base64-encoded.)

### Step 3 — Confirm the restart happened

```bash
# Check Reloader logs for the event
kubectl logs -n reloader -l app=reloader-reloader --tail=10

# Check the pod was replaced (AGE should be recent)
kubectl get pods -n default -l app=reloader-test
```

Expected log output:

```text
Changes detected in 'reloader-test' of type 'Secret' in namespace 'default'
Updated 'reloader-test' of type 'Deployment' in namespace 'default'
```

### Step 4 — Clean up

```bash
kubectl delete deployment reloader-test -n default
kubectl delete secret reloader-test -n default
```

---

## Verify a reload was triggered

### Check the logs

```bash
kubectl logs -n reloader -l app=reloader-reloader --tail=50
```

A successful reload produces:

```text
Changes detected in 'database-secret' of type 'Secret' in namespace 'production'
Updated 'my-app' of type 'Deployment' in namespace 'production'
```

If you see no log output after a change, see [Reloader is not reacting to changes](#reloader-is-not-reacting-to-changes) below.

### Check Kubernetes Events

Reloader emits a Kubernetes Event on the workload when it triggers a restart. These appear in `kubectl describe` output:

```bash
kubectl describe deployment <name> -n <namespace>
```

Look for events from the `reloader` source:

```text
Events:
  Type    Reason   Age   From      Message
  ----    ------   ----  ----      -------
  Normal  Reloader  5s   reloader  Updated 'my-app' of type 'Deployment' because of changes in Secret 'database-secret'
```

### Check the pod age

After a reload, pods are replaced. The `AGE` column should reflect a recent restart:

```bash
kubectl get pods -n <namespace> -l <your-app-label>
```

### Check rollout status

```bash
kubectl rollout status deployment/<name> -n <namespace>
```

### Check Prometheus metrics

```bash
kubectl port-forward -n reloader svc/reloader 9090:9090
curl -s http://localhost:9090/metrics | grep reloader_reload
```

```text
reloader_reload_executed_total{success="true"}    4
reloader_reload_executed_total{success="false"}   0
```

---

## Common problems

### Reloader is not reacting to changes

**1. Check the annotation is on the right resource and correct.**

The annotation must be on the workload's `metadata.annotations`, not on the pod template (`spec.template.metadata.annotations`).

```bash
kubectl get deployment <name> -n <namespace> -o jsonpath='{.metadata.annotations}'
```

Compare the annotation key exactly against the [Annotation Reference](../reference/annotations.md). A single character typo silently disables the watch.

**2. Check that the data actually changed.**

Reloader compares the `data` field of the Secret or ConfigMap. If only labels or annotations on the Secret changed — with no change to the data content — Reloader will not fire. Confirm the data changed:

```bash
kubectl get secret <name> -n <namespace> -o jsonpath='{.data}' | sha1sum
# update the secret, then run again and compare
kubectl get secret <name> -n <namespace> -o jsonpath='{.data}' | sha1sum
```

**3. Check the search/match pattern is complete.**

If using `reloader.stakater.com/search: "true"` on the Deployment, the Secret or ConfigMap must also have `reloader.stakater.com/match: "true"`. Both sides of the pair are required.

```bash
kubectl get secret <name> -n <namespace> -o jsonpath='{.metadata.annotations}'
```

**4. Check namespace scope.**

If Reloader is deployed with `watchGlobally: false`, it only watches its own namespace. If `namespaceSelector` is set, the target namespace must match the selector.

```bash
kubectl logs -n reloader -l app=reloader-reloader | grep -i "namespace\|watch"
```

**5. Check label selectors.**

If `resourceLabelSelector` is configured, the Secret or ConfigMap must carry matching labels. Resources that do not match are silently ignored.

```bash
kubectl get secret <name> -n <namespace> --show-labels
```

**6. Check the resource is not excluded.**

If `reloader.stakater.com/ignore: "true"` is on the Secret or ConfigMap, Reloader skips it entirely:

```bash
kubectl get secret <name> -n <namespace> -o jsonpath='{.metadata.annotations}'
```

---

### Pod is running but still using the old configuration

This is expected behaviour for environment variables.

**Kubernetes does not update environment variables in running pods.** Environment variables are read at pod start time. A change to a Secret or ConfigMap does not change the values inside a running container — the pod must be restarted to pick up the new values. This is exactly what Reloader does.

If your pods are being restarted by Reloader but still show old values, check:

- Whether the pod actually restarted (compare the `AGE` of the pod to when the Secret was updated)
- Whether the application is caching config values internally and needs a longer startup delay to re-read them
- Whether the Secret key your application reads matches the key that changed

File-mounted secrets behave differently: Kubernetes updates mounted ConfigMap and Secret volumes in-place within roughly two kubelet sync periods (~60 seconds by default), without a pod restart. If your application watches the mounted file, it may pick up the new value automatically. Reloader's rolling restart still ensures a clean pod start.

---

### Reloader is restarting pods it should not

**Check `auto: "true"` scope.**

`reloader.stakater.com/auto: "true"` watches every ConfigMap and Secret referenced anywhere in the pod spec — including those injected by sidecar containers or service mesh components. If a shared resource changes, all workloads referencing it restart.

Switch to the named annotation to limit scope:

```yaml
secret.reloader.stakater.com/reload: "only-this-secret"
```

Or use the [search and match pattern](../reference/annotations.md) so that resource owners explicitly opt their Secret into triggering restarts.

**Check `autoReloadAll` mode.**

If `reloader.autoReloadAll: true` is set globally, every workload in the watched scope restarts on any matching change. To exempt a specific workload:

```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "false"
```

---

### Argo CD shows the app as OutOfSync after a reload

Reloader's default `env-vars` strategy injects an environment variable into the pod template. Argo CD compares the live state against Git and flags this as drift.

Switch to the `annotations` reload strategy:

```yaml
reloader:
  reloadStrategy: annotations
```

See [Use Reloader with Argo CD](use-reloader-with-argocd.md) for the full configuration.

---

### Pod restarts are happening multiple times for one change

A single Secret or ConfigMap update should produce exactly one restart per matching workload. If restarts are happening repeatedly:

- Check whether the Secret is being updated multiple times in quick succession (for example by an external sync controller running on a short refresh interval)
- Use `pause-period` to add a cooldown:

```yaml
metadata:
  annotations:
    deployment.reloader.stakater.com/pause-period: "2m"
```

If you are running multiple Reloader replicas **without** HA mode (`enableHA: false`), each replica independently processes the same event and each triggers a restart. Run either a single replica, or enable HA mode:

```yaml
reloader:
  enableHA: true
  deployment:
    replicas: 2
```

---

### RBAC errors — Reloader cannot patch workloads

**Symptom:** Reloader logs show `failed to update deployment` or similar.

Verify the ClusterRole was created:

```bash
kubectl describe clusterrole reloader-reloader-role
```

Check that Reloader's ServiceAccount has patch permission on deployments:

```bash
kubectl auth can-i patch deployments \
  --as=system:serviceaccount:reloader:reloader-reloader \
  --all-namespaces
```

Check for StatefulSets and Daemonsets:

```bash
kubectl auth can-i patch statefulsets \
  --as=system:serviceaccount:reloader:reloader-reloader \
  --all-namespaces

kubectl auth can-i patch daemonsets \
  --as=system:serviceaccount:reloader:reloader-reloader \
  --all-namespaces
```

If any of these return `no`, the ClusterRole is missing rules. See the [RBAC reference](../reference/rbac.md) for the full rule set and instructions for recreating it.

---

### CSI Driver secrets not triggering a restart

If you are using the Secrets Store CSI Driver with `secretObjects` and Reloader is not firing on rotation:

**1. Confirm the Kubernetes Secret is actually being updated.**

The CSI Driver only syncs the Secret after a pod mounts the volume. If no pod is currently mounting the CSI volume, the Secret is not updated.

```bash
# Confirm the secret exists and check when it was last modified
kubectl get secret <name> -n <namespace> -o jsonpath='{.metadata.resourceVersion}'
# Rotate the upstream secret, wait for the poll interval, then compare resourceVersion
```

**2. Confirm the pod is running with the CSI volume mount.**

```bash
kubectl get secretproviderclasspodstatuses -n <namespace>
```

If no `SecretProviderClassPodStatus` entries exist, no pod is actively mounting the volume.

**3. For file-based CSI (no `secretObjects`) — confirm CSI integration is enabled.**

If you are using the file-based pattern with `secretproviderclass.reloader.stakater.com/reload`, Reloader must be installed with:

```yaml
reloader:
  enableCSIIntegration: true
```

Without this flag, Reloader does not watch `SecretProviderClassPodStatus` resources.

---

### Reloader is not reacting after being restarted or upgraded

By default, Reloader only reacts to changes that happen while it is running. It does not replay events that occurred while it was unavailable.

To trigger a re-sync of all tracked workloads after Reloader starts:

```yaml
reloader:
  reloadOnCreate: true
  syncAfterRestart: true
```

`syncAfterRestart: true` requires `reloadOnCreate: true` to function. With both set, the newly elected leader re-evaluates all watched resources on startup.

---

## Quick diagnostics checklist

| Check | Command |
|---|---|
| Reloader pod is running | `kubectl get pods -n reloader -l app=reloader-reloader` |
| Reloader logs show the change | `kubectl logs -n reloader -l app=reloader-reloader --tail=50` |
| Kubernetes Event was emitted | `kubectl describe deployment <name> -n <namespace>` |
| Annotation is on the workload (not pod template) | `kubectl get deployment <name> -n <namespace> -o jsonpath='{.metadata.annotations}'` |
| Secret data actually changed | Compare `sha1sum` of `.data` before and after |
| RBAC allows patching | `kubectl auth can-i patch deployments --as=system:serviceaccount:reloader:reloader-reloader --all-namespaces` |
| Namespace is in scope | `kubectl logs -n reloader -l app=reloader-reloader \| grep -i namespace` |
| Prometheus reload counter increased | `curl http://localhost:9090/metrics \| grep reloader_reload_executed_total` |
