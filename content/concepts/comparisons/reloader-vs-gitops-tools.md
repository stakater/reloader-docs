# Reloader vs GitOps Tools

Modern Kubernetes platforms often use GitOps tools to manage application deployments and infrastructure configuration.

GitOps controllers such as ArgoCD and Flux continuously reconcile the cluster state with the desired state stored in Git.

However, GitOps tools and Reloader solve **different operational problems** in Kubernetes.

Understanding this distinction helps platform teams design reliable configuration management workflows.

---

## The Configuration Reload Problem

In Kubernetes, updating a **ConfigMap** or **Secret** does **not automatically restart pods**.

Example:

```bash
ConfigMap updated
↓
Pods continue running
↓
Application still uses old configuration
```

This behavior is intentional. Kubernetes only performs a rollout when the **Pod specification changes**, not when referenced configuration resources change.

Because of this, platforms must introduce mechanisms to ensure applications pick up configuration updates.

---

## What GitOps Tools Do

GitOps tools manage Kubernetes resources by reconciling cluster state with the desired configuration stored in Git repositories.

Typical GitOps workflow:

```bash
Developer updates Git repository
↓
GitOps controller detects change
↓
Kubernetes manifests applied
↓
Pods updated if PodSpec changes
```

GitOps controllers focus on:

* continuous deployment
* configuration drift correction
* infrastructure and application lifecycle management
* automated reconciliation of cluster state

GitOps tools operate by comparing **Git state** with **cluster state**.

---

## What Happens When Configuration Changes Outside Git

In many environments, configuration resources such as Secrets or ConfigMaps may be updated by external systems.

Examples include:

* secret synchronization controllers
* certificate management systems
* automation pipelines

Example scenario:

```bash
External system updates Secret
↓
Kubernetes Secret updated
↓
Git repository unchanged
↓
GitOps controller sees no drift
↓
Pods are not restarted
```

Because the Git repository did not change, the GitOps controller does not perform a new rollout.

As a result, applications may continue running with outdated configuration.

---

## How Reloader Works

Reloader is a Kubernetes controller that watches for changes in:

* ConfigMaps
* Secrets

When these resources change, Reloader automatically triggers a rolling restart of workloads that reference them.

Example workflow:

```bash
Secret or ConfigMap updated
↓
Reloader detects change
↓
Deployment patched
↓
Kubernetes rolling restart triggered
```

This ensures applications restart and load the latest configuration.

---

## Key Differences

| Aspect                         | Reloader                        | GitOps Tools                        |
| ------------------------------ | ------------------------------- | ----------------------------------- |
| Primary purpose                | React to configuration changes  | Reconcile cluster state with Git    |
| Trigger mechanism              | ConfigMap or Secret updates     | Git repository changes              |
| Runtime configuration handling | Automatic                       | Not automatic                       |
| Operational scope              | Configuration reload automation | Deployment and lifecycle management |

GitOps tools manage **desired state deployment**, while Reloader ensures **runtime configuration changes propagate to running workloads**.

---

## When GitOps Alone Is Enough

GitOps tools may be sufficient when:

* configuration changes are always committed through Git
* application rollouts always occur through GitOps workflows
* configuration is tightly coupled to application releases

In these environments, updates naturally trigger rollouts through Git changes.

---

## When Reloader Becomes Useful

Reloader becomes particularly useful when:

* Secrets or ConfigMaps are updated dynamically
* external systems synchronize configuration into Kubernetes
* certificate rotation occurs automatically
* configuration changes occur independently of Git deployments

These situations are common in modern Kubernetes platforms.

---

## Using Reloader with GitOps

Reloader and GitOps tools work well together.

A typical platform setup looks like this:

```bash
Git repository updated
↓
GitOps controller deploys application
↓
ConfigMaps or Secrets change later
↓
Reloader detects change
↓
Pods restart automatically
```

GitOps manages **deployment and desired state**, while Reloader ensures **applications react to runtime configuration updates**.

---

## Summary

GitOps tools such as Argo CD and Flux manage Kubernetes deployments by reconciling cluster state with Git repositories.

Reloader focuses on a different operational concern: ensuring applications restart when configuration resources change.

Both approaches address different layers of Kubernetes operations and can complement each other in production environments.

---

## FAQ

### Do GitOps tools restart pods when a ConfigMap changes?

Not automatically. GitOps controllers react to changes in Git repositories, not runtime updates to Kubernetes resources.

### Can Reloader be used together with GitOps tools?

Yes. Many platforms use GitOps tools for deployment and Reloader for automated configuration reloads.

### Do GitOps tools manage Secrets and ConfigMaps?

They can deploy them from Git, but they do not automatically restart workloads when those resources change outside the Git workflow.
