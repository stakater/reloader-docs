# Annotation Reference

Reloader is controlled entirely through Kubernetes annotations. No application changes are required.

This page is the complete reference for every annotation Reloader supports, what values they accept, which resource types they apply to, and how they interact with each other.

---

## Workload annotations

These annotations are placed on workload resources: `Deployment`, `StatefulSet`, `Daemonset`, `Argo Rollout`, `CronJob`, or `Job`.

### `reloader.stakater.com/auto`

Watches all `ConfigMaps` and `Secrets` that the workload references. When any of them changes, Reloader triggers a rolling restart.

| Field | Value |
|---|---|
| **Applies to** | Deployment, StatefulSet, Daemonset, Rollout, CronJob, Job |
| **Accepted values** | `"true"`, `"false"` |
| **Default** | Not set (no-op) |

```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
```

Setting `"false"` explicitly disables reloading for that workload even when `--auto-reload-all` is enabled globally.

---

### `secret.reloader.stakater.com/auto`

Like `reloader.stakater.com/auto` but restricted to `Secrets` only. ConfigMap changes are ignored.

| Field | Value |
|---|---|
| **Applies to** | Deployment, StatefulSet, Daemonset, Rollout, CronJob, Job |
| **Accepted values** | `"true"` |

```yaml
metadata:
  annotations:
    secret.reloader.stakater.com/auto: "true"
```

---

### `configmap.reloader.stakater.com/auto`

Like `reloader.stakater.com/auto` but restricted to `ConfigMaps` only. Secret changes are ignored.

| Field | Value |
|---|---|
| **Applies to** | Deployment, StatefulSet, Daemonset, Rollout, CronJob, Job |
| **Accepted values** | `"true"` |

```yaml
metadata:
  annotations:
    configmap.reloader.stakater.com/auto: "true"
```

---

### `secretproviderclass.reloader.stakater.com/auto`

Triggers a reload when a `SecretProviderClass` resource changes. Used with the Secrets Store CSI Driver when secrets are mounted as files and no Kubernetes `Secret` object is created.

| Field | Value |
|---|---|
| **Applies to** | Deployment, StatefulSet, Daemonset, Rollout, CronJob, Job |
| **Accepted values** | `"true"` |

```yaml
metadata:
  annotations:
    secretproviderclass.reloader.stakater.com/auto: "true"
```

---

### `secret.reloader.stakater.com/reload`

Watches one or more named `Secrets` explicitly. The Secret does not need to be referenced in the pod spec — Reloader will watch it regardless.

| Field | Value |
|---|---|
| **Applies to** | Deployment, StatefulSet, Daemonset, Rollout, CronJob, Job |
| **Accepted values** | Comma-separated Secret names |

```yaml
metadata:
  annotations:
    secret.reloader.stakater.com/reload: "database-secret,api-keys"
```

---

### `configmap.reloader.stakater.com/reload`

Watches one or more named `ConfigMaps` explicitly. The ConfigMap does not need to be referenced in the pod spec.

| Field | Value |
|---|---|
| **Applies to** | Deployment, StatefulSet, Daemonset, Rollout, CronJob, Job |
| **Accepted values** | Comma-separated ConfigMap names |

```yaml
metadata:
  annotations:
    configmap.reloader.stakater.com/reload: "app-config,feature-flags"
```

---

### `secretproviderclass.reloader.stakater.com/reload`

Watches one or more named `SecretProviderClass` resources explicitly.

| Field | Value |
|---|---|
| **Applies to** | Deployment, StatefulSet, Daemonset, Rollout, CronJob, Job |
| **Accepted values** | Comma-separated SecretProviderClass names |

```yaml
metadata:
  annotations:
    secretproviderclass.reloader.stakater.com/reload: "vault-csi-provider"
```

---

### `reloader.stakater.com/search`

Enables search mode. Reloader only triggers a restart when a referenced `ConfigMap` or `Secret` also has the `reloader.stakater.com/match: "true"` annotation. Used together with `match` to give Secret/ConfigMap owners control over which resources trigger reloads.

| Field | Value |
|---|---|
| **Applies to** | Deployment, StatefulSet, Daemonset, Rollout, CronJob, Job |
| **Accepted values** | `"true"` |

```yaml
metadata:
  annotations:
    reloader.stakater.com/search: "true"
```

See [search and match pattern](#search-and-match-pattern) for a full example.

---

### `secrets.exclude.reloader.stakater.com/reload`

Excludes specific `Secrets` from triggering a reload for this workload, even if `auto: "true"` is set.

| Field | Value |
|---|---|
| **Applies to** | Deployment, StatefulSet, Daemonset, Rollout, CronJob, Job |
| **Accepted values** | Comma-separated Secret names |

```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
    secrets.exclude.reloader.stakater.com/reload: "audit-log-secret"
```

---

### `configmaps.exclude.reloader.stakater.com/reload`

Excludes specific `ConfigMaps` from triggering a reload for this workload.

| Field | Value |
|---|---|
| **Applies to** | Deployment, StatefulSet, Daemonset, Rollout, CronJob, Job |
| **Accepted values** | Comma-separated ConfigMap names |

```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
    configmaps.exclude.reloader.stakater.com/reload: "shared-readonly-config"
```

---

### `secretproviderclasses.exclude.reloader.stakater.com/reload`

Excludes specific `SecretProviderClass` resources from triggering a reload.

| Field | Value |
|---|---|
| **Applies to** | Deployment, StatefulSet, Daemonset, Rollout, CronJob, Job |
| **Accepted values** | Comma-separated SecretProviderClass names |

---

### `reloader.stakater.com/rollout-strategy`

Controls how Reloader triggers a reload for Argo `Rollout` resources specifically.

| Field | Value |
|---|---|
| **Applies to** | Argo Rollout only |
| **Accepted values** | `"rollout"` (default), `"restart"` |

| Strategy | Behaviour |
|---|---|
| `"rollout"` | Patches the pod template to trigger a new rollout. GitOps tools may detect this as drift. |
| `"restart"` | Deletes pods directly without patching the template. Avoids GitOps drift but is more disruptive. |

```yaml
metadata:
  annotations:
    reloader.stakater.com/rollout-strategy: "restart"
```

---

### `deployment.reloader.stakater.com/pause-period`

Pauses reload triggering for a Deployment for the specified duration after a reload. Prevents a burst of rapid configuration changes from causing repeated restarts.

| Field | Value |
|---|---|
| **Applies to** | Deployment |
| **Accepted values** | Go duration string — must be positive (e.g. `"30s"`, `"5m"`, `"1h"`) |

```yaml
metadata:
  annotations:
    deployment.reloader.stakater.com/pause-period: "5m"
```

---

## ConfigMap and Secret annotations

These annotations are placed on `ConfigMap` or `Secret` resources.

### `reloader.stakater.com/match`

Marks a `ConfigMap` or `Secret` as eligible for the [search and match pattern](#search-and-match-pattern). Only has effect when the consuming workload has `reloader.stakater.com/search: "true"`.

| Field | Value |
|---|---|
| **Applies to** | ConfigMap, Secret |
| **Accepted values** | `"true"`, `"false"` |

```yaml
metadata:
  annotations:
    reloader.stakater.com/match: "true"
```

---

### `reloader.stakater.com/ignore`

Instructs Reloader to skip this resource entirely. Changes to it will never trigger a reload, regardless of what workloads reference it or what annotations those workloads have.

| Field | Value |
|---|---|
| **Applies to** | ConfigMap, Secret, SecretProviderClass |
| **Accepted values** | `"true"` |

```yaml
metadata:
  annotations:
    reloader.stakater.com/ignore: "true"
```

---

## System-managed annotations

These annotations are written by Reloader itself. Do not set them manually.

### `reloader.stakater.com/last-reloaded-from`

Added to the workload's pod template metadata to record which resource triggered the last reload. Only present when `--reload-strategy=annotations` is configured.

| Field | Value |
|---|---|
| **Managed by** | Reloader (read-only) |
| **Applies to** | Pod template metadata of any supported workload |

### `deployment.reloader.stakater.com/paused-at`

Records the timestamp when a pause period started. Set by Reloader when `pause-period` is in effect.

| Field | Value |
|---|---|
| **Managed by** | Reloader (read-only) |
| **Applies to** | Deployment |

---

## Patterns

### Auto pattern

The simplest pattern. Reloader watches all `ConfigMaps` and `Secrets` referenced anywhere in the pod spec (environment variables, volume mounts, `envFrom`).

```yaml
# deployment.yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
```

When any referenced ConfigMap or Secret changes, Reloader restarts the workload.

---

### Named resource pattern

Explicitly name the resources to watch. Useful when the ConfigMap or Secret is not directly referenced in the pod spec (for example, read by the application at runtime from a mounted path).

```yaml
# deployment.yaml
metadata:
  annotations:
    secret.reloader.stakater.com/reload: "database-credentials"
    configmap.reloader.stakater.com/reload: "app-config"
```

---

### Search and match pattern

Separates concerns: the workload opts in to "search mode", and individual Secrets or ConfigMaps opt in to being "matchable". This lets Secret owners control reload behaviour independently of the workload owner.

```yaml
# deployment.yaml
metadata:
  annotations:
    reloader.stakater.com/search: "true"
```

```yaml
# secret.yaml
metadata:
  annotations:
    reloader.stakater.com/match: "true"
```

The workload will only restart when a ConfigMap or Secret it references has `match: "true"`. Resources without `match: "true"` are ignored even if they change.

---

### CSI file-based pattern

When using the Secrets Store CSI Driver without `secretObjects` (no Kubernetes Secret is created), use `SecretProviderClass`-based annotations instead.

```yaml
# deployment.yaml
metadata:
  annotations:
    secretproviderclass.reloader.stakater.com/reload: "vault-csi-provider"
```

This requires `reloader.enableCSIIntegration: true` in the Helm values.

---

## Behaviour rules

**`auto` takes precedence over `search`**
If both `reloader.stakater.com/auto: "true"` and `reloader.stakater.com/search: "true"` are set on the same workload, `auto` wins and `search` is ignored.

**Global auto-reload mode**
If Reloader is started with `--auto-reload-all=true` (or `reloader.autoReloadAll: true` in Helm), all workloads behave as if they have `auto: "true"`. Setting `reloader.stakater.com/auto: "false"` explicitly on a workload opts it out.

**Typed annotations vs generic**
`secret.reloader.stakater.com/auto` and `configmap.reloader.stakater.com/auto` can be combined. Either one being `"true"` enables reloading for that resource type independently.

**Exclude annotations work alongside auto**
`secrets.exclude.reloader.stakater.com/reload` and `configmaps.exclude.reloader.stakater.com/reload` can be combined with `auto: "true"` to watch everything except specific named resources.

---

## Custom annotation keys

All annotation keys can be overridden cluster-wide via Helm values. This is useful when the default annotation names conflict with another tool or when your organisation enforces a custom annotation domain.

```yaml
reloader:
  custom_annotations:
    auto: "myorg.com/reload"
    secret: "myorg.com/reload-secret"
    configmap: "myorg.com/reload-configmap"
    search: "myorg.com/reload-search"
    match: "myorg.com/reload-match"
    secret_auto: "myorg.com/reload-secret-auto"
    configmap_auto: "myorg.com/reload-configmap-auto"
    pausePeriod: "myorg.com/reload-pause-period"
    pauseTime: "myorg.com/reload-paused-at"
```

When custom annotation keys are configured, only those keys are recognised. The default `reloader.stakater.com/*` keys are no longer active.
