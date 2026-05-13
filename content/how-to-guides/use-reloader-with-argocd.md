# Use Reloader with Argo CD

Reloader and Argo CD work well together, but the default Reloader configuration causes Argo CD to mark applications as **OutOfSync** every time a reload happens. This guide explains why, and how to fix it.

---

## The Problem

Reloader's default reload strategy (`env-vars`) works by injecting an environment variable into the pod template when a ConfigMap or Secret changes:

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

This change exists only in the **live cluster state** — it is not in Git. Argo CD compares live state against Git and flags the difference:

```text
Status: OutOfSync
  spec.template.spec.containers[0].env: array has extra element
```

If Argo CD is configured with **auto-sync**, it will revert the change — undoing Reloader's restart trigger and preventing the pod from reloading the new secret value.

---

## The Solution

Two changes are needed:

1. **Switch Reloader to the `annotations` reload strategy** — instead of injecting an env var, Reloader adds a single annotation to the pod template metadata
2. **Configure Argo CD to ignore that annotation** — so it never flags it as drift

---

## Step 1 — Switch Reloader to the annotations strategy

Update your Reloader Helm values:

```yaml
reloader:
  reloadStrategy: annotations
```

Apply with:

```bash
helm upgrade reloader stakater/reloader \
  --namespace reloader \
  --set reloader.reloadStrategy=annotations
```

With this strategy, Reloader adds `reloader.stakater.com/last-reloaded-from` to the pod template metadata instead of injecting an env var:

```yaml
spec:
  template:
    metadata:
      annotations:
        reloader.stakater.com/last-reloaded-from: "database-secret"
```

This is still enough to trigger a rolling restart — Kubernetes detects the pod template diff and rolls the pods.

---

## Step 2 — Configure Argo CD to ignore the Reloader annotation

### Option A: Per-Application (recommended)

Add `ignoreDifferences` to each Argo CD `Application` that uses Reloader:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/my-org/my-app
    targetRevision: main
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/template/metadata/annotations/reloader.stakater.com~1last-reloaded-from
    - group: apps
      kind: StatefulSet
      jsonPointers:
        - /spec/template/metadata/annotations/reloader.stakater.com~1last-reloaded-from
    - group: apps
      kind: DaemonSet
      jsonPointers:
        - /spec/template/metadata/annotations/reloader.stakater.com~1last-reloaded-from
```

The `~1` in the JSON Pointer is the escaped form of `/`, representing the annotation key `reloader.stakater.com/last-reloaded-from`.

### Option B: Cluster-wide (argocd-cm)

To apply the ignore rule to all applications globally, add a resource customization to the `argocd-cm` ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  resource.customizations.ignoreDifferences.apps_Deployment: |
    jsonPointers:
    - /spec/template/metadata/annotations/reloader.stakater.com~1last-reloaded-from
  resource.customizations.ignoreDifferences.apps_StatefulSet: |
    jsonPointers:
    - /spec/template/metadata/annotations/reloader.stakater.com~1last-reloaded-from
  resource.customizations.ignoreDifferences.apps_DaemonSet: |
    jsonPointers:
    - /spec/template/metadata/annotations/reloader.stakater.com~1last-reloaded-from
```

Apply:

```bash
kubectl apply -f argocd-cm.yaml -n argocd
```

---

## Step 3 — Annotate your workload

Nothing changes here from normal Reloader usage. Add the annotation to the Deployment (or other workload) in Git:

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

Commit and push. Argo CD syncs the manifest. Reloader watches the workload.

---

## Verify it works

### Trigger a reload

Update the Secret or ConfigMap that the workload references, then wait for the change to propagate.

### Check Argo CD is not marking the app OutOfSync

```bash
argocd app get my-app
```

The status should remain `Synced` even after Reloader has patched the pod template.

### Check Reloader's logs

```bash
kubectl logs -n reloader -l app=reloader --tail=20
```

You should see lines like:

```text
Changes detected in 'database-secret' of type 'SECRET' in namespace: production
Updated 'my-app' of type 'Deployment' in namespace: production
```

### Check pod age

```bash
kubectl get pods -n production -l app=my-app
```

After a secret rotation, pods should be recently restarted (low `AGE`), and Argo CD should still show `Synced`.

---

## Using Argo Rollouts

If your workloads are Argo `Rollout` resources, enable Argo Rollouts support in Reloader:

```yaml
reloader:
  isArgoRollouts: true
  reloadStrategy: annotations
```

By default, Reloader triggers a new rollout by patching the pod template (`rollout` strategy). If you want to avoid patching the template entirely (useful when even an annotation causes drift in your Argo CD setup), use the `restart` rollout strategy instead:

```yaml
# On the Rollout resource
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
    reloader.stakater.com/rollout-strategy: "restart"
```

The `restart` strategy deletes pods directly without touching the pod template, so Argo CD sees no template drift at all.

Also add `Rollout` to the `ignoreDifferences` list in your Application:

```yaml
ignoreDifferences:
  - group: argoproj.io
    kind: Rollout
    jsonPointers:
      - /spec/template/metadata/annotations/reloader.stakater.com~1last-reloaded-from
```

---

## Summary

| Step | What to do |
|------|-----------|
| Reloader | Set `reloadStrategy: annotations` |
| Argo CD Application | Add `ignoreDifferences` for the Reloader annotation |
| Workload | Annotate with `reloader.stakater.com/auto: "true"` as normal |
| Argo Rollouts | Set `reloader.stakater.com/rollout-strategy: "restart"` to avoid all template drift |
