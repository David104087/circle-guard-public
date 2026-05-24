# Service Mesh con Istio

## Qué se implementó

CircleGuard usa **Istio 1.29.2** como service mesh en los tres entornos (dev, stage, production).

## Por qué Istio en lugar de Linkerd

| Criterio | Istio | Linkerd |
|----------|-------|---------|
| Circuit Breaker nativo | ✅ DestinationRule | ❌ Requiere biblioteca app |
| Traffic splitting granular | ✅ VirtualService | ✅ HTTPRoute |
| Kiali (visualización) | ✅ Integración oficial | ⚠️ Buoyant Cloud (pago) |
| Perfil demo completo | ✅ `--set profile=demo` | ❌ Instalación más manual |
| Jaeger out-of-the-box | ✅ addon incluido | ⚠️ Config adicional |
| Madurez del proyecto | Mayor (CNCF Graduated) | Alta (CNCF Graduated) |

**Decisión:** Istio ofrece el Circuit Breaker (Phase 5 patrón de resiliencia) y la visualización Kiali en un solo paquete, reduciendo la complejidad de integración.

## Estrategia mTLS

**Modo:** `STRICT` en todos los namespaces CircleGuard.

Con modo STRICT:
- Todos los pods del namespace deben tener sidecar Envoy inyectado.
- Cualquier conexión plain HTTP proveniente de fuera del mesh es rechazada por el Envoy del destino.
- La aplicación usa HTTP normal en localhost → Envoy lo cifra automáticamente en tránsito.

Archivo: [`k8s/istio/peer-authentication.yaml`](../../k8s/istio/peer-authentication.yaml)

## Gestión de tráfico

### Retry policies

GET requests en todos los servicios tienen retry automático (3 intentos, `retryOn: 5xx,gateway-error,connect-failure`). POST/PUT/DELETE no tienen retry (no idempotentes).

Ver: [`k8s/istio/virtual-services.yaml`](../../k8s/istio/virtual-services.yaml)

### Circuit Breaker

`outlierDetection` en todos los servicios: 5 errores 5xx consecutivos → expulsión por 30s.

Ver: [`k8s/istio/destination-rules.yaml`](../../k8s/istio/destination-rules.yaml)

### Canary deployments

`gateway-service` tiene dos subsets (v1/v2) en su DestinationRule. El split de tráfico se ajusta modificando los pesos en el VirtualService. Pipeline Phase 4 automatiza el flujo 0% → 10% → 100% con aprobación manual.

Ver: [`docs/operations/canary-deployments.md`](../operations/canary-deployments.md)

## Ingress Gateway

Un único GCP LoadBalancer (`istio-ingressgateway`) recibe todo el tráfico externo.
IP: `35.253.156.137` (dev). Puerto 80 (HTTP, TLS en Phase 8).

Archivo: [`k8s/istio/gateway.yaml`](../../k8s/istio/gateway.yaml)

## Observabilidad del mesh

| Tool | Puerto | Acceso |
|------|--------|--------|
| Kiali | 20001 | `istioctl dashboard kiali` |
| Jaeger | 16686 | `istioctl dashboard jaeger` |
| Grafana | 3000 | `istioctl dashboard grafana` |
| Prometheus | 9090 | `istioctl dashboard prometheus` |

Todos corren en `istio-system` namespace.

## Verificación rápida

```bash
# Ver mTLS activo en todos los namespaces
kubectl get peerauthentication -A

# Ver sidecars inyectados (debe mostrar 2 containers por pod)
kubectl get pods -n circleguard-dev

# Ver circuit breakers configurados
kubectl get destinationrule -n circleguard-dev

# Ver traffic routing
kubectl get virtualservice -n circleguard-dev
```

## Diagrama del mesh (Kiali)

Ver screenshot en [`docs/diagrams/kiali-graph.png`](../diagrams/kiali-graph.png) (generado durante la sesión de demo).
