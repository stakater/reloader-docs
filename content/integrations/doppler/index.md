# Doppler Integration

This page shows how Reloader works alongside the Doppler Kubernetes operator to trigger rolling restarts when secrets change in Doppler.

## How the integration works

The Doppler Kubernetes operator syncs secrets from Doppler into standard Kubernetes `Secret` objects using the `DopplerSecret` CRD. Reloader watches those Kubernetes Secrets. When the operator updates a Secret after a change in Doppler, Reloader detects the data change and triggers a rolling restart of any annotated workloads.

```text
Doppler (cloud)
↓
Doppler Kubernetes operator syncs secret (every 60s by default)
↓
Kubernetes Secret updated
↓
Reloader detects data change
↓
Rolling restart of annotated workloads
```

## Integration patterns

| Pattern | Use case | Guide |
|---|---|---|
| **Reloader with Doppler operator** | All workload types including StatefulSets, Daemonsets, and Argo Rollouts; ConfigMap reload; consistent reload across multiple secret backends | [Doppler Operator Guide](doppler-operator.md) |

## Doppler operator's built-in reload

The Doppler Kubernetes operator includes a built-in reload feature for `Deployment` resources. When `secrets.doppler.com/reload: "true"` is set on a Deployment's pod template, the operator triggers a rolling restart after it updates the managed Kubernetes Secret.

The Doppler documentation explicitly recommends using Stakater Reloader for workloads beyond Deployments. Reloader is the right choice when:

- You use **StatefulSets, Daemonsets, or Argo Rollouts** — the Doppler operator's built-in reload only supports Deployments
- You need **ConfigMap reload** — the Doppler operator does not sync to ConfigMaps; Reloader watches ConfigMaps
- You run **multiple secret backends** (for example, Doppler alongside AWS Secrets Manager via ESO) and want a single consistent reload mechanism across all of them
- You need **per-workload cooldowns**, namespace scoping, Prometheus metrics, or webhook alerts
- You need **Reloader Enterprise** for hardened images, commercial SLA, or regulated environment requirements

See [Reloader vs Doppler Built-In Reload](../../concepts/comparisons/reloader-vs-doppler-reload.md) for a detailed comparison.

## Guides

- [Reloader with Doppler Operator](doppler-operator.md)
