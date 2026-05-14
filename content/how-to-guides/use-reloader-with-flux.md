# Use Reloader with Flux

Reloader and Flux can conflict when Reloader patches a workload and Flux's reconciliation loop reverts the change. This guide explains why this happens and how to configure both tools to work together reliably.

---

## The Problem

Reloader's default reload strategy (`env-vars`) injects an environment variable into the pod template when a ConfigMap or Secret changes:

```yaml
# What Reloader injects into the live Deployment
spec:
  template:
    spec:
      containers:
        - env:
            - name: STAKATER_DATABASE_SECRET
              value: "a3f1c9b2..."  # SHA1 hash of the secret data
```

This change is not in Git. When Flux reconciles on its next cycle, it compares the live cluster state against Git and reverts the env var — undoing Reloader's restart trigger:

```text
Applied revision: main/abc1234
Deployment/my-app configured  ← Flux just reverted Reloader's patch
```

The pod never picks up the rotated secret because the rolling restart is cancelled before it completes.

---

## The Solution

Switch Reloader to the **`annotations`** reload strategy. Flux v2 uses Kubernetes **server-side apply (SSA)**, which tracks field ownership per manager. When Reloader writes the annotation using its own field manager, Flux does not own that field and will not remove it during reconciliation.

No additional Flux configuration is needed for this to work.

---

## Step 1 — Switch Reloader to the annotations strategy

Update your Reloader Helm values:

```yaml
reloader:
  reloadStrategy: annotations
```

If you manage Reloader with Flux, update the `HelmRelease`:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: reloader
  namespace: reloader
spec:
  chart:
    spec:
      chart: reloader
      sourceRef:
        kind: HelmRepository
        name: stakater
  values:
    reloader:
      reloadStrategy: annotations
```

With this strategy, Reloader adds `reloader.stakater.com/last-reloaded-from` to the pod template metadata instead of injecting an env var:

```yaml
spec:
  template:
    metadata:
      annotations:
        reloader.stakater.com/last-reloaded-from: "database-secret"
```

Because this annotation is not in the Git manifest, Flux does not claim ownership of it via SSA. Reloader owns it, and Flux leaves it alone.

---

## Step 2 — Annotate your workload

Add the Reloader annotation to the Deployment in Git as normal:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  annotations:
    reloader.stakater.com/auto: "true"
spec:
  ...
```

Commit and push. Flux syncs it. Reloader watches it.

---

## Step 3 — Verify it works

### Trigger a reload

Update the Secret or ConfigMap that the workload references, then wait for the change to propagate.

### Check Flux is not reverting the annotation

Watch Flux's reconciliation output:

```bash
flux get kustomizations --watch
```

After a Reloader-triggered restart, the Kustomization should remain `Ready` and `Applied` with no further changes on the next reconcile.

### Check Reloader's logs

```bash
kubectl logs -n reloader -l app=reloader --tail=20
```

You should see:

```text
Changes detected in 'database-secret' of type 'SECRET' in namespace: production
Updated 'my-app' of type 'Deployment' in namespace: production
```

### Check pod age

```bash
kubectl get pods -n production -l app=my-app
```

Pods should be recently restarted after a secret rotation, and Flux should not re-apply and revert them.

---

## If you cannot use Flux v2 SSA

If you are on an older Flux setup that uses **client-side apply** instead of SSA, the annotation will still be reverted. In that case, you can tell Flux to ignore specific fields using a Kustomize patch in your `Kustomization`.

Add a strategic merge patch that pre-declares the annotation with a placeholder value. Flux will then manage the field and Reloader can update it between reconciliations:

```yaml
# kustomization.yaml (applied by Flux)
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
patches:
  - patch: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: my-app
      spec:
        template:
          metadata:
            annotations:
              reloader.stakater.com/last-reloaded-from: ""
    target:
      kind: Deployment
      name: my-app
```

This approach has a tradeoff: Flux will reset the annotation to `""` on every reconciliation, and Reloader will re-set it on the next reload. The pods will still restart correctly because the annotation value changing from `""` to the secret name counts as a pod template diff.

For most teams, upgrading to Flux v2 with SSA is the cleaner path.

---

## How SSA field ownership works

For context, Kubernetes server-side apply tracks which manager last wrote each field. When Flux applies a Deployment manifest using SSA:

- Fields declared in the manifest are owned by `flux-kustomize-controller`
- Fields **not** declared in the manifest are not claimed by Flux
- Reloader patches the pod template annotation using a `Patch` API call, claiming ownership of that field

On the next Flux reconciliation, Flux re-applies the manifest. Since Flux does not own `reloader.stakater.com/last-reloaded-from` (it was never in the Git manifest), SSA does not remove it.

This is why the `annotations` strategy works with Flux v2 without any additional configuration — and why the `env-vars` strategy is problematic: environment variable list entries are more likely to conflict with fields Flux does own.

---

## Summary

| Step | What to do |
|------|-----------|
| Reloader | Set `reloadStrategy: annotations` |
| Flux `HelmRelease` | Set `values.reloader.reloadStrategy: annotations` |
| Workload | Annotate with `reloader.stakater.com/auto: "true"` as normal |
| Flux v1 / no SSA | Add a Kustomize patch to pre-declare the annotation field |
