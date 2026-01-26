# Integrations Overview

Reloader integrates with a wide range of Kubernetes-native tools for secrets management, certificate automation, and configuration delivery.

This section provides an overview of:

- How integrations work with Reloader
- The different **support and validation levels**
- Which integrations are **validated and supported in Reloader Enterprise**
- What community users can expect

Each integration has its own dedicated section with architecture notes, step-by-step examples, and operational considerations.

---

## How integrations work with Reloader

Reloader itself is **tool-agnostic**.

It watches Kubernetes resources such as:

- `Secrets`
- `ConfigMaps`

When these change, Reloader can trigger safe rollouts of supported workloads (e.g. Deployments, StatefulSets, Rollouts), regardless of **how** those resources were created or updated.

Integrations typically follow this flow:

```bash
External system
↓
Kubernetes Secret / ConfigMap
↓
Reloader detects change
↓
Controlled workload rollout
```

Because the integration point is Kubernetes-native, many tools *can* work with Reloader. The difference lies in **validation, guarantees, and support**.

---

## Support & validation levels

Not all integrations are equal in terms of testing, guarantees, and support.

To set clear expectations, Reloader uses the following support levels.

### 🟢 Validated (Reloader Enterprise)

- Continuously tested in CI
- Documented end-to-end workflows
- Validated across upgrades
- Known edge cases handled
- Covered by commercial support and SLA

### 🟡 Community

- Known to work in practice
- Community-contributed or best-effort docs
- No continuous validation or SLA

### 🔵 Experimental

- Early-stage or limited validation
- Suitable for testing and experimentation
- Behavior may change between releases

These labels are shown clearly on each integration page.

---

## Integrations support matrix

The table below summarizes the current status of supported integrations.

| Integration | Support level |
|------------|---------------|
| HashiCorp Vault | 🟢 Validated (Reloader Enterprise) |
| OpenBao | 🟢 Validated (Reloader Enterprise) |
| Conjur | 🟢 Validated (Reloader Enterprise) |
| External Secrets Operator | 🟡 Community |
| Cert-Manager | 🟡 Community |
| Sealed Secrets | 🟡 Community |
| Secrets Store CSI Driver | 🟡 Community |

> Community usage is possible for most integrations, but **only integrations marked as “Validated” are continuously tested and supported**.

---

## What “validated” means in practice

For integrations marked as **Validated (Reloader Enterprise)**, Stakater continuously verifies:

- Reload behavior under frequent secret rotation
- Compatibility with supported Kubernetes versions
- Interaction with GitOps workflows (e.g. Argo CD)
- Rollout safety and failure handling
- RBAC and security boundaries
- Upgrade and rollback scenarios

This reduces operational risk for platform teams running Reloader in production-critical environments.
