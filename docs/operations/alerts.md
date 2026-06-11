# CircleGuard — Alerting Rules

Alertas configuradas en `k8s/monitoring/alerting-rules.yaml` via `PrometheusRule` CRD.
Alertmanager las enruta al canal Slack `#circleguard-alerts` (webhook en credencial Jenkins `slack-webhook`).

---

## Resumen de alertas

| Alerta | Severidad | Condición | Ventana | For | Grupo |
|--------|-----------|-----------|---------|-----|-------|
| PodCrashLooping | critical | >3 reinicios en 15min | 30s | 5m | circleguard.pods |
| PodNotReady | warning | Pod not ready | 30s | 5m | circleguard.pods |
| HighP95Latency | warning | p95 latencia >1s | 30s | 5m | circleguard.latency |
| HighErrorRate | critical | >5% errores 5xx | 30s | 5m | circleguard.errors |
| JvmHeapHigh | warning | Heap JVM >90% | 60s | 10m | circleguard.jvm |
| PvcAlmostFull | warning | PVC >85% lleno | 5m | 10m | circleguard.storage |

---

## Detalles por alerta

### PodCrashLooping

**Archivo fuente:** `k8s/monitoring/alerting-rules.yaml` — grupo `circleguard.pods`, regla 1

**Condición:**
```promql
increase(kube_pod_container_status_restarts_total{namespace=~"circleguard-.*"}[15m]) > 3
```

**Causa más probable:** OOMKilled (falta memoria), error de conexión al iniciar (base de datos no disponible), imagen corrupta, sidecar Istio iniciándose antes que la app.

**Acción al recibir:**
1. `kubectl get pods -n <namespace>` — identificar pod afectado
2. `kubectl describe pod <pod> -n <namespace>` — leer Events (razón del reinicio)
3. `kubectl logs <pod> -n <namespace> --previous` — logs del contenedor anterior
4. Si es OOM: revisar memory limits en el Deployment, aumentar `resources.limits.memory`
5. Si es conexión DB: verificar que Postgres/Redis esté Running y ESO haya sincronizado el Secret

---

### PodNotReady

**Archivo fuente:** `k8s/monitoring/alerting-rules.yaml` — grupo `circleguard.pods`, regla 2

**Condición:**
```promql
kube_pod_status_ready{condition="false",namespace=~"circleguard-.*"} == 1
```

**Causa más probable:** Readiness probe fallando, Secret no sincronizado por ESO, dependencia de infraestructura no disponible.

**Acción al recibir:**
1. `kubectl get pods -n <namespace>` — estado del pod
2. `kubectl describe pod <pod>` → sección "Conditions" y "Events"
3. `kubectl get externalsecrets -n <namespace>` — verificar `SecretSynced: True`
4. Si readiness probe falla: `kubectl exec <pod> -- curl -s http://localhost:<port>/actuator/health/readiness`

---

### HighP95Latency

**Archivo fuente:** `k8s/monitoring/alerting-rules.yaml` — grupo `circleguard.latency`

**Condición:**
```promql
histogram_quantile(0.95,
  sum(rate(http_server_requests_seconds_bucket{namespace=~"circleguard-.*"}[5m])) by (le, service)
) > 1
```

**Causa más probable:** Consultas N+1 en base de datos, GC pause del JVM, saturación de CPU, latencia de red inusual, Istio circuit breaker abriendo y reintentando.

**Acción al recibir:**
1. Grafana → dashboard del servicio afectado → panel "p95 Latency" — identificar endpoint lento
2. Jaeger → buscar trazas lentas del servicio
3. `kubectl top pods -n <namespace>` — verificar CPU/memoria
4. Revisar logs de Postgres para queries lentas: `kubectl exec statefulset/postgres -n <namespace> -- psql -U admin -c "SELECT query, mean_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 5;"`

---

### HighErrorRate

**Archivo fuente:** `k8s/monitoring/alerting-rules.yaml` — grupo `circleguard.errors`

**Condición:**
```promql
sum(rate(http_server_requests_seconds_count{...,status=~"5.."}[5m])) by (service)
/ sum(rate(http_server_requests_seconds_count{...}[5m])) by (service)
> 0.05
```

**Causa más probable:** Excepción no controlada en el servicio, backend dependency caído, secreto rotado sin reiniciar el pod, Kafka desconectado.

**Acción al recibir:**
1. Kibana → `level: ERROR AND kubernetes.labels.app: <service>` — últimos 15 minutos
2. `kubectl logs deployment/<service> -n <namespace> --tail=100`
3. Jaeger → trazas con status 500 del servicio afectado
4. Verificar dependencias: `kubectl get pods -n <namespace>` (Postgres, Kafka, Redis)
5. Si es un 503 de Istio: revisar DestinationRule y circuit breaker — puede estar en estado abierto

---

### JvmHeapHigh

**Archivo fuente:** `k8s/monitoring/alerting-rules.yaml` — grupo `circleguard.jvm`

**Condición:**
```promql
sum(jvm_memory_used_bytes{namespace=~"circleguard-.*",area="heap"}) by (pod)
/ sum(jvm_memory_max_bytes{namespace=~"circleguard-.*",area="heap"}) by (pod)
> 0.9
```

**Causa más probable:** Memory leak, caché sin límite, procesamiento de payload grande, GC no liberando suficiente.

**Acción al recibir:**
1. Grafana → panel "JVM Heap Usage" del pod afectado
2. `kubectl top pod <pod> -n <namespace>` — comparar con `resources.limits.memory`
3. Si está por encima del limit: `kubectl delete pod <pod>` para forzar GC completo al reiniciar
4. Largo plazo: revisar si `Xmx` en `JAVA_TOOL_OPTIONS` está ajustado correctamente (`-Xmx256m` por defecto en nodos DO)

---

### PvcAlmostFull

**Archivo fuente:** `k8s/monitoring/alerting-rules.yaml` — grupo `circleguard.storage`

**Condición:**
```promql
(kubelet_volume_stats_used_bytes{namespace=~"circleguard-.*"}
/ kubelet_volume_stats_capacity_bytes{namespace=~"circleguard-.*"}) > 0.85
```

**Causa probable:** Crecimiento de datos de Postgres/Elasticsearch, logs de Kafka no purgados, snapshots acumulados.

**Acción al recibir:**
1. `kubectl get pvc -n <namespace>` — identificar PVC afectado
2. Para Postgres: `kubectl exec statefulset/postgres -n <namespace> -- psql -U admin -c "SELECT pg_size_pretty(pg_database_size('circleguard'));"` — ver tamaño de BD
3. Para Elasticsearch: limpiar índices viejos (> 30 días) via Kibana → Index Management
4. Si no hay forma de liberar espacio: expandir PVC (GKE soporta `kubectl patch pvc ... --patch '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'`)

---

## Canal de notificación

Las alertas críticas y warnings se envían al webhook de Slack configurado en Jenkins (`slack-webhook`). El mismo canal recibe notificaciones de pipeline y de Trivy.

Configuración Alertmanager: `k8s/monitoring/alertmanager-config.yaml`

Para probar manualmente que Alertmanager envía:
```bash
# Port-forward Alertmanager
kubectl port-forward svc/kube-prometheus-kube-prome-alertmanager -n monitoring 9093:9093
# POST de alerta de prueba
curl -H 'Content-Type: application/json' -d '[{"labels":{"alertname":"TestAlert","severity":"warning"}}]' \
  http://localhost:9093/api/v1/alerts
```
