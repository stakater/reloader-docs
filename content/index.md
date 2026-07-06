# Reloader

> Automatically restart Kubernetes workloads when ConfigMaps or Secrets change.

Kubernetes does not restart pods when a ConfigMap or Secret is updated. Reloader closes that gap. It watches for changes to ConfigMaps and Secrets and triggers a rolling restart of every Deployment, StatefulSet, or Daemonset that depends on them — automatically, without modifying your application.

---

## Quick start

Install Reloader via Helm:

```bash
helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update
helm install reloader stakater/reloader \
  --namespace reloader \
  --create-namespace
```

Add one annotation to any Deployment:

```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
```

From this point on, whenever a ConfigMap or Secret referenced by that Deployment changes, Reloader triggers a rolling restart. No application changes required.

---

## The problem Reloader solves

In Kubernetes, updating a ConfigMap or Secret does not automatically update running pods. Environment variables set at pod start time do not change while the pod is running. This creates a gap between the desired configuration and what is actually running:

- A database password rotates in Vault or AWS Secrets Manager
- The sync controller (ESO, CSI Driver) updates the Kubernetes Secret
- The running pods continue using the **old password** until manually restarted

This gap causes stale configuration, broken secret rotation workflows, and operational incidents that are hard to diagnose. Reloader eliminates the manual step.

---

## How it works

Reloader uses the Kubernetes watch API to receive real-time events when a ConfigMap or Secret is updated. It checks whether the data actually changed (not just metadata). If it did, Reloader finds all workloads with matching annotations and patches their pod template — either injecting an environment variable with the resource's SHA1 hash, or updating an annotation. Kubernetes detects the pod template change and initiates a rolling update, respecting the workload's own `RollingUpdate` strategy.

```text
ConfigMap or Secret updated
  ↓
Reloader detects data change (watch API)
  ↓
Finds workloads with matching annotations
  ↓
Patches pod template
  ↓
Kubernetes rolling restart
  ↓
Pods start with updated configuration
```

See [How Reloader Works](architecture/how-it-works.md) for the full mechanics.

---

## Supported workloads

| Workload | Support |
|---|---|
| `Deployment` | ✅ Full support |
| `StatefulSet` | ✅ Full support |
| `DaemonSet` | ✅ Full support |
| `Argo Rollout` | ✅ Requires `reloader.isArgoRollouts: true` |
| `CronJob` | ✅ Supported |
| `Job` | ✅ Supported |
| `DeploymentConfig` | ✅ OpenShift only, auto-detected |

---

## What Reloader watches

| Resource | Notes |
|---|---|
| `Secret` | Default; disable with `reloader.ignoreSecrets: true` |
| `ConfigMap` | Default; disable with `reloader.ignoreConfigMaps: true` |
| `SecretProviderClass` | Requires `reloader.enableCSIIntegration: true` — for file-based CSI secrets with no Kubernetes Secret |

---

## Works with your secrets stack

Reloader is tool-agnostic. It watches the Kubernetes Secret or ConfigMap, regardless of how it was created or updated. It works with:

**Secret delivery:**

- [External Secrets Operator](integrations/index.md) — Vault, OpenBao, Conjur, AWS Secrets Manager, Azure Key Vault, GCP Secret Manager, Infisical, Doppler, and more
- [Secrets Store CSI Driver](integrations/vault/vault-csi.md) — Vault, OpenBao, Conjur, AWS ASCP, Azure Key Vault Provider
- Vault Agent Injector (when `agent-inject-secret` creates a Kubernetes Secret)
- Any tool that writes to a Kubernetes Secret or ConfigMap

**GitOps and deployment:**

- [Argo CD](how-to-guides/use-reloader-with-argocd.md) — use the `annotations` reload strategy to avoid sync drift
- [Flux](how-to-guides/use-reloader-with-flux.md)
- Helm — fully compatible, no chart changes required
- Kustomize

---

## Annotation patterns

Three patterns for controlling which changes trigger a restart:

**Auto — watch everything referenced in the pod spec:**

```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
```

**Named — watch specific resources by name:**

```yaml
metadata:
  annotations:
    secret.reloader.stakater.com/reload: "db-credentials,api-keys"
    configmap.reloader.stakater.com/reload: "app-config"
```

**Search and match — resource owners control which Secrets trigger restarts:**

```yaml
# On the Deployment
metadata:
  annotations:
    reloader.stakater.com/search: "true"

# On the Secret
metadata:
  annotations:
    reloader.stakater.com/match: "true"
```

See the full [Annotation Reference](reference/annotations.md) for all supported annotations.

---

## Key capabilities

- **No application changes** — reload logic lives in Kubernetes annotations, not in application code
- **Works with any language or framework** — Python, Go, Java, Node.js, or any containerised workload
- **Works with third-party and legacy apps** — no source code access required
- **Respects rolling update strategy** — Reloader delegates restarts to Kubernetes; `maxUnavailable` and PodDisruptionBudgets are respected
- **Namespace scoping** — watch all namespaces, one namespace, or a label-selected subset
- **High availability** — run multiple replicas with leader election
- **Prometheus metrics** — `reloader_reload_executed_total` tracks every reload
- **Webhook alerts** — Slack, Microsoft Teams, Google Chat, or any https endpoint
- **GitOps-compatible** — `annotations` reload strategy avoids Argo CD sync drift
- **OpenShift support** — auto-detects DeploymentConfig resources
- **CSI Driver integration** — watches `SecretProviderClassPodStatus` for file-based secret rotation

---

## OSS and Enterprise

| | Reloader OSS | Reloader Enterprise |
|---|---|---|
| Core reload | ✅ | ✅ |
| All workload types | ✅ | ✅ |
| Prometheus metrics and alerting | ✅ | ✅ |
| Hardened container images (Standard + UBI) | ❌ | ✅ |
| Validated Vault, OpenBao, Conjur integrations | ❌ | ✅ |
| Long-term maintenance and backported fixes | ❌ | ✅ |
| Commercial support and SLA | ❌ | ✅ |
| Suitable for regulated environments | ❌ | ✅ |

[Compare editions in full →](about/editions.md)

To get Reloader Enterprise, open a ticket at the [Stakater support portal](https://support.stakater.com/) or speak to your Stakater account team.

---

## Where to go next

**Set up Reloader:**

- [Install Reloader OSS](installation/install-oss.md)
- [Install Reloader Enterprise](installation/install.md)
- [Run Reloader on OpenShift](how-to-guides/use-reloader-with-openshift.md)

**Common tasks:**

- [Restart pods when a ConfigMap changes](how-to-guides/restart-pods-when-configmap-changes.md)
- [Restart pods when a Secret changes](how-to-guides/restart-pods-when-secret-changes.md)
- [Restart pods when external secrets change](how-to-guides/restart-pods-when-external-secrets-change.md)
- [Reload pods on TLS certificate rotation](how-to-guides/reload-pods-on-tls-certificate-rotation.md)

**Understand the concepts:**

- [The secret propagation problem in Kubernetes](concepts/secret-propagation-problem-kubernetes.md)
- [How Reloader works](architecture/how-it-works.md)
- [Reloader vs other approaches](concepts/comparisons/reloader-vs-checksum-annotations.md)

**Integrate with your secrets stack:**

- [HashiCorp Vault](integrations/vault/index.md)
- [OpenBao](integrations/openbao/index.md)
- [CyberArk Conjur](integrations/conjur/index.md)
- [AWS Secrets Manager](integrations/aws/index.md)
- [Azure Key Vault](integrations/azure/index.md)
- [GCP Secret Manager](integrations/gcp/index.md)

**Frequently asked questions:**

- [Does Reloader cause downtime?](about/faq.md#does-reloader-cause-downtime)
- [Does it work with StatefulSets?](about/faq.md#does-reloader-work-with-statefulsets)
- [What happens if Reloader is down?](about/faq.md#what-happens-if-reloader-is-down-when-a-configmap-or-secret-changes)
