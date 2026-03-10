# Reloader vs Helm

Many Kubernetes users assume that Helm already solves the problem of restarting workloads when configuration changes.

This is a common misconception.

Helm and Reloader solve **different problems in the Kubernetes lifecycle**.

Understanding this difference is essential when designing reliable configuration management in Kubernetes.

---

## What Helm Does

Helm is a package manager for Kubernetes.

Helm is responsible for:

* Installing applications
* Managing application versions
* Rendering templates
* Applying manifests to the cluster

Helm operates during **deployment time**.

Typical Helm workflow:

```bash
Developer updates Helm values
↓
Helm upgrade runs
↓
Kubernetes resources updated
↓
Pods roll out
```

Helm only affects workloads **when Helm itself runs**.

If a ConfigMap or Secret changes outside of Helm, Helm does **nothing**.

---

## What Reloader Does

Reloader is a Kubernetes controller that watches for changes in:

* ConfigMaps
* Secrets

When a change is detected, Reloader automatically triggers a rolling restart of workloads that depend on those resources.

Typical workflow:

```bash
Secret updated
↓
Reloader detects change
↓
Deployment patched
↓
Kubernetes rolling restart triggered
```

This ensures applications always run with the **latest configuration**.

---

## Why Helm Alone Is Not Enough

In modern Kubernetes environments, configuration is often updated by external systems such as:

* secret management systems
* certificate rotation tools
* CI/CD pipelines
* GitOps controllers

When these systems update a Secret or ConfigMap, Helm is **not involved**.

That means:

Pods continue running with **stale configuration**.

This is the exact problem Reloader solves.

---

## Common Helm Workaround: Checksum Annotations

Many Helm charts implement a workaround using checksum annotations:

```bash
checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

This forces a Deployment rollout when Helm upgrades run.

However, this approach has several limitations:

* Requires modifying Helm charts
* Only works during Helm upgrades
* Does not react to external secret rotation
* Difficult to standardize across teams
* Adds template complexity

For a deeper comparison, see: [Reloader vs Checksum Annotations](reloader-vs-checksum-annotations.md)

---

## Helm and Reloader Work Best Together

Helm and Reloader are not competitors.

They solve different layers of the Kubernetes platform.

A typical production setup looks like this:

```bash
Helm → installs applications
↓
Secrets / ConfigMaps change
↓
Reloader → triggers pod restart
```

Helm handles **application lifecycle**.

Reloader handles **runtime configuration updates**.

---

## When You Should Use Reloader

Reloader becomes especially useful when using:

* secret rotation systems
* certificate automation
* GitOps workflows
* external secret managers
* dynamic configuration updates

These systems update configuration **without redeploying applications**.

Reloader ensures workloads automatically pick up those changes.

---

## Summary

| Tool | Purpose |
|-----|--------|
| Helm | Deploy and manage applications |
| Reloader | Restart workloads when configuration changes |

Helm manages **application deployment**.

Reloader ensures **configuration changes are safely applied to running workloads**.

Together they form a reliable configuration management workflow in Kubernetes.

---

## FAQ

### Does Helm restart pods when a ConfigMap changes?

No. Helm only triggers rollouts when Helm upgrades run.

### How do you restart pods when a Secret changes in Kubernetes?

You can use a controller like Reloader that watches Secrets and triggers rolling updates automatically.
