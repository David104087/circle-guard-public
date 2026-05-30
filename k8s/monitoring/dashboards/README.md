# Grafana Dashboards — per service

One dashboard per microservice (Task 7.3). Each shows the four golden signals plus
JVM health and the service's business metric:

| Panel | Source metric |
|-------|---------------|
| Request rate (by status) | `http_server_requests_seconds_count` |
| Error rate (5xx %) | `http_server_requests_seconds_count{status=~"5.."}` |
| Latency p50 / p95 / p99 | `http_server_requests_seconds_bucket` (histogram_quantile) |
| JVM heap used / max | `jvm_memory_used_bytes`, `jvm_memory_max_bytes` (`area="heap"`) |
| GC pause rate | `jvm_gc_pause_seconds_sum` |
| Business metric | per service (see table below) |

## Business metric per service

| Service | Metric | Where it's incremented |
|---------|--------|------------------------|
| auth | `auth_tokens_issued_total` | `JwtTokenService.generateToken` |
| dashboard | `analytics_queries_total` (tag `scope`) | `AnalyticsService` queries |
| file | `files_uploaded_total` | `FileStorageService` |
| form | `surveys_submitted_total` (tag `has_symptoms`) | `HealthSurveyService.submitSurvey` |
| gateway | `qr_validations_total` (tag `result`) | `QrValidationService.validateToken` |
| identity | `identities_registered_total` | `IdentityVaultService.getOrCreateAnonymousId` |
| notification | `notifications_sent_total` | `NotificationDispatcher` |
| promotion | `health_status_changes_total` (tag `status`) | `HealthStatusService.updateStatus` |

## Template variables

- `$datasource` — Prometheus datasource (auto-selected; works under manual import and sidecar provisioning).
- `$namespace` — `circleguard-dev` / `circleguard-stage` / `circleguard-production`.
- `$service` — the `job` label, regex-filtered to this service.

## How they load

The kube-prometheus-stack Grafana sidecar watches the `monitoring` namespace for
ConfigMaps labeled `grafana_dashboard: "1"` (configured in
[`../kube-prometheus-values.yaml`](../kube-prometheus-values.yaml)).

```bash
# Package all 8 JSON files as labeled ConfigMaps and apply
kubectl apply -k k8s/monitoring/dashboards/

# Verify the sidecar picked them up
kubectl get cm -n monitoring -l grafana_dashboard=1
```

They appear in Grafana under **Dashboards** within ~30 s, no restart needed.

> The JSON files are also directly importable via the Grafana UI
> (**Dashboards → Import → Upload JSON**) for quick local inspection.
