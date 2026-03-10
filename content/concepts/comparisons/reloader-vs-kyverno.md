# Reloader vs Kyverno

Both Reloader and Kyverno can be involved in restarting Kubernetes workloads when configuration changes.

However, they are designed for **different primary purposes** within a Kubernetes platform.

Understanding how they differ helps platform teams choose the right tool for configuration management and policy enforcement.

---

## What Kyverno Is

Kyverno is a Kubernetes-native policy engine that allows platform teams to define and enforce policies across their clusters.

Kyverno policies can:

* validate Kubernetes resources
* mutate resources during admission
* generate additional resources automatically
* enforce security and compliance standards

Typical Kyverno use cases include:

* enforcing security policies
* requiring labels and annotations
* blocking privileged containers
* enforcing resource limits
* generating default configurations

Kyverno operates primarily during **admission time**, when resources are created or updated.

---

## What Reloader Is

Reloader is a Kubernetes controller designed to ensure applications pick up configuration changes stored in:

* ConfigMaps
* Secrets

When these resources change, Reloader automatically triggers rolling restarts of workloads that reference them.

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

This ensures running applications reload updated configuration or credentials without requiring manual intervention.

---

## Can Kyverno Trigger Pod Restarts?

Yes.

Kyverno can be configured to trigger restarts using mutation policies. For example, when a ConfigMap or Secret changes, Kyverno can update an annotation on a Deployment. Since the Deployment specification changes, Kubernetes performs a rolling restart.

Conceptual example:

```bash
ConfigMap updated
↓
Kyverno mutation policy updates Deployment annotation
↓
Deployment spec changes
↓
Pods restart
```

This means Kyverno can technically be used to implement configuration reload patterns.

However, this typically requires writing and maintaining custom policies.

---

## External Secret Management

Many Kubernetes platforms use external secret management systems.

Examples include:

* secret synchronization operators
* certificate automation systems
* Vault integrations

When these systems update Kubernetes Secret resources, both Kyverno and Reloader can react to those updates.

However, neither tool can detect changes that occur **outside the Kubernetes API**. For example, if an application reads secrets directly from an external system without updating a Kubernetes Secret object, neither Kyverno nor Reloader will detect that change.

---

## Key Differences

While Kyverno can be used to trigger restarts, it is primarily designed for policy enforcement rather than configuration reload automation.

| Aspect | Reloader | Kyverno |
|------|------|------|
|Primary purpose | Configuration reload automation | Policy enforcement and governance |
|Architecture | Dedicated controller watching Secrets and ConfigMaps | Policy engine evaluating resources |
|Typical scope | Configuration management | Security, compliance, governance |
|Operational complexity | Simple install and configuration | Requires policy design and maintenance |

Reloader focuses specifically on ensuring applications reload configuration when it changes.

Kyverno focuses on enforcing governance and compliance policies across Kubernetes clusters.

---

## Operational Considerations

Using Kyverno for reload automation often requires writing custom policies that:

* detect configuration changes
* update workloads safely
* avoid unintended restart loops

This approach can work well for teams already heavily using Kyverno for platform governance.

For teams that only need reliable configuration reload behavior, a dedicated controller may be simpler to operate.

---

## When Kyverno May Be Enough

Using Kyverno to trigger restarts may make sense when:

* Kyverno is already deeply integrated into the platform
* teams want to manage all cluster behavior through policies
* configuration reload logic is relatively simple

In these environments, Kyverno policies can be extended to perform restart automation.

---

## When Reloader Is a Better Fit

Reloader may be a better option when:

* automatic reload behavior is required across many applications
* platform teams want a dedicated solution for configuration changes
* operational simplicity is important
* configuration changes frequently occur through external systems

These environments are common in modern Kubernetes platforms using secret rotation or automated certificate management.

---

## Summary

Kyverno and Reloader solve different platform problems.

Kyverno provides powerful policy enforcement capabilities for Kubernetes clusters.

Reloader focuses specifically on ensuring that applications pick up configuration changes stored in Secrets and ConfigMaps.

Both tools can coexist in the same platform and serve complementary roles.

---

## FAQ

### Can Kyverno restart pods when a ConfigMap changes?

Yes. Kyverno can use mutation policies to update workloads when configuration resources change, which can trigger rolling restarts.

### Is Kyverno a replacement for Reloader?

Not directly. Kyverno is designed as a policy engine, while Reloader focuses specifically on configuration reload automation.

### Can Kyverno and Reloader be used together?

Yes. Many Kubernetes platforms use Kyverno for governance and Reloader for configuration management.
