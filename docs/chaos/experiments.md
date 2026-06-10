# Chaos Engineering — Experimentos CircleGuard

> Todos los experimentos se ejecutan **únicamente en el cluster `circleguard-dev`** (namespace `circleguard-dev`).
> Nunca ejecutar experimentos en stage o production sin aprobación explícita.

---

## Principios de Chaos Engineering (GameDay)

1. **Hipótesis primero:** definir el comportamiento esperado antes de inyectar el fallo.
2. **Blast radius mínimo:** afectar solo el componente objetivo, duración ≤ 120 segundos.
3. **Observabilidad activa:** Grafana y Kiali abiertos durante el experimento.
4. **Stop manual disponible:** `kubectl delete chaoschaos/<nombre> -n chaos-testing` detiene inmediatamente.
5. **Documentar resultados:** registrar métricas antes, durante y después.

---

## Experimento 1 — Pod Failure: `notification-service`

| Campo | Valor |
|-------|-------|
| **Componente objetivo** | `notification-service` (Kafka consumer) |
| **Tipo de chaos** | `PodChaos` — pod-kill |
| **Duración** | 60 segundos |
| **Namespace** | `circleguard-dev` |

### Hipótesis
Cuando el pod de `notification-service` es eliminado, Kubernetes lo reinicia en ≤ 30 segundos. Durante ese intervalo, el circuit breaker de Istio absorbe los errores transitorios y los productores Kafka retienen mensajes en el topic. Al restaurarse el pod, el consumidor retoma el lag acumulado sin pérdida de datos.

### Comportamiento esperado
- Restart del pod en < 30 s (readiness probe TCP).
- Errores 5xx en `notification-service` durante el kill; ningún error en servicios upstream.
- Istio retry policy reintenta llamadas REST.
- Kafka lag en topic `health-notifications` sube durante el kill y baja al recuperarse.

### Criterios de éxito
- Pod vuelve a `Running` en < 30 s.
- Cero errores en `form-service` (productor Kafka) durante el experimento.
- Lag de Kafka vuelve a 0 dentro de 2 minutos post-recuperación.

### CRD Chaos Mesh
```yaml
# docs/chaos/manifests/exp1-pod-failure.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: kill-notification-service
  namespace: chaos-testing
spec:
  action: pod-kill
  mode: one
  selector:
    namespaces:
      - circleguard-dev
    labelSelectors:
      app: notification-service
  duration: "60s"
```

---

## Experimento 2 — Network Delay: `form-service → notification-service`

| Campo | Valor |
|-------|-------|
| **Componente objetivo** | Tráfico entre `form-service` y `notification-service` |
| **Tipo de chaos** | `NetworkChaos` — network-delay |
| **Latencia inyectada** | 200ms ± 50ms (distribución normal) |
| **Duración** | 90 segundos |

### Hipótesis
Con una latencia de 200ms adicional en la comunicación, los reintentos de Istio (`retries: 3, perTryTimeout: 2s`) absorben el impacto. El p95 de latencia en `form-service` aumenta pero permanece por debajo del umbral de alerta de 1s. Ningún request falla desde la perspectiva del cliente externo.

### Comportamiento esperado
- Latencia p95 en `form-service` sube de ~50ms a ~300ms.
- Traces en Jaeger muestran el span `form → notification` con delay.
- Istio retry histogram aumenta.
- Circuit breaker NO se abre (latencia < timeout de outlierDetection).

### Criterios de éxito
- Tasa de error en `form-service` < 1% durante el experimento.
- p99 < 1s (umbral de alerta de Prometheus).
- Traces en Jaeger confirman el delay en el span correcto.

### CRD Chaos Mesh
```yaml
# docs/chaos/manifests/exp2-network-delay.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: delay-form-notification
  namespace: chaos-testing
spec:
  action: delay
  mode: one
  selector:
    namespaces:
      - circleguard-dev
    labelSelectors:
      app: form-service
  delay:
    latency: "200ms"
    correlation: "25"
    jitter: "50ms"
  direction: to
  target:
    mode: one
    selector:
      namespaces:
        - circleguard-dev
      labelSelectors:
        app: notification-service
  duration: "90s"
```

---

## Experimento 3 — Network Partition: `gateway-service → auth-service`

| Campo | Valor |
|-------|-------|
| **Componente objetivo** | Tráfico entre `gateway-service` y `auth-service` |
| **Tipo de chaos** | `NetworkChaos` — network-loss 100% |
| **Duración** | 60 segundos |

### Hipótesis
Cuando `auth-service` es completamente inaccesible para `gateway-service`, el Circuit Breaker de Istio (outlierDetection) detecta los errores 5xx consecutivos y abre el circuito. Los requests al gateway retornan 503 (rápido-fail) en lugar de esperar el timeout completo. Al restaurarse la conectividad, el circuit breaker se cierra gradualmente (half-open).

### Comportamiento esperado
- Circuit breaker abre después de 5 errores consecutivos (umbral configurado en DestinationRule).
- Errores 503 devueltos en < 100ms (fast-fail, no timeout).
- Kiali muestra la arista gateway→auth en rojo con icono de circuit breaker.
- Al terminar el chaos, el circuito se cierra en 30s (ejectionTime configurado).

### Criterios de éxito
- Errores 503 reportados durante partición, no timeouts de 30s.
- `kubectl get destinationrule auth-service-destination -n circleguard-dev` mantiene la configuración de outlierDetection.
- Servicio se recupera automáticamente ≤ 60s después de restaurar red.

### CRD Chaos Mesh
```yaml
# docs/chaos/manifests/exp3-network-partition.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: partition-gateway-auth
  namespace: chaos-testing
spec:
  action: loss
  mode: one
  selector:
    namespaces:
      - circleguard-dev
    labelSelectors:
      app: gateway-service
  loss:
    loss: "100"
    correlation: "100"
  direction: to
  target:
    mode: one
    selector:
      namespaces:
        - circleguard-dev
      labelSelectors:
        app: auth-service
  duration: "60s"
```

---

## Experimento 4 — CPU Stress: `dashboard-service`

| Campo | Valor |
|-------|-------|
| **Componente objetivo** | `dashboard-service` (analítica geoespacial con k-anonimato) |
| **Tipo de chaos** | `StressChaos` — CPU stress 80% |
| **Duración** | 90 segundos |

### Hipótesis
Al saturar la CPU del `dashboard-service`, las consultas de analítica geoespacial aumentan su latencia significativamente. El JVM GC aumenta su frecuencia. Prometheus detecta el spike de CPU y la latencia. El Circuit Breaker de Istio puede detectar lentitud y degradar el servicio. Los demás servicios no se ven afectados.

### Comportamiento esperado
- CPU usage de `dashboard-service` sube a 80%+.
- Latencia p95 en `dashboard-service` sube > 500ms.
- GC pauses aumentan (visible en Grafana JVM dashboard).
- Alerta `DashboardHighLatency` dispara en Alertmanager.
- Otros servicios mantienen latencia normal.

### Criterios de éxito
- Alerta de Prometheus activa durante el stress.
- Servicio no muere (liveness probe TCP sobrevive).
- Latencia vuelve a baseline ≤ 30s después del stress.

### CRD Chaos Mesh
```yaml
# docs/chaos/manifests/exp4-cpu-stress.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: stress-dashboard-cpu
  namespace: chaos-testing
spec:
  mode: one
  selector:
    namespaces:
      - circleguard-dev
    labelSelectors:
      app: dashboard-service
  stressors:
    cpu:
      workers: 2
      load: 80
  duration: "90s"
```

---

## Experimento 5 — Kafka Disruption: Kill Kafka broker

| Campo | Valor |
|-------|-------|
| **Componente objetivo** | Pod `kafka-0` (broker Kafka) |
| **Tipo de chaos** | `PodChaos` — pod-kill |
| **Duración** | 90 segundos |

### Hipótesis
Cuando el broker Kafka es eliminado, los productores (`form-service`) fallan temporalmente al publicar mensajes y acumulan errores en los logs. Los consumidores (`notification-service`) pierden la conexión y suspenden el procesamiento. Cuando Kafka se recupera, los productores y consumidores se reconectan automáticamente y los mensajes acumulados (si no se perdieron) son procesados. El lag de Kafka refleja la interrupción.

### Comportamiento esperado
- `form-service` logs muestran `KafkaProducerException` durante la caída.
- `notification-service` logs muestran `Disconnected from broker` y `Reconnect`.
- Kafka lag sube durante la caída, baja tras la recuperación.
- Zookeeper mantiene el estado del topic/partición.
- Kafka se reinicia en < 60s (pod restart policy).

### Criterios de éxito
- Kafka pod vuelve a `Running` en < 60s.
- Lag en topics vuelve a 0 dentro de 3 minutos post-recuperación.
- No hay pérdida de mensajes (Kafka retención >= 24h configurada).
- `form-service` y `notification-service` se reconectan sin intervención manual.

### CRD Chaos Mesh
```yaml
# docs/chaos/manifests/exp5-kafka-disruption.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: kill-kafka
  namespace: chaos-testing
spec:
  action: pod-kill
  mode: one
  selector:
    namespaces:
      - circleguard-dev
    labelSelectors:
      app: kafka
  duration: "90s"
```

---

## Resumen de Experimentos

| # | Nombre | Componente | Tipo | Duración |
|---|--------|-----------|------|----------|
| 1 | Pod Failure | notification-service | pod-kill | 60s |
| 2 | Network Delay | form→notification | network-delay 200ms | 90s |
| 3 | Network Partition | gateway→auth | network-loss 100% | 60s |
| 4 | CPU Stress | dashboard-service | cpu-stress 80% | 90s |
| 5 | Kafka Disruption | kafka-0 | pod-kill | 90s |

---

## Orden de ejecución recomendado

1. Exp 1 (Pod Failure) — riesgo bajo, buen warm-up
2. Exp 5 (Kafka) — valida toda la cadena event-driven
3. Exp 4 (CPU Stress) — valida alerting y degradación gradual
4. Exp 2 (Network Delay) — valida retry policy de Istio
5. Exp 3 (Network Partition) — riesgo mayor, valida circuit breaker completo
