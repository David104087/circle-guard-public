# CircleGuard — Observability Runbook

How to access and use each observability tool.

---

## Tools Overview

| Tool | Purpose | Access |
|------|---------|--------|
| Prometheus | Metrics collection & alerting | `kubectl port-forward svc/kube-prometheus-kube-prome-prometheus -n monitoring 9090:9090` |
| Grafana | Dashboards | `kubectl port-forward svc/kube-prometheus-grafana -n monitoring 3000:80` |
| Alertmanager | Alert routing | `kubectl port-forward svc/kube-prometheus-kube-prome-alertmanager -n monitoring 9093:9093` |
| Jaeger | Distributed traces | `kubectl port-forward svc/jaeger-query -n istio-system 16686:16686` |
| Kibana | Log search & dashboards | `kubectl port-forward svc/kibana -n logging 5601:5601` |
| Kiali | Service mesh topology | `istioctl dashboard kiali` |

---

## Metrics (Prometheus + Grafana)

### Accessing Grafana

```bash
export KUBECONFIG=~/.kube/circleguard-dev
kubectl port-forward svc/kube-prometheus-grafana -n monitoring 3000:80
# Open http://localhost:3000
# Login: admin / CircleGuardGrafana2024
```

### Key dashboards

| Dashboard | Path in Grafana |
|-----------|----------------|
| Per-service JVM + HTTP metrics | Dashboards → CircleGuard → Services |
| Istio mesh overview | Dashboards → Istio → Istio Mesh Dashboard |
| Istio service details | Dashboards → Istio → Istio Service Dashboard |
| Node/cluster resources | Dashboards → Kubernetes → Cluster Resources |

### Useful PromQL queries

```promql
# Request rate per service (last 5min)
sum(rate(http_server_requests_seconds_count{namespace="circleguard-dev"}[5m])) by (uri)

# p95 latency per service
histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket{namespace="circleguard-dev"}[5m])) by (le, uri))

# Error rate
sum(rate(http_server_requests_seconds_count{namespace="circleguard-dev",status=~"5.."}[5m])) by (uri)
/ sum(rate(http_server_requests_seconds_count{namespace="circleguard-dev"}[5m])) by (uri)

# JVM heap usage %
sum(jvm_memory_used_bytes{namespace="circleguard-dev",area="heap"}) by (pod)
/ sum(jvm_memory_max_bytes{namespace="circleguard-dev",area="heap"}) by (pod) * 100

# Business metrics
surveys_submitted_total
files_uploaded_total
notifications_sent_total
```

---

## Logs (Kibana + Fluent Bit)

### Accessing Kibana

```bash
kubectl port-forward svc/kibana -n logging 5601:5601
# Open http://localhost:5601
```

### Index pattern

- Index: `circleguard-*`
- Time field: `@timestamp`

### Useful saved searches

| Search | Query |
|--------|-------|
| All errors in last 1h | `level: ERROR AND kubernetes.namespace_name: circleguard-dev` |
| Auth failures | `kubernetes.labels.app: auth-service AND message: "Authentication"` |
| Survey submissions | `kubernetes.labels.app: form-service AND message: "submitSurvey"` |
| Kafka consumer errors | `level: ERROR AND (kafka OR consumer)` |

### Installing ELK + Fluent Bit

```bash
# Install Elasticsearch
helm upgrade --install elasticsearch bitnami/elasticsearch \
  -n logging --create-namespace \
  -f k8s/logging/elasticsearch-helm-values.yaml

# Install Kibana
helm upgrade --install kibana bitnami/kibana \
  -n logging --set elasticsearch.hosts[0]=elasticsearch-master

# Deploy Fluent Bit DaemonSet
kubectl apply -f k8s/logging/fluent-bit-daemonset.yaml
```

---

## Traces (Jaeger)

### Accessing Jaeger UI

```bash
kubectl port-forward svc/jaeger-query -n istio-system 16686:16686
# Open http://localhost:16686
```

### Installing Jaeger

```bash
kubectl apply -f k8s/monitoring/jaeger.yaml
```

### Finding a multi-service trace

1. Open Jaeger UI at http://localhost:16686
2. Select service: `form-service.circleguard-dev`
3. Operation: `POST /surveys`
4. Click "Find Traces"
5. Select a trace to see the full chain: form-service → Kafka → promotion-service + notification-service

Istio automatically generates spans for all HTTP calls within the mesh. No instrumentation needed for intra-mesh traces. For Kafka propagation, trace context is injected via Spring headers (configured via `spring.kafka.producer.properties`).

---

## Alerts (Alertmanager)

### Configured alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| PodCrashLooping | >3 restarts in 15min | critical |
| PodNotReady | Not ready >5min | warning |
| HighP95Latency | p95 >1s | warning |
| HighErrorRate | >5% 5xx | critical |
| JvmHeapHigh | Heap >90% | warning |
| PvcAlmostFull | PVC >85% | warning |

### Firing an alert manually (test)

```bash
# Simulate pod crash loop
kubectl delete pod -n circleguard-dev -l app=auth-service
# Repeat 3+ times within 15 min to trigger PodCrashLooping alert
```

### Checking active alerts

```bash
kubectl port-forward svc/kube-prometheus-kube-prome-alertmanager -n monitoring 9093:9093
# http://localhost:9093
```

---

## Service Mesh (Kiali)

```bash
export KUBECONFIG=~/.kube/circleguard-dev
istioctl dashboard kiali
```

Shows live traffic flow between all 8 services with mTLS lock icons on every edge.

---

## Quick Troubleshooting

**Service returning 500s:**
1. Check Grafana → Error Rate dashboard
2. Check Kibana → `level: ERROR AND kubernetes.labels.app: <service>`
3. Check Jaeger for the failed trace
4. Check `kubectl logs -n circleguard-dev deployment/<service> -f`

**High latency:**
1. Grafana → p95 latency dashboard
2. Jaeger → find slow traces (sort by duration)
3. Check JVM heap: `kubectl top pods -n circleguard-dev`
4. Check DB connections: `kubectl exec statefulset/postgres -n circleguard-dev -- psql -U admin -c "SELECT count(*) FROM pg_stat_activity;"`

**Pod not starting:**
1. `kubectl describe pod <pod> -n circleguard-dev` → Events section
2. Check ESO secret sync: `kubectl get externalsecrets -n circleguard-dev`
3. Check PVC: `kubectl get pvc -n circleguard-dev`
