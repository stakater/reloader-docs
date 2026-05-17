# Integrations Overview

Reloader integrates with a wide range of Kubernetes-native tools for secrets management, certificate automation, and configuration delivery.

This section provides an overview of:

- How integrations work with Reloader
- The different **support and validation levels**
- Which integrations are **validated and supported in Reloader Enterprise**
- What community users can expect

Each integration has its own dedicated section with architecture notes, step-by-step examples, and operational considerations.

All integrations work with both **Reloader OSS** and **Reloader Enterprise**. Enterprise customers receive commercial support and SLA coverage.

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

## Integrations

| Integration | Guides |
|------------|--------|
| [HashiCorp Vault](./vault/index.md) | [ESO](./vault/vault-eso.md), [VSO](./vault/vault-vso.md), [CSI Driver](./vault/vault-csi.md), [CSI Driver (File-Based)](./vault/vault-csi-file.md) |
| [OpenBao](./openbao/index.md) | [ESO](./openbao/openbao-eso.md), [BSO](./openbao/openbao-bso.md), [CSI Driver](./openbao/openbao-csi.md), [CSI Driver (File-Based)](./openbao/openbao-csi-file.md) |
| [Conjur](./conjur/index.md) | [ESO](./conjur/conjur-eso.md), [Sidecar](./conjur/conjur-sidecar.md), [CSI Driver](./conjur/conjur-csi.md) |
| [AWS Secrets Manager](./aws/index.md) | [ESO](./aws/aws-eso.md), [CSI Driver](./aws/aws-csi.md) |
| [GCP Secret Manager](./gcp/index.md) | [ESO](./gcp/gcp-eso.md) |
| [Azure Key Vault](./azure/index.md) | [ESO](./azure/azure-eso.md), [CSI Driver](./azure/azure-csi.md) |
| [Infisical](./infisical/index.md) | [Infisical Operator](./infisical/infisical-operator.md) |
