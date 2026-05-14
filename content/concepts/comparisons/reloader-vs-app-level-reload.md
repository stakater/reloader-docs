# Reloader vs Application-Level Hot-Reload

Applications running in Kubernetes need to pick up configuration and secret changes. There are two fundamentally different approaches to this problem:

1. **Application-level hot-reload** — the application itself watches for changes and reloads its own configuration without restarting
1. **Reloader** — a Kubernetes controller that detects changes and triggers a rolling restart of the workload

Both can work, but they operate under different assumptions, apply to different scenarios, and carry different operational tradeoffs.

---

## What application-level hot-reload means

Application-level hot-reload refers to logic built directly into the application process to detect and apply configuration changes at runtime, without a pod restart.

Common implementations include:

- **File watchers** — libraries such as Go's `fsnotify`, Viper's `WatchConfig()`, Node.js `chokidar`, or Python's `watchdog` that detect changes to mounted config files
- **SIGHUP handlers** — the process catches a Unix signal and re-reads its configuration; used by nginx, HAProxy, and many traditional Unix daemons
- **HTTP refresh endpoints** — an endpoint such as Spring Boot Actuator's `/actuator/refresh` that triggers a configuration reload when called
- **Polling** — the application re-reads configuration from a file or API on a fixed interval

---

## A critical Kubernetes constraint

Before comparing the two approaches, there is a hard platform constraint to understand:

**Kubernetes does not update environment variables in running pods when a ConfigMap or Secret changes.**

Environment variables are set at pod start time. They do not change while the container is running, regardless of what happens to the ConfigMap or Secret they were sourced from.

This means:

- **Env var-based config** → app-level hot-reload cannot help. A pod restart is the only way to pick up the new value.
- **File-mounted config** → Kubernetes does update mounted ConfigMap and Secret volumes in-place, with a delay of up to twice the kubelet sync period (the default is 60 seconds). An app with file-watching logic can pick up these changes without a restart.

Most 12-factor applications and containerised workloads read configuration from environment variables. For those, app-level hot-reload is not an option regardless of how it is implemented.

---

## How app-level hot-reload works in Kubernetes

For file-mounted configuration, the flow looks like this:

```
ConfigMap or Secret updated
↓
Kubernetes updates the mounted volume files
(delay: up to 2× kubelet sync period, default ~60s)
↓
App's file watcher detects the change
↓
App re-reads and applies new configuration
↓
Running process continues — no restart
```

This is genuinely zero-downtime: existing connections, in-flight requests, and process state are all preserved.

---

## How Reloader works

Reloader is a Kubernetes controller that watches ConfigMaps and Secrets for data changes. When a change is detected, it patches the workload's pod template. Kubernetes then performs a rolling restart according to the workload's own `RollingUpdate` strategy.

```
ConfigMap or Secret updated
↓
Reloader detects the data change
↓
Reloader patches the pod template
↓
Kubernetes rolling restart
↓
New pods start with updated configuration
```

Reloader works for both env var-based and file-based configuration, and requires no changes to the application.

---

## Comparison

| Aspect | App-Level Hot-Reload | Reloader |
|---|---|---|
| Works with env var config | ❌ No — env vars cannot change in a running pod | ✅ Yes — pod restart picks up new env vars |
| Works with file-mounted config | ✅ Yes | ✅ Yes |
| Pod restart required | ❌ No | ✅ Yes (rolling restart) |
| True zero-downtime | ✅ Yes | Depends on replica count and `maxUnavailable` |
| Requires changes to application code | ✅ Yes | ❌ No |
| Works with third-party or legacy apps | ❌ No | ✅ Yes |
| Works across all languages and frameworks | ❌ No — per-language implementation | ✅ Yes |
| Platform-wide visibility of reload events | ❌ No | ✅ Yes — logs, metrics, Kubernetes Events |
| Consistent behavior across all workloads | ❌ No — each app implements differently | ✅ Yes |
| Responds to externally rotated secrets (ESO, Vault) | Partially — only if mounted as files | ✅ Yes |
| Clean process state after reload | ❌ No — old state may persist in memory | ✅ Yes — fresh process start |

---

## Limitations of app-level hot-reload

### Only works for file-mounted configuration

App-level hot-reload is limited to configuration delivered as mounted files. It cannot handle environment variable-based configuration, which is the default pattern for most containerised applications.

### Every application must implement it

Each service needs its own reload logic. In a platform with many services across multiple languages and frameworks, this results in:

- inconsistent implementations
- varying levels of testing (reload paths are often less tested than startup paths)
- maintenance overhead for each application team

### Third-party and legacy applications are excluded

If you do not control the application source — a database, a message broker, a commercial tool — you cannot add reload logic. Reloader handles these without any modification.

### Partial reload can leave inconsistent state

When an application hot-reloads, only the parts explicitly wired to the reload path are updated. If a configuration change affects multiple subsystems and one reload step fails, the application may be left in a partially updated state. A pod restart produces a clean process with the full updated configuration applied from the start.

### No platform-level visibility

Each application reloads silently from the platform's perspective. Platform teams have no standard way to know when a reload happened, whether it succeeded, or which configuration changed. Reloader emits Kubernetes Events, structured logs, and Prometheus metrics for every reload it triggers.

### Mounted volume propagation delay

Kubernetes updates mounted ConfigMap and Secret volumes with a delay (up to twice the kubelet sync period). This is typically around 60 seconds but can be longer depending on kubelet configuration. App-level hot-reload is therefore not instantaneous — Reloader's event-driven approach reacts as soon as the watch event arrives, which is typically faster.

---

## When app-level hot-reload makes sense

App-level hot-reload is a valid choice when:

- The application has **long-lived connections** (WebSockets, gRPC streaming) where a pod restart would disrupt active clients and zero-downtime is non-negotiable
- Configuration is **file-based only** and never sourced from environment variables
- The team **controls the application source** and is willing to implement, test, and maintain reload paths
- The configuration changes **very frequently** (such as feature flags or rate limits updated many times per day), and rolling restarts at that frequency would be too slow or too disruptive

---

## When Reloader is the better choice

Reloader is the right choice when:

- Configuration is **sourced from environment variables**, in whole or in part
- The application is **third-party, legacy, or otherwise unmodifiable**
- A **platform team** is responsible for configuration reload behavior across many services and wants consistent, observable behavior without requiring each application team to implement their own logic
- **Secrets are rotated externally** — by ESO, Vault, Conjur, or a cloud secret manager — and the platform needs to ensure workloads pick up the new value reliably
- **Compliance or security requirements** favor a fresh process start on secret rotation, guaranteeing no residual state from the old secret remains in memory

---

## Using both approaches together

Some platforms use both:

- **App-level hot-reload** for high-frequency, low-stakes configuration (feature flags, rate limits) that changes file-mounted values and where zero-downtime matters
- **Reloader** for secrets, env var-based configuration, and all workloads that do not implement reload logic

This combination avoids unnecessary restarts for configuration that changes frequently while ensuring secrets and env var-based config are always applied correctly.

---

## FAQ

### Can my app hot-reload environment variables?

No. Kubernetes sets environment variables when the container starts and does not update them while the container is running. An application cannot observe or respond to changes in the original ConfigMap or Secret that env vars were sourced from. A pod restart is required.

### Does Reloader cause downtime?

Not with multiple replicas and a proper `RollingUpdate` strategy. With `maxUnavailable: 0` and at least two replicas, Reloader triggers a rolling restart where new pods are started before old ones are terminated. Single-replica deployments experience a brief pod replacement gap.

### Can Reloader and app-level hot-reload be used in the same cluster?

Yes. They operate independently. Reloader triggers a restart when it detects a change; if the application also has a file watcher, the file watcher will run during the pod's lifetime but the pod will be replaced by Reloader when a relevant change occurs.
