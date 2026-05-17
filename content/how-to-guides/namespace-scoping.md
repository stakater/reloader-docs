# Scope Reloader to Specific Namespaces

By default Reloader watches every namespace in the cluster. This guide shows how to restrict that scope — to a single namespace, to namespaces matching a label selector, or by excluding specific namespaces — and explains the RBAC implications of each mode.

---

## Default behavior

Out of the box, Reloader runs with `watchGlobally: true`. It uses the Kubernetes watch API to observe `ConfigMaps` and `Secrets` across all namespaces, and patches workloads wherever it finds matching annotations.

This is appropriate for platform-wide deployments where a single Reloader instance serves the whole cluster.

---

## Option 1 — Restrict to the deployment namespace

Set `watchGlobally: false` to limit Reloader to the single namespace it is deployed in.

```yaml
reloader:
  watchGlobally: false
```

What changes:

- Reloader sets the `KUBERNETES_NAMESPACE` environment variable to its own pod namespace.
- It only watches resources and workloads in that namespace.
- The chart creates a **`Role`** and **`RoleBinding`** instead of a `ClusterRole` and `ClusterRoleBinding`.

This is the most restrictive option and the right choice when you want one Reloader instance per team namespace, or when cluster-wide RBAC is not permitted.

```bash
helm install reloader stakater/reloader \
  --namespace my-team \
  --create-namespace \
  --set reloader.watchGlobally=false
```

---

## Option 2 — Watch namespaces matching a label selector

To watch a subset of namespaces rather than all of them, use `namespaceSelector`:

```yaml
reloader:
  namespaceSelector: "environment=production"
```

Reloader passes this value to the `--namespace-selector` flag at startup and evaluates it against namespace labels.

Multiple label requirements can be combined using comma-separated expressions (AND logic):

```yaml
reloader:
  namespaceSelector: "environment=production,team=platform"
```

This configuration still uses `watchGlobally: true` under the hood, so the chart creates a **`ClusterRole`**. The ClusterRole also gains a `namespaces: get, list, watch` rule so Reloader can read namespace labels to evaluate the selector.

Label the namespaces you want Reloader to watch:

```bash
kubectl label namespace production environment=production
kubectl label namespace staging environment=staging
```

With `namespaceSelector: "environment=production"`, only `production` is watched; `staging` is ignored.

---

## Option 3 — Exclude specific namespaces

To watch all namespaces except a named list, use `ignoreNamespaces`:

```yaml
reloader:
  ignoreNamespaces: "kube-system,kube-public,cert-manager"
```

This is a comma-separated list of exact namespace names. Reloader passes it to the `--namespaces-to-ignore` flag.

`ignoreNamespaces` and `namespaceSelector` can be combined. When both are set:

- `namespaceSelector` restricts Reloader to namespaces matching the label selector.
- `ignoreNamespaces` then excludes specific names from that already-filtered set.

---

## Option 4 — Filter by resource labels

`resourceLabelSelector` restricts which `ConfigMaps` and `Secrets` Reloader watches, regardless of namespace scope. Only resources whose labels match the selector can trigger a reload.

```yaml
reloader:
  resourceLabelSelector: "reloader-managed=true"
```

This is orthogonal to namespace filtering — it filters resources, not namespaces.

Use it to limit Reloader's blast radius in clusters where many ConfigMaps and Secrets exist but only a subset should ever trigger a restart.

Label the resources you want Reloader to watch:

```yaml
metadata:
  labels:
    reloader-managed: "true"
```

---

## Interaction between selectors

The selectors narrow scope independently:

| Setting | What it filters |
|---|---|
| `watchGlobally: false` | Only the deployment namespace; uses Role instead of ClusterRole |
| `namespaceSelector` | Namespaces whose labels match the selector |
| `ignoreNamespaces` | Named namespaces excluded from watching |
| `resourceLabelSelector` | ConfigMaps/Secrets whose labels match the selector |

A resource triggers a reload only if it passes **all** active filters. For example, if `namespaceSelector: "team=platform"` is set and a namespace does not have that label, no ConfigMap or Secret in that namespace will ever trigger a reload, regardless of workload annotations.

---

## RBAC implications per mode

| Mode | Role type | `namespaces` rule added |
|---|---|---|
| `watchGlobally: true` (default) | `ClusterRole` + `ClusterRoleBinding` | Only when `namespaceSelector` is set |
| `watchGlobally: false` | `Role` + `RoleBinding` | Never |

See the [RBAC reference](../reference/rbac.md) for the full list of rules in each mode.

---

## Practical patterns

### One Reloader per team namespace

Each team installs their own Reloader instance scoped to their namespace:

```bash
helm install reloader stakater/reloader \
  --namespace team-alpha \
  --set reloader.watchGlobally=false

helm install reloader stakater/reloader \
  --namespace team-beta \
  --set reloader.watchGlobally=false
```

Each instance only needs a `Role` in its own namespace, which is useful when cluster-admin cannot grant `ClusterRole` permissions.

### One Reloader watching production namespaces only

A single Reloader instance watches only namespaces labelled for production:

```bash
kubectl label namespace prod-app-1 environment=production
kubectl label namespace prod-app-2 environment=production

helm install reloader stakater/reloader \
  --namespace reloader \
  --create-namespace \
  --set reloader.namespaceSelector="environment=production"
```

### Cluster-wide with system namespaces excluded

Watch everything except namespaces that should never trigger reloads:

```yaml
reloader:
  ignoreNamespaces: "kube-system,kube-public,kube-node-lease,cert-manager,reloader"
```

---

## Verifying scope in a running cluster

Check which namespace selector and ignore list are active:

```bash
kubectl get deployment -n reloader reloader-reloader -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n'
```

Check whether a specific namespace is being watched:

```bash
kubectl logs -n reloader -l app=reloader | grep -i "namespace"
```

Confirm the RBAC mode:

```bash
# Returns output in global mode
kubectl get clusterrole -l app=reloader-reloader

# Returns output in namespace-scoped mode
kubectl get role -n <deployment-namespace> -l app=reloader-reloader
```
