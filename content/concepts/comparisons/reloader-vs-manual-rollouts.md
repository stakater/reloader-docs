# Reloader vs Manual Rollouts

In Kubernetes, applications often rely on configuration stored in **ConfigMaps** and **Secrets**.

When those resources change, running pods do not automatically reload the updated values. Platform teams therefore need a way to ensure applications pick up configuration updates.

One simple approach is to manually restart workloads. Another approach is to use an automated controller such as **Reloader**.

Both approaches solve the same problem but differ significantly in operational complexity and scalability.

---

## The Configuration Reload Problem

Updating a ConfigMap or Secret in Kubernetes does **not automatically restart pods**.

Example:

```bash
ConfigMap updated
↓
Pods continue running
↓
Application still uses old configuration
```

This happens because Kubernetes only triggers a rollout when the **Pod specification changes**, not when referenced resources change.

Because of this behavior, operators must either manually restart workloads or introduce automation.

---

## Manual Rollouts

A common way to reload configuration is to manually restart workloads.

Example command:

```bash
kubectl rollout restart deployment my-app
```

Typical workflow:

```bash
ConfigMap updated
↓
Operator runs rollout restart
↓
Deployment updated
↓
Pods restart
```

This approach works because restarting pods forces applications to reload configuration.

---

## Advantages of Manual Rollouts

Manual rollouts are simple and require no additional tooling.

### Built Into Kubernetes

The rollout command is part of standard Kubernetes tooling and works with Deployments, StatefulSets, and Daemonsets.

### Useful for Occasional Changes

For small environments or infrequent configuration updates, manually restarting workloads may be sufficient.

### No Additional Controllers Required

Manual restarts do not require installing additional components in the cluster.

---

## Limitations of Manual Rollouts

Manual restarts can become difficult to manage as systems grow.

### Requires Human Intervention

Someone must remember to restart workloads after configuration changes.

In busy environments, this step can easily be missed.

### Operational Overhead

If multiple applications depend on the same configuration resource, each workload may need to be restarted individually.

### Difficult to Scale

In clusters with many applications, manually tracking configuration dependencies and restarting affected workloads becomes operationally expensive.

### Error-Prone

Manual processes increase the risk of mistakes, such as restarting the wrong workloads or forgetting to restart some applications.

---

## How Reloader Works

Reloader is a Kubernetes controller that watches for changes in:

* ConfigMaps
* Secrets

When those resources change, Reloader automatically triggers a rolling restart of workloads that reference them.

Example workflow:

```bash
ConfigMap or Secret updated
↓
Reloader detects change
↓
Deployment patched
↓
Kubernetes rolling restart triggered
```

This ensures applications restart and pick up the latest configuration automatically.

---

## Key Differences

| Aspect                  | Reloader                    | Manual Rollouts                |
| ----------------------- | --------------------------- | ------------------------------ |
| Automation              | Automatic                   | Manual                         |
| Operational effort      | Minimal after installation  | Requires repeated intervention |
| Scalability             | Works across many workloads | Difficult to manage at scale   |
| Risk of missed restarts | Low                         | Higher                         |

Manual rollouts rely on operators to trigger restarts, while Reloader provides **automatic configuration change handling**.

---

## When Manual Rollouts Make Sense

Manual restarts may be appropriate when:

* configuration changes are rare
* clusters are small
* operational simplicity is preferred

In these cases, running a restart command occasionally may be sufficient.

---

## When Reloader Is a Better Fit

Reloader is often a better solution when:

* configuration changes happen frequently
* multiple workloads depend on the same configuration
* teams want reliable automation
* minimizing operational overhead is important

These conditions are common in modern Kubernetes environments.

---

## Summary

Manual rollouts and Reloader both ensure applications pick up configuration updates.

Manual rollouts rely on operators to restart workloads after configuration changes.

Reloader automates this process by watching ConfigMaps and Secrets and triggering rolling restarts when they change.

Automation can help reduce operational overhead and improve reliability as systems scale.

---

## FAQ

### Do ConfigMap changes automatically restart pods in Kubernetes?

No. Updating a ConfigMap does not restart pods automatically.

### How can I restart pods after configuration changes?

You can manually restart workloads using:

```bash
kubectl rollout restart deployment <deployment-name>
```

Alternatively, automation tools like Reloader can trigger rolling restarts automatically when configuration changes.

### Can manual rollouts and Reloader be used together?

Yes. Manual restarts can still be used when needed, even if Reloader is installed.
