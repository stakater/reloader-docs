# Helm Values & CLI Flags Reference

Reloader is configured through Helm values, which the chart translates into CLI flags on the Reloader process. This page documents every available setting, its CLI flag equivalent, default value, and what it does.

---

## How to apply settings

**Values file (recommended for production):**

```yaml
# values.yaml
reloader:
  autoReloadAll: true
  logLevel: debug
```

```bash
helm install reloader stakater/reloader -f values.yaml
```

**Inline `--set`:**

```bash
helm install reloader stakater/reloader \
  --set reloader.autoReloadAll=true \
  --set reloader.logLevel=debug
```

---

## Core behavior

| Helm value | CLI flag | Type | Default | Description |
|---|---|---|---|---|
| `reloader.autoReloadAll` | `--auto-reload-all` | bool | `false` | Treat every workload as if it has `reloader.stakater.com/auto: "true"`. Individual workloads can still opt out by setting the annotation to `"false"`. |
| `reloader.reloadOnCreate` | `--reload-on-create` | bool | `false` | Also trigger reloads when a ConfigMap or Secret is **created**, not just updated. |
| `reloader.reloadOnDelete` | `--reload-on-delete` | bool | `false` | Also trigger reloads when a ConfigMap or Secret is **deleted**. |
| `reloader.reloadStrategy` | `--reload-strategy` | string | `env-vars` | How Reloader forces a rolling update. See [Reload strategies](#reload-strategies). |
| `reloader.webhookUrl` | `--webhook-url` | string | `""` | Send an HTTP request to this URL on change instead of restarting workloads. When set, no workloads are restarted. |
| `reloader.isArgoRollouts` | `--is-Argo-Rollouts` | bool | `false` | Enable support for Argo `Rollout` resources. |
| `reloader.isOpenshift` | *(Helm only)* | bool | `false` | Enable OpenShift `DeploymentConfig` support. Reloader auto-detects OpenShift at startup; only set this if auto-detection fails. |
| `reloader.enableCSIIntegration` | `--enable-csi-integration` | bool | `false` | Enable watching `SecretProviderClass` resources via the Secrets Store CSI Driver. Required for file-based CSI secret mounts. |

### Reload strategies

| Value | Behaviour |
|---|---|
| `env-vars` (default) | Patches a dummy environment variable onto the pod template to force a rolling update. |
| `annotations` | Adds `reloader.stakater.com/last-reloaded-from` to the pod template. Produces less drift when using GitOps tools (Argo CD, Flux). |

---

## Namespace and resource filtering

| Helm value | CLI flag | Type | Default | Description |
|---|---|---|---|---|
| `reloader.watchGlobally` | *(Helm only)* | bool | `true` | When `false`, Reloader only watches the namespace it is deployed in. When `true`, it watches all namespaces (subject to `namespaceSelector` and `ignoreNamespaces`). |
| `reloader.namespaceSelector` | `--namespace-selector` | string | `""` | Comma-separated `key=value` label selectors. Only namespaces matching all selectors are watched. Example: `environment=production`. |
| `reloader.ignoreNamespaces` | `--namespaces-to-ignore` | string | `""` | Comma-separated list of namespace names to exclude entirely. |
| `reloader.resourceLabelSelector` | `--resource-label-selector` | string | `""` | Comma-separated `key=value` label selectors. Only ConfigMaps and Secrets matching all selectors are watched. |
| `reloader.ignoreSecrets` | `--resources-to-ignore=secrets` | bool | `false` | Ignore all Secrets cluster-wide. Reloader will not watch or react to any Secret changes. |
| `reloader.ignoreConfigMaps` | `--resources-to-ignore=configMaps` | bool | `false` | Ignore all ConfigMaps cluster-wide. |
| `reloader.ignoreJobs` | `--ignored-workload-types=jobs` | bool | `false` | Skip `Job` workloads — changes to referenced ConfigMaps/Secrets will not trigger Job restarts. |
| `reloader.ignoreCronJobs` | `--ignored-workload-types=cronjobs` | bool | `false` | Skip `CronJob` workloads. |

When both `namespaceSelector` and `resourceLabelSelector` are set, both conditions must match for a resource to be watched.

---

## High availability

Running more than one Reloader replica without HA enabled causes duplicate reloads. Enable HA to use leader election so only one replica acts at a time.

| Helm value | CLI flag | Type | Default | Description |
|---|---|---|---|---|
| `reloader.enableHA` | `--enable-ha` | bool | `false` | Enable leader election via a Kubernetes `Lease` lock. Required when running multiple replicas. |
| `reloader.syncAfterRestart` | `--sync-after-restart` | bool | `false` | When a new leader is elected, it re-evaluates all tracked workloads and triggers any missed reloads. Requires `reloadOnCreate: true`. |
| `reloader.deployment.replicas` | *(Helm only)* | int | `1` | Number of Reloader replicas. Set to `2` or more only when `enableHA: true`. |

**Minimum HA configuration:**

```yaml
reloader:
  enableHA: true
  reloadOnCreate: true
  syncAfterRestart: true
  deployment:
    replicas: 2
```

HA uses a `Lease` object named `stakater-reloader-lock` in the Reloader namespace. The pod must have `POD_NAME` and `POD_NAMESPACE` environment variables set (the Helm chart sets these automatically).

---

## Logging

| Helm value | CLI flag | Type | Default | Description |
|---|---|---|---|---|
| `reloader.logLevel` | `--log-level` | string | `info` | Log verbosity. Valid values: `trace`, `debug`, `info`, `warning`, `error`, `fatal`, `panic`. |
| `reloader.logFormat` | `--log-format` | string | `""` | Log format. Empty string produces structured text output. Set to `json` for machine-readable logs. |

---

## Metrics and monitoring

Reloader exposes a Prometheus metrics endpoint on `:9090/metrics`.

| Helm value | CLI flag | Type | Default | Description |
|---|---|---|---|---|
| `reloader.enableMetricsByNamespace` | *(Helm only)* | bool | `false` | Expose a per-namespace reload counter. May produce high cardinality in clusters with many namespaces. |
| `reloader.podMonitor.enabled` | *(Helm only)* | bool | `false` | Create a `PodMonitor` resource for Prometheus Operator scraping (recommended). |
| `reloader.serviceMonitor.enabled` | *(Helm only)* | bool | `false` | Create a `ServiceMonitor` resource. **Deprecated** — use `podMonitor` instead. Requires a `Service` to be configured. |

**Enable PodMonitor:**

```yaml
reloader:
  podMonitor:
    enabled: true
    labels:
      release: prometheus  # match your Prometheus Operator selector
```

---

## Custom annotation keys

All annotation key names can be overridden cluster-wide. This is useful when the default `reloader.stakater.com/*` keys conflict with another tool, or when your organisation enforces a custom annotation domain.

| Helm value | CLI flag | Default annotation key |
|---|---|---|
| `reloader.custom_annotations.auto` | `--auto-annotation` | `reloader.stakater.com/auto` |
| `reloader.custom_annotations.configmap` | `--configmap-annotation` | `configmap.reloader.stakater.com/reload` |
| `reloader.custom_annotations.secret` | `--secret-annotation` | `secret.reloader.stakater.com/reload` |
| `reloader.custom_annotations.configmap_auto` | `--configmap-auto-annotation` | `configmap.reloader.stakater.com/auto` |
| `reloader.custom_annotations.secret_auto` | `--secret-auto-annotation` | `secret.reloader.stakater.com/auto` |
| `reloader.custom_annotations.search` | `--auto-search-annotation` | `reloader.stakater.com/search` |
| `reloader.custom_annotations.match` | `--search-match-annotation` | `reloader.stakater.com/match` |
| `reloader.custom_annotations.pausePeriod` | `--pause-deployment-annotation` | `deployment.reloader.stakater.com/pause-period` |
| `reloader.custom_annotations.pauseTime` | `--pause-deployment-time-annotation` | `deployment.reloader.stakater.com/paused-at` |

When any custom annotation key is configured, only that key is recognised — the default key is no longer active.

---

## Deployment configuration

### Resources

No resource requests or limits are set by default. Set them explicitly for production:

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

### Scheduling

| Helm value | Type | Default | Description |
|---|---|---|---|
| `reloader.deployment.nodeSelector` | object | `{}` | Node selector labels for pod scheduling. |
| `reloader.deployment.affinity` | object | `{}` | Affinity and anti-affinity rules. |
| `reloader.deployment.tolerations` | list | `[]` | Tolerations for tainted nodes. |
| `reloader.deployment.topologySpreadConstraints` | list | `[]` | Spread pods across zones or nodes. |
| `reloader.deployment.priorityClassName` | string | `""` | PriorityClass name for the pod. |

### Security context

| Helm value | Type | Default | Description |
|---|---|---|---|
| `reloader.deployment.securityContext` | object | `runAsNonRoot: true, runAsUser: 65534, seccompProfile: RuntimeDefault` | Pod-level security context. |
| `reloader.deployment.containerSecurityContext` | object | `{}` | Container-level security context. |
| `reloader.readOnlyRootFileSystem` | bool | `false` | Mount the container root filesystem as read-only. |

**OpenShift note:** On OpenShift 4.13.3+, set `reloader.deployment.securityContext.runAsUser: null` to allow OpenShift to assign the UID dynamically.

### Other deployment options

| Helm value | Type | Default | Description |
|---|---|---|---|
| `reloader.deployment.replicas` | int | `1` | Number of replicas. Only increase when `enableHA: true`. |
| `reloader.deployment.revisionHistoryLimit` | int | `2` | Number of old ReplicaSets to retain. |
| `reloader.deployment.annotations` | object | `{}` | Annotations on the Deployment resource. |
| `reloader.deployment.pod.annotations` | object | `{}` | Annotations on the pod template. |
| `reloader.deployment.dnsConfig` | object | `{}` | Custom DNS configuration for pods. |
| `reloader.deployment.volumeMounts` | list | `[]` | Additional volume mounts. |
| `reloader.deployment.volumes` | list | `[]` | Additional volumes. |
| `reloader.deployment.gomaxprocsOverride` | string | `""` | Override `GOMAXPROCS`. Set to `"0"` for Go runtime default. |
| `reloader.deployment.gomemlimitOverride` | string | `""` | Override `GOMEMLIMIT`. Set to `"0"` for Go runtime default. |

### Environment variables

Pass additional environment variables to the Reloader container. Used primarily for webhook alerting.

```yaml
reloader:
  deployment:
    env:
      open:
        ALERT_ON_RELOAD: "true"
        ALERT_SINK: "slack"
        ALERT_WEBHOOK_URL: "https://hooks.slack.com/..."
        ALERT_ADDITIONAL_INFO: "prod-cluster"
      secret:
        # read from the default reloader Secret by key name
        ALERT_WEBHOOK_URL: alert_webhook_key
      existing:
        my-existing-secret:
          ALERT_WEBHOOK_URL: webhook_url_key
```

---

## RBAC and service account

| Helm value | Type | Default | Description |
|---|---|---|---|
| `reloader.rbac.enabled` | bool | `true` | Create `ClusterRole` and `ClusterRoleBinding` granting Reloader read access to ConfigMaps, Secrets, Deployments, etc. |
| `reloader.serviceAccount.create` | bool | `true` | Create a dedicated `ServiceAccount` for Reloader. |
| `reloader.serviceAccount.name` | string | `""` | Name of the ServiceAccount. If empty, a name is generated from the Helm release. |
| `reloader.serviceAccount.annotations` | object | `{}` | Annotations on the ServiceAccount — useful for IRSA (AWS) or Workload Identity (GCP). |

---

## Image

| Helm value | Type | Default | Description |
|---|---|---|---|
| `image.repository` | string | `ghcr.io/stakater/reloader` | Container image repository. Override to `ghcr.io/stakater/reloader-enterprise` for the Enterprise image. |
| `image.tag` | string | `v1.4.16` | Image tag. |
| `image.pullPolicy` | string | `IfNotPresent` | Kubernetes image pull policy. |
| `global.imagePullSecrets` | list | `[]` | Image pull secrets for private registries. |
| `global.imageRegistry` | string | `""` | Global image registry prefix. |

---

## Advanced

### Pod Disruption Budget

```yaml
reloader:
  podDisruptionBudget:
    enabled: true
    minAvailable: 1
```

| Helm value | Type | Default | Description |
|---|---|---|---|
| `reloader.podDisruptionBudget.enabled` | bool | `false` | Create a `PodDisruptionBudget`. |
| `reloader.podDisruptionBudget.minAvailable` | int | — | Minimum available replicas during disruption. |
| `reloader.podDisruptionBudget.maxUnavailable` | int | — | Maximum unavailable replicas. If both are set, only `maxUnavailable` is used. |

### Vertical Pod Autoscaler

```yaml
reloader:
  verticalPodAutoscaler:
    enabled: true
    updatePolicy:
      updateMode: Auto
```

| Helm value | Type | Default | Description |
|---|---|---|---|
| `reloader.verticalPodAutoscaler.enabled` | bool | `false` | Create a `VerticalPodAutoscaler` resource. Requires VPA CRDs installed. |
| `reloader.verticalPodAutoscaler.updatePolicy.updateMode` | string | `Auto` | VPA update mode: `Off`, `Initial`, `Recreate`, or `Auto`. |
| `reloader.verticalPodAutoscaler.controlledResources` | list | `[]` | Resources VPA can adjust. Defaults to CPU and memory. |
| `reloader.verticalPodAutoscaler.minAllowed` | object | `{}` | Minimum resource bounds. |
| `reloader.verticalPodAutoscaler.maxAllowed` | object | `{}` | Maximum resource bounds. |

### Network Policy

```yaml
reloader:
  netpol:
    enabled: true
    from:
      - podSelector:
          matchLabels:
            app.kubernetes.io/name: prometheus
```

| Helm value | Type | Default | Description |
|---|---|---|---|
| `reloader.netpol.enabled` | bool | `false` | Create a `NetworkPolicy` to restrict traffic to Reloader pods. |
| `reloader.netpol.from` | list | `[]` | Ingress rules — pods/namespaces allowed to reach Reloader (e.g. Prometheus for scraping). |
| `reloader.netpol.to` | list | `[]` | Egress rules. |

### Profiling (pprof)

| Helm value | CLI flag | Type | Default | Description |
|---|---|---|---|---|
| `reloader.enablePProf` | `--enable-pprof` | bool | `false` | Start a pprof HTTP server for Go runtime profiling. |
| `reloader.pprofAddr` | `--pprof-addr` | string | `:6060` | Address for the pprof server. |
