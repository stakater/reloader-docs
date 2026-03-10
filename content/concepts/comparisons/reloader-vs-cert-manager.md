# Reloader vs cert-manager

Kubernetes applications often rely on TLS certificates for secure communication. These certificates are usually stored in **Secrets** and mounted into workloads.

When certificates are renewed, Kubernetes updates the Secret containing the new certificate. However, applications using that Secret may continue running with the **old certificate loaded in memory**.

Two tools are often involved in solving different parts of this workflow:

1. **cert-manager**, which issues and renews certificates  
1. **Reloader**, which ensures applications restart when configuration changes

Although they interact with the same Kubernetes resources, they serve **different roles in the platform**.

---

## The Certificate Rotation Problem

TLS certificates expire and must be renewed periodically.

Tools such as cert-manager automate certificate issuance and renewal, updating the corresponding Kubernetes Secret when a new certificate is available.

Example:

```bash
Certificate nearing expiry
↓
cert-manager renews certificate
↓
TLS Secret updated
```

However, most applications **do not automatically reload certificates** when the Secret changes.

Example:

```bash
TLS Secret updated
↓
Application pods still running
↓
Application continues using old certificate
```

This can lead to situations where applications keep using outdated certificates until they are restarted.

---

## What cert-manager Does

cert-manager is a Kubernetes controller that automates certificate management.

It can:

* issue TLS certificates
* renew certificates automatically
* integrate with certificate authorities
* store certificates in Kubernetes Secrets

Typical workflow:

```bash
Certificate resource created
↓
cert-manager requests certificate
↓
Certificate issued
↓
Secret containing certificate created
```

Later, when the certificate approaches expiration:

```bash
Certificate renewal triggered
↓
cert-manager obtains new certificate
↓
Secret updated with new certificate
```

cert-manager focuses on **certificate lifecycle management**.

---

## What Happens After Certificate Renewal

When cert-manager updates a TLS Secret, the Secret resource changes but application pods usually **continue running without restarting**.

Example:

```bash
cert-manager renews certificate
↓
Secret updated
↓
Pods still running
↓
Application continues using old certificate
```

Unless the application supports dynamic certificate reload, the new certificate will not be used until the pod restarts.

---

## How Reloader Works

Reloader is a Kubernetes controller that watches for changes in:

* ConfigMaps
* Secrets

When one of these resources changes, Reloader automatically triggers a rolling restart of workloads that reference them.

Example workflow:

```bash
cert-manager renews certificate
↓
TLS Secret updated
↓
Reloader detects change
↓
Deployment patched
↓
Kubernetes rolling restart triggered
```

This ensures applications restart and load the new certificate.

---

## Key Differences

| Aspect            | Reloader                                     | cert-manager                    |
| ----------------- | -------------------------------------------- | ------------------------------- |
| Primary purpose   | Restart workloads when configuration changes | Manage TLS certificates         |
| Trigger mechanism | Secret or ConfigMap updates                  | Certificate issuance or renewal |
| Scope             | Application runtime behavior                 | Certificate lifecycle           |
| Operational role  | Configuration reload automation              | Certificate management          |

cert-manager ensures **certificates are issued and renewed**, while Reloader ensures **applications reload them when they change**.

---

## Using Reloader with cert-manager

Reloader and cert-manager are often used together.

Typical workflow:

```bash
Certificate issued or renewed
↓
cert-manager updates TLS Secret
↓
Reloader detects Secret change
↓
Workloads restart automatically
↓
Applications load new certificate
```

This combination helps ensure applications always run with valid certificates.

---

## When cert-manager Alone Is Enough

cert-manager alone may be sufficient when:

* applications support dynamic certificate reload
* workloads monitor certificate files themselves
* restarts are handled manually

Some web servers and proxies can reload certificates without restarting.

---

## When Reloader Becomes Useful

Reloader becomes useful when:

* applications require a restart to load new certificates
* certificate rotation happens automatically
* multiple workloads depend on the same TLS Secret
* platform teams want reliable automation

These situations are common in production Kubernetes environments.

---

## Summary

cert-manager and Reloader solve different parts of the certificate management workflow.

cert-manager automates certificate issuance and renewal.

Reloader ensures applications restart when the certificate Secret changes.

Using both together provides a reliable way to ensure applications always run with the latest TLS certificates.

---

## FAQ

### Does cert-manager restart pods when certificates renew?

No. cert-manager updates the TLS Secret but typically does not restart workloads using that Secret.

### Can Reloader detect certificate updates?

Yes. Reloader detects changes to Secrets, including TLS Secrets updated during certificate renewal.

### Can cert-manager and Reloader be used together?

Yes. Many Kubernetes platforms use cert-manager for certificate management and Reloader to ensure workloads reload new certificates automatically.
