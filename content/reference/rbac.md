# RBAC and Security Reference

This page documents the exact Kubernetes permissions Reloader requires, the pod security context it runs with, and the options available for hardening the deployment.

All information on this page is derived from the [Reloader Helm chart](https://github.com/stakater/Reloader/tree/master/deployments/kubernetes).

---

## How RBAC is provisioned

The Helm chart creates RBAC resources automatically. The type depends on `reloader.watchGlobally`:

| `watchGlobally` | RBAC resources created |
|---|---|
| `true` (default) | `ClusterRole` + `ClusterRoleBinding` |
| `false` | `Role` + `RoleBinding` (scoped to the deployment namespace) |

RBAC creation is controlled by `reloader.rbac.enabled` (default: `true`). To bring your own RBAC and skip chart-managed resources, set it to `false` — but you must then create the Role/ClusterRole manually using the rules below.

---

## ClusterRole rules (default mode)

These are the exact rules the chart creates when `watchGlobally: true`.

### Core resources (read)

```yaml
- apiGroups: [""]
  resources: ["secrets", "configmaps"]
  verbs: ["list", "get", "watch"]
```

Reloader watches Secrets and ConfigMaps for data changes. These are read-only permissions.

- The `secrets` rule is **omitted** when `reloader.ignoreSecrets: true`.
- The `configmaps` rule is **omitted** when `reloader.ignoreConfigMaps: true`.

### Namespaces (read) — only when `namespaceSelector` is set

```yaml
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "watch"]
```

Required so Reloader can evaluate namespace labels when filtering with `namespaceSelector`. Not added to the ClusterRole when `namespaceSelector` is unset.

### Workloads (patch)

```yaml
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "statefulsets"]
  verbs: ["list", "get", "update", "patch"]

- apiGroups: ["extensions"]
  resources: ["deployments", "daemonsets"]
  verbs: ["list", "get", "update", "patch"]
```

Reloader patches the pod template of matching workloads to trigger a rolling restart. The `extensions` rules are retained for compatibility with older Kubernetes versions where these resources existed under the `extensions` API group.

### CronJobs and Jobs

```yaml
- apiGroups: ["batch"]
  resources: ["cronjobs"]
  verbs: ["list", "get"]

- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["create"]
```

`list`/`get` on CronJobs allows Reloader to find and evaluate CronJob workloads. `create` on Jobs is required for the CronJob restart mechanism.

### Leader election — only when `enableHA: true`

```yaml
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["create", "get", "update"]
```

Required when running multiple replicas with HA mode. The active leader holds a Lease; standby replicas poll it. Not added to the ClusterRole when `enableHA: false`.

### Events

```yaml
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "patch"]
```

Reloader emits Kubernetes Events when it triggers a restart. These appear in `kubectl describe` output for the workload.

### Argo Rollouts — only when `isArgoRollouts: true`

```yaml
- apiGroups: ["argoproj.io"]
  resources: ["rollouts"]
  verbs: ["list", "get", "update", "patch"]
```

Only added when `isArgoRollouts: true` **and** the Argo Rollouts CRD (`argoproj.io/v1alpha1`) is detected in the cluster.

### OpenShift DeploymentConfigs — only when `isOpenshift: true`

```yaml
- apiGroups: ["apps.openshift.io"]
  resources: ["deploymentconfigs"]
  verbs: ["list", "get", "update", "patch"]
```

Only added when `isOpenshift: true` **and** the OpenShift API (`apps.openshift.io/v1`) is detected.

---

## Role rules (namespace-scoped mode)

When `watchGlobally: false`, the chart creates a `Role` in the deployment namespace instead of a `ClusterRole`. The rules are identical to the ClusterRole above, **except**:

- The `namespaces` rule is **never added** (not applicable to a Role).

This mode restricts Reloader to watching only the namespace it is deployed in.

---

## Disabling RBAC creation

If your organisation manages RBAC outside of Helm (for example via OPA/Gatekeeper, a centralised RBAC controller, or a GitOps pipeline), disable chart-managed RBAC:

```yaml
reloader:
  rbac:
    enabled: false
```

You must then create the Role or ClusterRole manually with the rules listed above, and bind it to the ServiceAccount Reloader uses.

---

## ServiceAccount

The chart creates a `ServiceAccount` in the deployment namespace by default.

```yaml
reloader:
  serviceAccount:
    create: true
    name: ""           # auto-generated if empty
    annotations: {}    # use for IRSA, Workload Identity, etc.
```

To disable ServiceAccount creation and supply your own:

```yaml
reloader:
  serviceAccount:
    create: false
    name: my-existing-sa
```

To control whether the token is auto-mounted:

```yaml
reloader:
  deployment:
    automountServiceAccountToken: false
```

---

## Pod security context

The chart sets the following pod-level security context by default:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65534
  seccompProfile:
    type: RuntimeDefault
```

- `runAsNonRoot: true` — the container must not run as root; Kubernetes enforces this.
- `runAsUser: 65534` — the `nobody` user; no special privileges.
- `seccompProfile: RuntimeDefault` — uses the node's default seccomp profile, which restricts syscalls to the safe default set.

On OpenShift 4.13.3 and later, the platform assigns UIDs dynamically. Set `runAsUser` to null to allow this:

```yaml
reloader:
  deployment:
    securityContext:
      runAsUser: null
      runAsNonRoot: true
      seccompProfile:
        type: RuntimeDefault
```

---

## Container security context

The container-level security context is empty by default. To harden it:

```yaml
reloader:
  deployment:
    containerSecurityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
          - ALL
      readOnlyRootFilesystem: true
```

`readOnlyRootFilesystem: true` can also be set via the top-level shorthand:

```yaml
reloader:
  readOnlyRootFileSystem: true
```

When `readOnlyRootFileSystem: true` is set (either way), the chart automatically mounts an `emptyDir` volume at `/tmp/` so Reloader can write temporary files.

---

## Network policy

The chart includes an optional `NetworkPolicy` that restricts ingress and egress for the Reloader pod. Disabled by default.

```yaml
reloader:
  netpol:
    enabled: true
```

When enabled, the policy allows:

- **Ingress** on port `9090` — for Prometheus metrics scraping
- **Egress** on port `443` — to reach the Kubernetes API server (HTTPS)

You can further restrict the ingress source with `netpol.from` and the egress destination with `netpol.to`:

```yaml
reloader:
  netpol:
    enabled: true
    from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: monitoring
    to:
      - ipBlock:
          cidr: 10.96.0.1/32   # cluster API server IP
```

---

## Verifying RBAC in a running cluster

Check what ClusterRole or Role was created:

```bash
# Global mode
kubectl get clusterrole -l app=reloader-reloader
kubectl describe clusterrole reloader-reloader-role

# Namespace-scoped mode
kubectl get role -n reloader -l app=reloader-reloader
kubectl describe role reloader-reloader-role -n reloader
```

Check the binding:

```bash
kubectl get clusterrolebinding -l app=reloader-reloader
kubectl describe clusterrolebinding reloader-reloader-role-binding
```

Confirm the ServiceAccount:

```bash
kubectl get serviceaccount -n reloader
```

If Reloader logs show `failed to update deployment`, check that its ServiceAccount has `update` and `patch` on `apps/deployments`:

```bash
kubectl auth can-i patch deployments \
  --as=system:serviceaccount:reloader:reloader-reloader \
  --all-namespaces
```
