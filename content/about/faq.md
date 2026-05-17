# Frequently Asked Questions

---

## How it works

### Does Reloader restart all pods at once?

No. Reloader patches the workload's pod template and lets Kubernetes handle the rollout. Kubernetes uses the workload's own `RollingUpdate` strategy — respecting `maxUnavailable` and `maxSurge` settings — so pods are replaced gradually, not all at once.

### Does Reloader cause downtime?

Not if your workload is configured correctly for rolling updates. Reloader delegates restarts to Kubernetes rolling update machinery. If you have `maxUnavailable: 0` and enough replicas, there is no downtime. Single-replica deployments will experience a brief interruption during the pod replacement — the same as any rolling restart.

### How does Reloader detect that a ConfigMap or Secret changed?

Reloader uses the Kubernetes watch API to receive real-time events when a ConfigMap or Secret is updated. It then compares the old and new data. If the data content changed (not just metadata such as labels or annotations), it proceeds with the reload. Metadata-only changes never trigger a restart.

### Does it modify my application code?

No. Reloader works entirely at the Kubernetes level through annotations on the workload. Your application code does not need to be changed, and your container image does not need to include any reload logic.

### What does Reloader actually do when it triggers a restart?

Reloader patches the pod template of the matching workload. It either:

- Injects or updates a dummy environment variable (`STAKATER_<NAME>_SECRET` or `STAKATER_<NAME>_CONFIGMAP`) set to the SHA1 hash of the changed resource's data (`env-vars` strategy, default), or
- Adds the annotation `reloader.stakater.com/last-reloaded-from` to the pod template metadata (`annotations` strategy)

Either way, Kubernetes detects the pod template has changed and initiates a rolling update. Reloader does not restart pods directly.

### Does Reloader respect PodDisruptionBudgets?

Yes. Because Reloader delegates restarts to Kubernetes rolling updates, PodDisruptionBudgets are respected. Kubernetes will not evict pods in a way that violates an active PDB.

### What happens if Reloader is down when a ConfigMap or Secret changes?

The change will not trigger a reload while Reloader is unavailable. When Reloader comes back up, it does not automatically replay missed changes. If your cluster uses `syncAfterRestart: true` and `reloadOnCreate: true`, a newly elected leader will re-sync tracked workloads — see the [installation guide](../installation/install-oss.md) for the HA configuration.

For production environments, running Reloader with [HA mode](../installation/install-oss.md#enable-high-availability) (multiple replicas with leader election) reduces the risk of availability gaps.

---

## Workload types

### Does Reloader work with StatefulSets?

Yes. StatefulSets are fully supported. Reloader patches the StatefulSet's pod template in the same way it does for Deployments. Kubernetes then performs a rolling update according to the StatefulSet's `updateStrategy`.

### Does Reloader work with Daemonsets?

Yes. Daemonsets are fully supported.

### Does Reloader work with Argo Rollouts?

Yes, with one configuration step. Set `reloader.isArgoRollouts: true` in the Helm values. Reloader then recognises Argo `Rollout` resources and can trigger restarts via either the `rollout` strategy (patches the pod template) or the `restart` strategy (deletes pods directly, avoiding GitOps drift).

### Does Reloader work with CronJobs and Jobs?

Yes, with caveats. Reloader can watch CronJobs and trigger a pod template update. Because Jobs and CronJobs are not long-running workloads, the practical effect depends on your use case. You can disable Job and CronJob watching with `reloader.ignoreJobs: true` and `reloader.ignoreCronJobs: true`.

### Does Reloader work with OpenShift DeploymentConfigs?

Yes. Reloader auto-detects whether it is running on OpenShift by probing the cluster API at startup. If auto-detection does not work in your environment, set `reloader.isOpenshift: true` explicitly.

---

## Annotations and configuration

### What is the difference between `auto`, `search/match`, and named reload annotations?

There are three annotation patterns:

| Pattern | How it works |
|---|---|
| `reloader.stakater.com/auto: "true"` | Watches all ConfigMaps and Secrets that the pod spec references (via env vars, `envFrom`, or volume mounts). Any change triggers a restart. |
| `secret.reloader.stakater.com/reload: "my-secret"` | Watches a specific named resource. The resource does not need to be in the pod spec. |
| `reloader.stakater.com/search: "true"` + `reloader.stakater.com/match: "true"` on the Secret | Workload opts into search mode; only resources that are explicitly marked with `match: "true"` trigger a restart. |

The `auto` pattern is simplest. The `search/match` pattern is useful when different teams own the workload and the Secret independently.

### Can I watch only Secrets and ignore ConfigMap changes?

Yes. Use `secret.reloader.stakater.com/auto: "true"` instead of `reloader.stakater.com/auto: "true"`. The typed annotation restricts watching to Secrets only.

### Can I exclude a specific Secret from triggering a restart even when `auto: "true"` is set?

Yes. Use the exclude annotation:

```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
    secrets.exclude.reloader.stakater.com/reload: "my-shared-secret"
```

### Can I prevent a workload from being restarted too frequently?

Yes. Use `deployment.reloader.stakater.com/pause-period` to add a cooldown after a reload:

```yaml
metadata:
  annotations:
    deployment.reloader.stakater.com/pause-period: "5m"
```

During the pause period, subsequent changes to the watched resources will not trigger additional restarts.

---

## Namespace and cluster scope

### Does Reloader watch all namespaces by default?

Yes. By default Reloader watches the entire cluster (`reloader.watchGlobally: true`). This is the recommended setting for platform-wide deployments.

### Can I restrict Reloader to a single namespace?

Yes. Set `reloader.watchGlobally: false`. Reloader will then only watch the namespace it is deployed in.

### Can I restrict Reloader to specific namespaces using label selectors?

Yes. Set `reloader.namespaceSelector` to a Kubernetes label selector:

```yaml
reloader:
  namespaceSelector: "environment=production"
```

Only namespaces matching that selector will be watched.

### Can I exclude specific namespaces?

Yes. Set `reloader.ignoreNamespaces` to a comma-separated list of namespace names.

---

## Compatibility

### What Kubernetes versions does Reloader support?

Reloader OSS requires Kubernetes 1.19 or later. The Reloader Enterprise compatibility matrix is published in the [Versions](../versions.md) section and specifies the tested Kubernetes version range for each release.

### Does Reloader work with Helm-managed workloads?

Yes. Reloader only patches the environment variable or annotation it controls. Subsequent `helm upgrade` runs see the Reloader-injected value as part of the live state and leave it in place. Helm does not remove or overwrite Reloader's changes.

### Does Reloader work with GitOps tools like Argo CD or Flux?

Yes, with a configuration choice. Reloader's default `env-vars` reload strategy injects an environment variable into the pod template, which Argo CD detects as drift from the Git state. To avoid this, use the `annotations` reload strategy:

```yaml
reloader:
  reloadStrategy: annotations
```

See the [Argo CD guide](../how-to-guides/use-reloader-with-argocd.md) and the [Flux guide](../how-to-guides/use-reloader-with-flux.md) for details.

### Does Reloader work with External Secrets Operator?

Yes. Reloader watches the Kubernetes Secret that ESO creates and keeps in sync. When ESO updates the Secret after a rotation, Reloader detects the data change and triggers the rolling restart. No ESO-specific configuration is needed.

### Does Reloader work with Secrets Store CSI Driver?

Yes, with one extra step. When using the CSI Driver **without** `secretObjects` (no Kubernetes Secret is created — secrets are mounted directly as files), enable CSI integration:

```yaml
reloader:
  enableCSIIntegration: true
```

Then annotate the workload with the `SecretProviderClass` name instead of a Secret name:

```yaml
metadata:
  annotations:
    secretproviderclass.reloader.stakater.com/reload: "my-vault-provider"
```

### Does Reloader work with Sealed Secrets?

Yes. Sealed Secrets decrypts the `SealedSecret` into a standard Kubernetes `Secret`. Reloader watches that resulting Secret and triggers restarts when its data changes, regardless of how it was created.

### Does Reloader work on OpenShift?

Yes. Reloader supports OpenShift and auto-detects the cluster type at startup to enable `DeploymentConfig` support. The [Reloader Enterprise](editions.md) UBI image variant is recommended for OpenShift environments with Red Hat certification requirements.

---

## Operations

### How do I know if a reload was triggered?

Three ways:

1. **Logs** — check Reloader's pod logs for lines like `Changes detected in 'my-secret'` and `Updated 'my-app' of type 'Deployment'`
1. **Prometheus metrics** — query `reloader_reload_executed_total` on the metrics endpoint at port `9090`
1. **Webhook alerts** — configure `ALERT_ON_RELOAD: "true"` to receive a notification to Slack, Teams, Google Chat, or a custom webhook

See [Monitoring Reloader](../how-to-guides/monitor-reloader.md) and [Alert When Reloader Triggers a Restart](../how-to-guides/alerting-on-reload.md) for details.

### What is the performance impact of running Reloader?

Reloader is a lightweight controller. It maintains a watch connection to the Kubernetes API server and processes events asynchronously. The typical resource footprint is:

- **CPU**: ~10–20m during normal operation; brief spikes during reload events
- **Memory**: ~64–128 MB depending on cluster size and number of watched resources

Set explicit resource requests and limits using the Helm values. See the [installation guide](../installation/install-oss.md#resource-requests-and-limits) for recommended values.

### Can I run multiple instances of Reloader?

Yes, with leader election enabled. Set `reloader.enableHA: true` and `reloader.deployment.replicas: 2` (or more). Only the leader processes reload events; the standby takes over if the leader becomes unavailable.

Running multiple instances without HA mode enabled can result in duplicate restarts.

### Does Reloader reload on Secret creation, or only on updates?

By default, only on **updates** (data changes). To also trigger a reload when a ConfigMap or Secret is first created, set:

```yaml
reloader:
  reloadOnCreate: true
```

---

## OSS vs Enterprise

### What is the difference between Reloader OSS and Reloader Enterprise?

Both share the same core reload functionality. Enterprise adds:

- **Hardened images** — continuously scanned for CVEs, available in UBI (Red Hat Universal Base Image) variant
- **Validated integrations** — Vault, OpenBao, and Conjur are tested end-to-end on every release
- **Long-term maintenance** — backported security and critical fixes across supported versions
- **Commercial support and SLA** — a support path for production incidents
- **Production onboarding** — guided setup and compatibility guarantees across upgrades

See the full [edition comparison](editions.md) for details.

### How do I get Reloader Enterprise?

Contact Stakater via the [Stakater support portal](https://support.stakater.com/) or speak to your Stakater account team. Once access is granted, installation uses the standard OSS Helm chart with the Enterprise image override — see the [Enterprise installation guide](../installation/install.md).
