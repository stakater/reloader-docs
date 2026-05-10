# Alert When Reloader Triggers a Restart

Reloader can send a webhook notification whenever it triggers a rolling restart. This is useful for audit trails, operational visibility, and integrating with incident management workflows.

Alerts are sent to a configured webhook endpoint with details about what changed and which workload was restarted.

---

## Supported sinks

| Sink | Value |
|---|---|
| Raw webhook (default) | `webhook` |
| Slack | `slack` |
| Microsoft Teams | `teams` |
| Google Chat | `gchat` |

---

## Configuration

Alerting is configured through environment variables on the Reloader deployment. The recommended way to set these is through the `reloader.deployment.env.secret` section of the Helm values, so that the webhook URL is stored as a Kubernetes Secret rather than in plaintext.

```yaml
reloader:
  deployment:
    env:
      secret:
        ALERT_ON_RELOAD: "true"
        ALERT_SINK: "slack"
        ALERT_WEBHOOK_URL: "https://hooks.slack.com/services/..."
        ALERT_ADDITIONAL_INFO: "Cluster: production-eu"
```

| Variable | Required | Description |
|---|---|---|
| `ALERT_ON_RELOAD` | Yes | Set to `"true"` to enable alerting. Default: `false` |
| `ALERT_SINK` | No | Sink type: `slack`, `teams`, `gchat`, or `webhook`. Default: `webhook` |
| `ALERT_WEBHOOK_URL` | Yes (when alerting enabled) | The webhook URL to send notifications to |
| `ALERT_ADDITIONAL_INFO` | No | Free-text string appended to the alert payload. Useful for adding context such as cluster name or environment |

---

## Examples

### Slack

Create a Slack Incoming Webhook by following the [Slack documentation](https://api.slack.com/messaging/webhooks), then configure:

```yaml
reloader:
  deployment:
    env:
      secret:
        ALERT_ON_RELOAD: "true"
        ALERT_SINK: "slack"
        ALERT_WEBHOOK_URL: "https://hooks.slack.com/services/<workspace-id>/<channel-id>/<token>"
        ALERT_ADDITIONAL_INFO: "Cluster: production"
```

### Microsoft Teams

```yaml
reloader:
  deployment:
    env:
      secret:
        ALERT_ON_RELOAD: "true"
        ALERT_SINK: "teams"
        ALERT_WEBHOOK_URL: "https://outlook.office.com/webhook/..."
```

### Google Chat

```yaml
reloader:
  deployment:
    env:
      secret:
        ALERT_ON_RELOAD: "true"
        ALERT_SINK: "gchat"
        ALERT_WEBHOOK_URL: "https://chat.googleapis.com/v1/spaces/..."
```

### Raw webhook

When `ALERT_SINK` is set to `webhook` (or left unset), Reloader sends a plain JSON POST to the URL.

```yaml
reloader:
  deployment:
    env:
      secret:
        ALERT_ON_RELOAD: "true"
        ALERT_SINK: "webhook"
        ALERT_WEBHOOK_URL: "https://your-internal-service/reloader-events"
        ALERT_ADDITIONAL_INFO: "env=staging"
```

---

## Using an existing Kubernetes Secret

If you already manage secrets externally (for example via External Secrets Operator), you can reference an existing Kubernetes Secret instead:

```yaml
reloader:
  deployment:
    env:
      existing:
        my-alert-secret:
          ALERT_ON_RELOAD: alert_on_reload
          ALERT_SINK: alert_sink
          ALERT_WEBHOOK_URL: alert_webhook_url
          ALERT_ADDITIONAL_INFO: alert_additional_info
```

This maps each environment variable to a key in the existing Secret named `my-alert-secret`.
