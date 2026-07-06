# Reloader vs Doppler Built-In Reload

The Doppler Kubernetes operator includes a built-in reload feature for `Deployment` resources. When a managed Kubernetes Secret is updated by the operator, it can automatically trigger a rolling restart of Deployments that reference that Secret and carry the `secrets.doppler.com/reload: "true"` annotation.

This page compares that built-in mechanism to using Stakater Reloader for the same job.

> The Doppler documentation explicitly recommends Stakater Reloader for workload types beyond Deployments.

---

## What Doppler's built-in reload does

The Doppler operator polls the Doppler API every 60 seconds (configurable via `spec.resyncSeconds`). When it detects a change, it updates the managed Kubernetes Secret. If a Deployment in the same namespace references that Secret and carries `secrets.doppler.com/reload: "true"` on the pod template, the operator triggers a rolling restart by patching an annotation on the Deployment.

```text
Doppler secret changes
↓
Doppler operator syncs Kubernetes Secret (every resyncSeconds)
↓
Operator checks for annotated Deployments in the same namespace
↓
Operator patches Deployment annotation → rolling restart
```

Three conditions must all be met for the built-in reload to fire:

1. The Deployment is in the **same namespace** as the managed Secret
1. The Deployment has `secrets.doppler.com/reload: "true"` on `spec.template.metadata.annotations`
1. The Deployment references the managed Secret

---

## Feature comparison

| Capability | Doppler built-in reload | Reloader |
|---|---|---|
| Deployments | ✅ | ✅ |
| StatefulSets | ❌ | ✅ |
| Daemonsets | ❌ | ✅ |
| Argo Rollouts | ❌ | ✅ (requires `isArgoRollouts: true`) |
| CronJobs | ❌ Not documented | ✅ |
| Watches ConfigMaps | ❌ Operator does not sync to ConfigMaps | ✅ |
| Works with non-Doppler secrets (ESO, CSI, plain Secrets) | ❌ Doppler-managed Secrets only | ✅ Any Kubernetes Secret or ConfigMap |
| Cross-namespace reload | ❌ Deployment must be in the same namespace as the Secret | ✅ |
| Named-resource reload annotation | ❌ | ✅ `secret.reloader.stakater.com/reload` |
| Cooldown between reloads | ❌ | ✅ `pause-period` annotation |
| Namespace scoping | ❌ | ✅ `namespaceSelector`, `ignoreNamespaces` |
| Prometheus metrics | ❌ | ✅ `reloader_reload_executed_total` |
| Webhook alerts (Slack, Teams, Google Chat) | ❌ | ✅ |
| High availability with leader election | ❌ | ✅ |
| Commercial support and SLA | ❌ | ✅ Reloader Enterprise |
| Hardened container images | ❌ | ✅ Reloader Enterprise |

---

## When Doppler's built-in reload is enough

If all of the following are true, the Doppler operator's built-in reload covers your use case without adding Reloader:

- You run only **Deployments** — no StatefulSets, Daemonsets, or Argo Rollouts
- All secrets come from **Doppler** — you are not mixing in ESO, CSI Driver, plain Secrets, or ConfigMaps
- The Deployment is in the **same namespace** as the managed Secret
- You do not need reload metrics, webhook alerts, or cooldown periods
- You have no compliance or SLA requirements for the reload mechanism itself

---

## When to use Reloader instead

**StatefulSets and Daemonsets** — the Doppler operator explicitly does not support them. If any workload in your cluster is a StatefulSet or Daemonset that consumes Doppler-managed secrets, Reloader is required.

**Argo Rollouts** — not supported by the Doppler operator. Reloader handles Argo Rollouts natively with `isArgoRollouts: true`.

**Cross-namespace secrets** — the Doppler operator's built-in reload only fires when the Deployment and the managed Secret are in the same namespace. Reloader has no such restriction.

**Multiple secret backends** — if the same application consumes secrets from both Doppler and AWS Secrets Manager (via ESO), or Doppler alongside a plain ConfigMap, you need Reloader. The Doppler operator only watches its own managed Secrets.

**ConfigMap reload** — the Doppler operator does not sync to ConfigMaps and does not trigger restarts on ConfigMap changes. Reloader does both.

**Platform-wide consistency** — if multiple teams in the same cluster use different secret tools, Reloader provides a single reload mechanism that works regardless of how secrets arrive.

**Regulated environments** — Reloader Enterprise provides hardened images, commercial support, and SLA coverage that the Doppler operator does not offer.

---

## Using both together

You can run both the Doppler operator and Reloader in the same cluster, but do not enable both reload mechanisms on the same workload. If a Deployment has both `secrets.doppler.com/reload: "true"` and a Reloader annotation, both fire on the same Secret update and the workload restarts twice.

Pick one per workload:

- Use Doppler's built-in reload on Deployments where you want operator-managed simplicity and no additional tools
- Use Reloader on all other workload types, and on any workload that needs cross-namespace support, multi-backend reload, or Enterprise features

---

## Summary

| Scenario | Recommendation |
|---|---|
| Deployments only, Doppler secrets only, same namespace | Either works; Doppler built-in is simpler |
| StatefulSets or Daemonsets | Reloader required |
| Argo Rollouts | Reloader required |
| Cross-namespace secrets | Reloader required |
| Mixed secret backends (Doppler + ESO, CSI, or plain Secrets) | Reloader |
| ConfigMap reload | Reloader |
| Platform-wide unified reload mechanism | Reloader |
| Regulated environment, SLA, hardened images | Reloader Enterprise |

See the [Doppler Operator Guide](../../integrations/doppler/doppler-operator.md) for the complete setup walkthrough.
