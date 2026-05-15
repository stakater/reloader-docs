# Monitor Reloader

Reloader exposes a Prometheus-compatible metrics endpoint and structured logs, giving platform teams visibility into reload activity, failure rates, and operational health.

---

## Metrics endpoint

Reloader exposes metrics at `/metrics` on **port `9090`**.

To inspect metrics manually:

```bash
kubectl port-forward -n reloader svc/reloader 9090:9090
curl -s http://localhost:9090/metrics | grep reloader_
```

---

## Available metrics

### `reloader_reload_executed_total`

Counts every reload Reloader has attempted, labelled by success or failure.

```text
reloader_reload_executed_total{success="true"}    # successful reloads
reloader_reload_executed_total{success="false"}   # failed reloads
```

This is the primary operational metric. A non-zero `success="false"` count indicates that Reloader is detecting changes but failing to patch the workload — usually an RBAC problem.

### `reloader_reload_executed_total_by_namespace`

The same counter broken down by namespace. **Disabled by default** because it has unbounded cardinality in large clusters.

Enable via Helm:

```yaml
reloader:
  enableMetricsByNamespace: true
```

Or via environment variable on the Reloader container:

```yaml
reloader:
  deployment:
    env:
      field:
        METRICS_COUNT_BY_NAMESPACE: enabled
```

When enabled:

```text
reloader_reload_executed_total_by_namespace{success="true",  namespace="production"}   12
reloader_reload_executed_total_by_namespace{success="false", namespace="staging"}       1
```

---

## Scraping metrics with Prometheus Operator

If you use the Prometheus Operator (`kube-prometheus-stack` or similar), enable the built-in `PodMonitor`:

```yaml
reloader:
  podMonitor:
    enabled: true
```

This creates a `PodMonitor` resource in the same namespace as Reloader. Prometheus Operator will discover it automatically if your Prometheus instance watches `PodMonitor` resources cluster-wide.

To verify the monitor was created:

```bash
kubectl get podmonitor -n reloader
```

To confirm Prometheus is scraping it, open the Prometheus targets page (`/targets`) and search for `reloader`.

---

## Scraping metrics without Prometheus Operator

If you manage Prometheus configuration directly (without Prometheus Operator), add a scrape job to your Prometheus config:

```yaml
scrape_configs:
  - job_name: reloader
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - reloader
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        regex: reloader
        action: keep
      - source_labels: [__address__]
        regex: (.+):\d+
        replacement: $1:9090
        target_label: __address__
```

---

## Example Grafana queries

Use these PromQL queries as the basis for Grafana panels.

### Total successful reloads (all time)

```promql
sum(reloader_reload_executed_total{success="true"})
```

### Reload rate (per minute, 5m window)

```promql
sum(rate(reloader_reload_executed_total{success="true"}[5m])) * 60
```

### Failed reload rate (alert candidate)

```promql
sum(rate(reloader_reload_executed_total{success="false"}[5m])) * 60
```

### Reloads by namespace (requires `enableMetricsByNamespace: true`)

```promql
sort_desc(
  sum by (namespace) (
    increase(reloader_reload_executed_total_by_namespace{success="true"}[1h])
  )
)
```

---

## Example Prometheus alerting rules

Save as a `PrometheusRule` resource or add to your Prometheus rules file.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: reloader-alerts
  namespace: reloader
spec:
  groups:
    - name: reloader
      rules:
        - alert: ReloaderFailingToRestart
          expr: |
            increase(reloader_reload_executed_total{success="false"}[5m]) > 0
          for: 2m
          labels:
            severity: warning
          annotations:
            summary: "Reloader is failing to restart workloads"
            description: >
              Reloader detected a ConfigMap or Secret change but failed to
              patch the workload. This is usually an RBAC issue.
              Check Reloader logs: kubectl logs -n reloader -l app=reloader

        - alert: ReloaderDown
          expr: |
            absent(up{job="reloader"} == 1)
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Reloader is not running"
            description: >
              No Reloader pod is reachable. Configuration changes will not
              trigger workload restarts until Reloader is healthy.
```

---

## Structured logs

Reloader emits structured logs for every reload event and error.

### Enable JSON logging

```yaml
reloader:
  logFormat: json
```

JSON logs are easier to ingest into Loki, Elasticsearch, or CloudWatch.

### Log levels

```yaml
reloader:
  logLevel: info   # trace | debug | info | warning | error | fatal | panic
```

### Key log events to watch

| Event | What it means |
|---|---|
| `Changes detected in '<name>' of type 'SECRET'` | Reloader detected a data change in a Secret |
| `Changes detected in '<name>' of type 'CONFIGMAP'` | Reloader detected a data change in a ConfigMap |
| `Updated '<workload>' of type 'Deployment'` | Reloader successfully patched a workload |
| `failed to update deployment` | Reloader could not patch the workload — check RBAC |
| `unable to create Kubernetes client` | Reloader cannot reach the API server |

### Query logs with kubectl

```bash
# Watch live reload events
kubectl logs -n reloader -l app=reloader -f | grep -E "Changes detected|Updated"

# Show only errors
kubectl logs -n reloader -l app=reloader | grep -i "error\|failed"
```

### Query logs with Loki / LogQL (if using Grafana)

```logql
{namespace="reloader"} |= "Changes detected"
```

```logql
{namespace="reloader"} |= "failed"
```

---

## Webhook notifications

In addition to metrics and logs, Reloader can send a webhook notification to Slack, Microsoft Teams, Google Chat, or any https endpoint whenever a reload is triggered.

See [Alert When Reloader Triggers a Restart](alerting-on-reload.md) for setup instructions.
