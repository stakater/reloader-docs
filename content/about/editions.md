# Reloader OSS vs Enterprise

Reloader is available in two editions: **Reloader OSS** and **Reloader Enterprise**.

Both editions share the same annotation-driven reload model and work with any Kubernetes-native secret or configuration delivery mechanism — External Secrets Operator, Secrets Store CSI Driver, Vault Agent, or plain ConfigMaps and Secrets.

The difference is what surrounds the core: hardened images, validated integrations, long-term maintenance, and commercial support.

---

## Feature comparison

| Capability | Reloader OSS | Reloader Enterprise |
|---|---|---|
| Core reload functionality | ✅ | ✅ |
| Works with ConfigMaps and Secrets | ✅ | ✅ |
| Works with any secret delivery mechanism (ESO, CSI, Vault Agent, etc.) | ✅ | ✅ |
| Supports Deployments, StatefulSets, DaemonSets, Argo Rollouts | ✅ | ✅ |
| OpenShift DeploymentConfig support | ✅ | ✅ |
| Prometheus metrics | ✅ | ✅ |
| Webhook alerting (Slack, Teams, Google Chat) | ✅ | ✅ |
| High-availability mode | ✅ | ✅ |
| Helm chart installation | ✅ | ✅ |
| **Hardened container images** | ❌ | ✅ |
| **UBI (Red Hat Universal Base Image) variant** | ❌ | ✅ |
| **Continuous CVE scanning and image verification** | ❌ | ✅ |
| **Validated Vault integration** | ❌ | ✅ |
| **Validated OpenBao integration** | ❌ | ✅ |
| **Validated Conjur integration** | ❌ | ✅ |
| **Continuous integration testing across supported integrations** | ❌ | ✅ |
| **Upgrade and compatibility guarantees** | ❌ | ✅ |
| **Long-term maintenance and backported fixes** | ❌ | ✅ |
| **Commercial support and SLA** | ❌ | ✅ |
| **Production onboarding and guidance** | ❌ | ✅ |
| **Suitable for regulated and audited environments** | ❌ | ✅ |

---

## Hardened and verified images

Reloader Enterprise images are built through a hardened supply chain and continuously scanned for vulnerabilities.

Enterprise images are available in two variants:

| Variant | Image |
|---|---|
| Standard | `ghcr.io/stakater/reloader-enterprise:<version>` |
| UBI (Red Hat Universal Base Image) | `ghcr.io/stakater/reloader-enterprise:<version>-ubi` |

The UBI variant is required in environments that mandate FIPS-compliant or Red Hat certified base images — common in regulated industries and OpenShift environments.

OSS images are built from upstream community infrastructure and are not covered by an SLA or hardening process.

---

## Validated integrations

Reloader Enterprise includes continuously validated integrations with:

- **HashiCorp Vault** — via External Secrets Operator, Vault Secrets Operator, and CSI Driver
- **OpenBao** — via External Secrets Operator, OpenBao Secrets Operator, and CSI Driver
- **CyberArk Conjur** — via External Secrets Operator, Sidecar, and CSI Driver

Validated means these integrations are tested end-to-end in CI on every release of Reloader Enterprise. You can rely on them working across version upgrades.

Community integrations (AWS Secrets Manager, GCP Secret Manager, Azure Key Vault, Infisical, Doppler, and others) are supported by the broader community and work with both editions. They are not covered by Reloader Enterprise's SLA.

---

## Long-term maintenance

Reloader Enterprise follows a defined release and support lifecycle:

- **Upgrade guarantees** — breaking changes are communicated in advance with migration guidance
- **Backported fixes** — security and critical bug fixes are backported to supported versions, not only the latest
- **Compatibility matrix** — tested Kubernetes version ranges are published for each Enterprise release

OSS follows a rolling release model; older versions receive no formal backport commitment.

---

## When to use Reloader OSS

Reloader OSS is a good fit for:

- Development and staging environments
- Teams evaluating Reloader before a production rollout
- Environments with no formal compliance or audit requirements
- Organisations comfortable with self-managing the supply chain and integration testing

Reloader OSS is installed from the [public Stakater Helm chart](https://stakater.github.io/stakater-charts).

---

## When to use Reloader Enterprise

Reloader Enterprise is the right choice when:

- **Regulated environments** — your environment is subject to SOC 2, PCI DSS, HIPAA, FedRAMP, or similar compliance frameworks that require verified software supply chains and SLA-backed support
- **Security-critical workloads** — secrets management is a security control, and the tooling surrounding it must meet the same standards
- **Platform teams at scale** — you are running Reloader across many clusters or namespaces and need guaranteed behaviour across upgrades
- **OpenShift deployments** — the UBI image variant is required for Red Hat certified workloads
- **Production SLA requirements** — incidents affecting configuration propagation need a commercial support path

---

## Getting Reloader Enterprise

Reloader Enterprise requires an active subscription. Access is granted by Stakater.

Once access is granted, you can install via the standard OSS Helm chart with the Enterprise image override. See the [installation guide](../installation/install.md) for the complete procedure.

To get access, open a ticket at [support.stakater.com](https://support.stakater.com/) or contact your Stakater account representative.
