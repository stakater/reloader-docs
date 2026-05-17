# Infisical Integration

This page shows how Reloader works alongside the Infisical Kubernetes operator to trigger rolling restarts when secrets change in Infisical.

## How the integration works

The Infisical Kubernetes operator syncs secrets from the Infisical API into standard Kubernetes `Secret` objects using the `InfisicalSecret` CRD. Reloader watches those Kubernetes Secrets. When the operator updates a Secret after a rotation or a change in Infisical, Reloader detects the data change and triggers a rolling restart of any annotated workloads.

```text
Infisical (cloud or self-hosted)
↓
Infisical Kubernetes operator syncs secret
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
| **Reloader with Infisical operator** | All workload types including Argo Rollouts; consistent reload mechanism across multiple secret backends | [Infisical Operator Guide](infisical-operator.md) |

## Infisical operator's built-in auto-reload

The Infisical operator includes a built-in auto-reload feature. When `secrets.infisical.com/auto-reload: "true"` is set on a Deployment, StatefulSet, or Daemonset, the operator restarts the workload after it updates the managed Kubernetes Secret.

Reloader is the better choice when:

- You use **Argo Rollouts** — the Infisical operator does not support them
- You run **multiple secret backends** (for example, Infisical alongside AWS Secrets Manager via ESO) and want a single consistent reload mechanism
- You need **per-workload cooldowns** (`pause-period`) to prevent rapid successive restarts
- You need **namespace scoping** or **label-based filtering** of which namespaces Reloader watches
- You need **Reloader Enterprise** for hardened images, commercial SLA, or regulated environment requirements

If your workloads are exclusively Deployments, StatefulSets, and Daemonsets and you use only Infisical, the built-in auto-reload is a reasonable alternative. See [Reloader vs Infisical Built-In Reload](../../concepts/comparisons/reloader-vs-infisical-reload.md) for a detailed comparison.

## Guides

- [Reloader with Infisical Operator](infisical-operator.md)
