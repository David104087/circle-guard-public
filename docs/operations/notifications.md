# CircleGuard — Pipeline Notifications

All three CircleGuard pipelines send Slack notifications on failure. This document describes the setup.

---

## Slack Webhook

Notifications are sent via an incoming Slack webhook. The webhook URL is stored as a Jenkins secret credential with ID `slack-webhook`.

**Setup:**
1. In your Slack workspace, create an Incoming Webhook app and copy the URL.
2. In Jenkins → Manage Jenkins → Credentials → Global → Add Credential:
   - Kind: Secret text
   - ID: `slack-webhook`
   - Secret: the Webhook URL

---

## Notification Triggers

| Pipeline | Trigger | Message |
|----------|---------|---------|
| DEV | Any failure | `CircleGuard DEV pipeline #N FAILED. Branch: X. See: <URL>` |
| STAGE | Any failure | `CircleGuard STAGE pipeline #N FAILED. See: <URL>` |
| MASTER | Any failure | `CircleGuard MASTER/PRODUCTION pipeline #N FAILED. Immediate attention required. See: <URL>` |

---

## curl Command (used in Jenkinsfile)

```bash
curl -s -X POST -H 'Content-type: application/json' \
    --data '{"text":"<message>"}' \
    "$SLACK_URL"
```

The `|| true` suffix ensures a webhook failure never aborts the post block.

---

## Email Alternative

If Slack is not available, replace the curl call with a Jenkins `mail` step:

```groovy
mail to: 'team@circleguard.example.com',
     subject: "CircleGuard ${PIPELINE_NAME} #${BUILD_NUMBER} FAILED",
     body: "Pipeline failed at ${BUILD_URL}"
```

This requires the Jenkins Email Extension Plugin and an SMTP server configured in Jenkins system settings.
