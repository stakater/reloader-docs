# AWS Secrets Manager Integration

This guide shows how to automatically restart Kubernetes workloads when AWS Secrets Manager secrets change, using External Secrets Operator (ESO) to sync secrets into Kubernetes and Stakater Reloader to trigger rolling restarts.

## Integration Patterns

| Pattern | How Secrets Arrive | Rotation | Reloader Compatibility | Guide |
|---------|-------------------|----------|------------------------|-------|
| **External Secrets Operator** | ESO syncs to K8s Secret | ESO refresh interval | Best fit | [ESO Guide](aws-eso.md) |

## How It Works

```mermaid
sequenceDiagram
    actor Ops as Operator / Rotation Job
    participant SM as AWS Secrets Manager
    participant ESO as External Secrets Operator
    participant K8s as Kubernetes Secret
    participant RL as Reloader
    participant Pod as Application Pod

    Ops->>SM: Rotate secret
    loop Every refreshInterval
        ESO->>SM: GetSecretValue
        SM-->>ESO: Updated secret value
    end
    ESO->>K8s: Update Secret data
    K8s-->>RL: Watch event (Secret changed)
    RL->>Pod: Trigger rolling restart
    Note over Pod: New pod starts with updated secret
```

## Prerequisites

- Kubernetes cluster (v1.19+) — EKS recommended for IRSA, but any cluster works with static credentials
- Helm v3+
- AWS account with Secrets Manager access
- AWS CLI configured locally
- Stakater Reloader installed
- External Secrets Operator installed

## How Reloader Works

1. A secret rotates in AWS Secrets Manager (manually, via Lambda, or by automatic rotation)
1. ESO detects the change on its next refresh cycle and updates the Kubernetes Secret
1. Reloader detects the Kubernetes Secret update and triggers a rolling restart of annotated workloads

### Reloader Annotations

**On Deployment:**

```yaml
metadata:
  annotations:
    reloader.stakater.com/search: "true"
```

**On the Secret (via ExternalSecret template):**

```yaml
metadata:
  annotations:
    reloader.stakater.com/match: "true"
```

## Pattern-Specific Guides

- [External Secrets Operator Pattern](aws-eso.md) — IRSA (recommended) or static credentials
