# Patrón: Sidecar (Istio Envoy Proxy)

## Descripción

El patrón **Sidecar** consiste en desplegar un contenedor auxiliar junto a cada contenedor de aplicación dentro del mismo pod. El sidecar comparte el namespace de red del pod y puede interceptar, transformar y gestionar el tráfico sin que la aplicación lo sepa.

## Implementación en CircleGuard

Istio inyecta automáticamente un proxy **Envoy** como sidecar en cada pod de los namespaces etiquetados con `istio-injection=enabled`.

```yaml
# Label aplicado en Task 3.2
kubectl label namespace circleguard-dev istio-injection=enabled
```

Después del `rollout restart`, cada pod tiene **2 contenedores**:
1. `<service-name>` — la aplicación Spring Boot
2. `istio-proxy` — el proxy Envoy

## Cross-cutting concerns que el sidecar maneja

| Concern | Implementación | Beneficio |
|---------|---------------|-----------|
| **mTLS** | Envoy cifra todo el tráfico saliente y verifica certificados en el entrante | La app no gestiona TLS/certificados |
| **Retry automático** | VirtualService configura reintentos en errores 5xx/connect-failure | La app no necesita Resilience4j o Hystrix |
| **Circuit Breaker** | DestinationRule detecta hosts fallidos y los expulsa del balanceo | Sin código de resiliencia en el servicio |
| **Métricas** | Envoy emite métricas Prometheus por defecto (latencia, RPS, errores) | Sin instrumentación adicional en la app |
| **Distributed tracing** | Envoy propaga headers `x-b3-traceid` y emite spans a Jaeger | Trazas distribuidas sin cambios en el código |
| **Access logging** | Envoy registra cada request/response | Logs estructurados sin configuración por servicio |

## Por qué es valioso

**Sin Sidecar:** Cada microservicio debería implementar estas capacidades por separado — distintas versiones de Resilience4j en Java, distintas configs de TLS, distintos formatos de log, distintas versiones del tracing SDK.

**Con Sidecar:** La plataforma gestiona todo esto de forma uniforme. Los desarrolladores se enfocan en la lógica de negocio; operaciones configura las políticas de red en manifests YAML.

## Trade-offs

- **Overhead de memoria/CPU:** Cada pod consume ~50-100 MB RAM y algunos milicores adicionales por el proxy Envoy.
- **Complejidad de depuración:** Un bug en la red puede estar en Envoy, no en la app — requiere conocer `istioctl proxy-config`.
- **Latencia adicional:** Dos saltos de proxy extra por request (source envoy → dest envoy) — típicamente <1ms.

## Referencias

- [`k8s/istio/peer-authentication.yaml`](../../k8s/istio/peer-authentication.yaml)
- [`k8s/istio/destination-rules.yaml`](../../k8s/istio/destination-rules.yaml)
- [`docs/operations/istio-verification.md`](../operations/istio-verification.md)
