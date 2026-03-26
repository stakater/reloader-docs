# What is Reloader?

> Configuration changes, applied safely — every time.

Reloader ensures that configuration and secret changes in Kubernetes are applied to running workloads in a **safe, automatic, and consistent** way.

In Kubernetes, updating a ConfigMap or Secret does not automatically update running Pods. Without additional controls, this often leads to manual restarts, stale configuration, and operational risk.

Reloader closes this gap by observing configuration changes and triggering workload updates based on explicit and predictable rules.

---

## ❤️ Support Reloader

Reloader is used by teams running Kubernetes in production across the world.

If it helps your team:

- ⭐ [Star the project on GitHub](https://github.com/stakater/Reloader)  
- ❤️ [Sponsor ongoing development](https://github.com/sponsors/stakater)  
- 🏢 Need enterprise support or production guidance? 👉 [Talk to the Stakater team](https://www.stakater.com/contact-us)

## Why Reloader Exists

In many Kubernetes environments, configuration changes rely on manual intervention or best-effort operational practices.

Common challenges include:

- Workloads running with outdated configuration or secrets
- Manual restarts causing downtime or errors
- Inconsistent behavior across environments
- Platform teams becoming operational bottlenecks

Reloader was created to make configuration changes **deterministic operational events**, rather than ad-hoc procedures.

## Reloader’s Operational Model

Reloader introduces a consistent operational model for handling configuration and secret changes in Kubernetes.

At a high level:

1. Configuration or secrets are updated
1. Reloader detects the change
1. A controlled workload update is triggered
1. The updated configuration is applied at runtime

This model ensures that approved configuration changes are actually reflected in running workloads, without requiring application changes or manual intervention.

### Deterministic Change Propagation

Reloader ensures that configuration changes are not silently ignored. Once a change is detected, the corresponding workload update follows a predictable and observable path.

### Reduced Operational Risk

By removing ad-hoc restarts and manual procedures, Reloader reduces human error and improves platform reliability.

---

## 🚀 Running Reloader in Production?

Reloader is often used in environments where reliability and consistency matter.

If you're deploying it at scale:

- Get guidance from the team behind it  
- Explore enterprise-grade support  
- Or run it as part of a managed Kubernetes platform  

👉 [Talk to Stakater](https://www.stakater.com/contact-us)  
👉 [Explore Stakater Cloud](https://www.stakater.cloud)  
