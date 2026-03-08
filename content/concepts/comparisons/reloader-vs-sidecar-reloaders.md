# Reloader vs Sidecar Reloaders

In Kubernetes, applications often rely on configuration stored in **ConfigMaps** and **Secrets**.

When those resources change, running pods do not automatically reload the updated values. This creates a common challenge for platform teams: ensuring applications pick up configuration updates without requiring manual restarts.

Two common approaches are used to address this problem:

1. Sidecar reloaders
1. A cluster-level controller such as Reloader

Both approaches can work, but they operate at different levels of the Kubernetes platform.

---

## The Configuration Reload Problem

In Kubernetes, updating a ConfigMap or Secret does **not automatically restart pods**.

Example:

```bash
ConfigMap updated
↓
Pods continue running
↓
Application still uses old configuration
```

This behavior is intentional. Kubernetes only triggers a rollout when the **Pod specification changes**, not when referenced resources change.

Because of this, platforms need mechanisms to ensure applications pick up configuration updates.

---

## What Sidecar Reloaders Are

Sidecar reloaders are additional containers that run inside the same pod as the application.

Their job is to monitor configuration files mounted from ConfigMaps or Secrets and notify the application when those files change.

Typical workflow:

```bash
ConfigMap updated
↓
Kubernetes updates mounted files
↓
Sidecar detects file change
↓
Sidecar signals application to reload configuration
```

Some applications support configuration reload through signals such as:

* SIGHUP
* HTTP reload endpoints
* custom reload commands

Sidecar reloaders are commonly used with applications that support **live configuration reload**.

---

## Advantages of Sidecar Reloaders

Sidecar reloaders can be useful in several scenarios.

### Works Without Restarting Pods

Some applications can reload configuration dynamically without restarting.

Sidecars allow these applications to pick up changes without triggering a rolling restart.

### Application-Specific Reload Logic

Sidecars can trigger custom reload mechanisms supported by the application, such as sending signals or calling reload endpoints.

### No Cluster-Level Controller Required

Sidecar reloaders operate entirely within the pod and do not require additional controllers installed in the cluster.

---

## Limitations of Sidecar Reloaders

Sidecar reloaders also introduce some operational trade-offs.

### Requires Changes to Application Manifests

Every workload must include the sidecar container.

This increases configuration overhead and requires application manifests to be modified.

### Additional Containers Per Pod

Each sidecar adds an extra container to the pod, increasing:

* resource usage
* scheduling overhead
* operational complexity

In large clusters, this can result in many additional containers running across workloads.

### Inconsistent Implementation Across Teams

Each application team may implement reload sidecars differently.

This can make it difficult for platform teams to standardize configuration reload behavior across the cluster.

### Not All Applications Support Live Reload

Many applications cannot reload configuration dynamically and still require a restart.

In these cases, sidecar reloaders provide limited value.

---

## How Reloader Works

Reloader is a Kubernetes controller that watches for changes in:

* ConfigMaps
* Secrets

When a change is detected, Reloader automatically triggers a rolling restart of workloads that reference those resources.

Typical workflow:

```bash
Secret or ConfigMap updated
↓
Reloader detects change
↓
Deployment patched
↓
Kubernetes rolling restart triggered
```

This ensures applications restart and load the updated configuration.

---

## Key Differences

| Aspect | Reloader | Sidecar Reloaders |
|------|------|------|
|Architecture | Cluster-level controller | Pod-level container |
|Configuration | Installed once per cluster | Added to every workload |
|Pod restart required | Yes | Not always |
|Operational complexity | Centralized | Distributed across applications |
|Resource overhead | Minimal | Additional container per pod |

Sidecar reloaders focus on **application-level reload behavior**, while Reloader provides **cluster-wide configuration change handling**.

---

## When Sidecar Reloaders Make Sense

Sidecar reloaders may be appropriate when:

* applications support dynamic configuration reload
* restarting pods would disrupt workloads
* teams want application-specific reload mechanisms

Some monitoring systems and web servers use this pattern successfully.

---

## When Reloader Is a Better Fit

Reloader may be preferable when:

* workloads require restarts to pick up configuration changes
* platform teams want standardized behavior across clusters
* minimizing additional containers per pod is important
* configuration changes occur frequently across many applications

These environments are common in modern Kubernetes platforms.

---

## Summary

Sidecar reloaders and Reloader address the same underlying problem: ensuring applications pick up configuration updates.

Sidecar reloaders operate **inside individual pods** and can support applications capable of dynamic configuration reload.

Reloader operates **at the cluster level**, triggering rolling restarts when configuration resources change.

Both approaches can be useful depending on the architecture and operational requirements of the platform.

---

## FAQ

### Do ConfigMap changes automatically restart pods in Kubernetes?

No. Kubernetes does not automatically restart pods when ConfigMaps change.

### Can applications reload configuration without restarting?

Some applications support dynamic configuration reload using signals or reload endpoints. In these cases, sidecar reloaders may be used.

### Can Reloader and sidecar reloaders be used together?

Yes. Some platforms use Reloader for workloads that require restarts and sidecar reloaders for applications that support dynamic reload.
