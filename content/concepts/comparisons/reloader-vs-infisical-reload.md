# Reloader vs Infisical Built-In Reload

The Infisical Kubernetes operator includes a built-in auto-reload feature. When a managed Kubernetes Secret is updated by the operator, it can automatically restart workloads that carry the annotation `secrets.infisical.com/auto-reload: "true"`.

This page compares that built-in mechanism to using Stakater Reloader for the same job.

---

## What Infisical's built-in reload does

The Infisical operator polls the Infisical API on a configurable `resyncInterval` (default: 1 minute). When it detects a change, it updates the managed Kubernetes Secret. If a Deployment, StatefulSet, or Daemonset carries `secrets.infisical.com/auto-reload: "true"`, the operator triggers a restart on that workload.

```text
Infisical secret changes
↓
Infisical operator syncs Kubernetes Secret (every resyncInterval)
↓
Operator checks for annotated workloads
↓
Operator triggers restart
```

---

## Feature comparison

| Capability | Infisical built-in reload | Reloader |
|---|---|---|
| Deployments | ✅ | ✅ |
| StatefulSets | ✅ | ✅ |
| Daemonsets | ✅ | ✅ |
| Argo Rollouts | ❌ | ✅ (requires `isArgoRollouts: true`) |
| CronJobs | ❌ Not documented | ✅ |
| Watches ConfigMaps | ❌ Secrets only | ✅ |
| Works with non-Infisical secrets (ESO, CSI, plain Secrets) | ❌ Infisical-managed Secrets only | ✅ Any Kubernetes Secret or ConfigMap |
| Named-resource reload annotation | ❌ | ✅ `secret.reloader.stakater.com/reload` |
| Cooldown between reloads | ❌ | ✅ `pause-period` annotation |
| Namespace scoping | ❌ | ✅ `namespaceSelector`, `ignoreNamespaces` |
| Prometheus metrics | ❌ | ✅ `reloader_reload_executed_total` |
| Webhook alerts (Slack, Teams, Google Chat) | ❌ | ✅ |
| High availability with leader election | ❌ | ✅ |
| Commercial support and SLA | ❌ | ✅ Reloader Enterprise |
| Hardened container images | ❌ | ✅ Reloader Enterprise |

---

## When Infisical's built-in reload is enough

If all of the following are true, the Infisical operator's built-in reload covers your use case without adding Reloader:

- You run only **Deployments, StatefulSets, and Daemonsets** — no Argo Rollouts
- All your secrets come from **Infisical** — you are not mixing in ESO, CSI Driver, or plain ConfigMaps
- You do not need reload metrics, webhook alerts, or cooldown periods
- You have no compliance or SLA requirements for the reload mechanism itself

---

## When to use Reloader instead

**Argo Rollouts** — the Infisical operator does not support them. If any workload in your cluster uses Argo Rollouts, Reloader is required to reload those workloads on secret changes.

**Multiple secret backends** — if the same application consumes secrets from both Infisical and AWS Secrets Manager (via ESO), or Infisical and a plain ConfigMap, you need Reloader. The Infisical operator only watches its own managed Secrets.

**ConfigMap reload** — the Infisical operator does not trigger restarts when ConfigMaps change. Reloader does.

**Granular control** — Reloader's `pause-period`, `search/match` pattern, and namespace scoping give finer control over when and where restarts happen.

**Platform-wide consistency** — if multiple teams in the same cluster use different secret tools, Reloader gives a single reload mechanism that works regardless of how secrets arrive.

**Regulated environments** — Reloader Enterprise provides hardened images, commercial support, and SLA coverage that the Infisical operator does not.

---

## Using both together

You can run both the Infisical operator and Reloader in the same cluster, but do not enable both reload mechanisms on the same workload. If a workload has both `secrets.infisical.com/auto-reload: "true"` and a Reloader annotation, both fire on the same Secret update and the workload restarts twice.

Pick one per workload:

- Use Infisical's built-in reload on workloads where you want operator-managed simplicity and no additional tools
- Use Reloader on workloads that need Argo Rollouts support, multi-backend reload, or Enterprise features

---

## Summary

| Scenario | Recommendation |
|---|---|
| Deployments, StatefulSets, Daemonsets — Infisical only | Either works; Infisical built-in is simpler |
| Argo Rollouts | Reloader required |
| Mixed secret backends (Infisical + ESO, CSI, or plain Secrets) | Reloader |
| ConfigMap reload | Reloader |
| Platform-wide unified reload mechanism | Reloader |
| Regulated environment, SLA, hardened images | Reloader Enterprise |

See the [Infisical Operator Guide](../../integrations/infisical/infisical-operator.md) for the complete setup walkthrough.
