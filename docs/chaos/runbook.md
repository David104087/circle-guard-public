# Chaos Engineering — Runbook

> **Regla de oro:** todos los experimentos se ejecutan SOLO en `circleguard-dev`.
> Nunca en stage o production sin aprobación del equipo.

---

## Prerequisitos

```bash
# Verificar Chaos Mesh instalado
kubectl get pods -n chaos-testing

# Verificar namespace objetivo
kubectl get pods -n circleguard-dev

# Tener Grafana abierto para observar métricas en tiempo real
kubectl port-forward svc/grafana -n monitoring 3000:80
# (o usar el port-forward del deployment de grafana en el cluster)
```

---

## Flujo de un experimento

```
1. Definir hipótesis  →  2. Abrir Grafana/Kiali  →  3. Aplicar CRD
      ↓
4. Observar 60-120s  →  5. Detener (si es necesario)  →  6. Documentar resultados
```

---

## Cómo aplicar un experimento

```bash
# Aplicar manifiesto
kubectl apply -f docs/chaos/manifests/exp1-pod-failure.yaml

# Verificar que fue creado
kubectl get podchaos -n chaos-testing
kubectl get networkchaos -n chaos-testing
kubectl get stresschaos -n chaos-testing

# Ver status del experimento
kubectl describe podchaos kill-notification-service -n chaos-testing
```

---

## Cómo detener un experimento en curso

```bash
# Opción 1: Eliminar el recurso CRD (detención inmediata)
kubectl delete podchaos kill-notification-service -n chaos-testing
kubectl delete networkchaos delay-form-notification -n chaos-testing
kubectl delete networkchaos partition-gateway-auth -n chaos-testing
kubectl delete stresschaos stress-dashboard-cpu -n chaos-testing
kubectl delete podchaos kill-kafka -n chaos-testing

# Opción 2: Eliminar todos los experimentos activos
kubectl delete podchaos,networkchaos,stresschaos --all -n chaos-testing

# Opción 3: Dashboard de Chaos Mesh
kubectl port-forward svc/chaos-dashboard -n chaos-testing 2333:2333
# Abrir http://localhost:2333
```

---

## Cómo verificar que el experimento terminó y el sistema se recuperó

```bash
# Verificar pods volvieron a Running
kubectl get pods -n circleguard-dev -w

# Verificar no hay chaos activo
kubectl get podchaos,networkchaos,stresschaos -n chaos-testing

# Verificar logs del pod recuperado
kubectl logs -n circleguard-dev deployment/notification-service --tail=20

# Verificar métricas en Grafana (latencia, tasa de error volvieron a baseline)
```

---

## Comandos de observabilidad durante experimentos

```bash
# Ver logs en tiempo real de un servicio
kubectl logs -n circleguard-dev deployment/<service> -f

# Ver eventos del namespace
kubectl get events -n circleguard-dev --sort-by='.lastTimestamp' | tail -20

# Ver métricas de CPU/memoria de pods
kubectl top pods -n circleguard-dev

# Verificar estado de Kafka topics (si experimento afecta Kafka)
kubectl exec -n circleguard-dev deployment/kafka -- \
  kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --all-groups 2>/dev/null | head -20
```

---

## Experimentos disponibles

| Archivo | Tipo | Objetivo | Duración |
|---------|------|---------|---------|
| `exp1-pod-failure.yaml` | PodChaos | notification-service | 60s |
| `exp2-network-delay.yaml` | NetworkChaos | form→notification | 90s |
| `exp3-network-partition.yaml` | NetworkChaos | gateway→auth | 60s |
| `exp4-cpu-stress.yaml` | StressChaos | dashboard-service | 90s |
| `exp5-kafka-disruption.yaml` | PodChaos | kafka | 90s |

---

## Interpretación de resultados

### Circuit Breaker activado (Istio)
- Señal: errores 503 rápidos (< 100ms) en lugar de timeouts
- Evidencia: Kiali muestra arista roja + icono CB
- Grafana: spike de 5xx en error rate dashboard

### Retry Policy funcionando (Istio)
- Señal: tasa de error en el cliente < tasa de fallo real del servidor
- Evidencia: Jaeger muestra spans duplicados (retries)
- Grafana: `istio_requests_total{response_code="200"}` se mantiene alta

### Pod Recovery (Kubernetes)
- Señal: pod vuelve a Running sin intervención manual
- Tiempo esperado: < 30s para pod-kill en pods con imagen local
- Evidencia: `kubectl get pods -w` muestra `Terminating → ContainerCreating → Running`

### Kafka Recovery
- Señal: consumer lag baja a 0 después del restart del broker
- Tiempo esperado: < 3 minutos post-recuperación
- Evidencia: `kafka-consumer-groups.sh --describe` muestra LAG=0

---

## Qué hacer si un experimento sale de control

1. **Detener inmediatamente:** `kubectl delete podchaos,networkchaos,stresschaos --all -n chaos-testing`
2. **Verificar pods:** `kubectl get pods -n circleguard-dev`
3. **Reiniciar servicios afectados:** `kubectl rollout restart deployment/<service> -n circleguard-dev`
4. **Si el nodo tiene MemoryPressure:** `kubectl cordon <node>` y escalar cluster
5. **Caso extremo:** recrear el namespace: `kubectl delete ns circleguard-dev && kubectl apply -f k8s/00-namespaces.yaml && kubectl apply -f k8s/dev/`

---

## Políticas de seguridad para GameDay

1. **Solo en dev** — stage y prod requieren aprobación escrita del tech lead.
2. **Un experimento a la vez** — nunca dos chaos simultáneos.
3. **Duración máxima:** 120 segundos sin confirmación de resultados.
4. **Siempre con observabilidad abierta** — Grafana + kubectl logs antes de aplicar.
5. **Rollback plan documentado** antes de cada experimento.
6. **Horario:** preferiblemente fuera de horario de clase/demo.
