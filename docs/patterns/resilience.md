# Patrón de Resiliencia: Circuit Breaker + Retry (via Istio)

## Qué es

El **Circuit Breaker** es un patrón que detecta cuando un servicio downstream está fallando repetidamente y "abre el circuito" — dejando de enviarle peticiones temporalmente para evitar cascadas de fallos. Se combina con **Retry** para reintentar automáticamente operaciones idempotentes antes de declarar el fallo.

## Implementación en CircleGuard

Implementado via `DestinationRule` y `VirtualService` de Istio. No requiere cambios en el código de los microservicios — el proxy Envoy gestiona todo esto de forma transparente.

### Circuit Breaker (DestinationRule)

Archivo: [`k8s/istio/destination-rules.yaml`](../../k8s/istio/destination-rules.yaml)

Configuración aplicada a **todos los 8 servicios**:

```yaml
trafficPolicy:
  connectionPool:
    tcp:
      maxConnections: 100          # Máximo de conexiones TCP abiertas
    http:
      http1MaxPendingRequests: 50  # Cola máxima de peticiones en espera
      http2MaxRequests: 100        # Peticiones HTTP/2 concurrentes máximas
  outlierDetection:
    consecutive5xxErrors: 5        # Abrir circuito tras 5 errores 5xx consecutivos
    interval: 30s                  # Ventana de evaluación
    baseEjectionTime: 30s          # Tiempo mínimo de exclusión del host
    maxEjectionPercent: 50         # Máximo 50% de hosts excluidos simultáneamente
```

**Cómo funciona:** Si `auth-service` devuelve 5 errores 5xx consecutivos en una ventana de 30s, Istio lo expulsa del balanceo por 30s. Si los errores continúan en el siguiente ciclo, el tiempo de expulsión aumenta (exponential backoff hasta `maxEjectionTime`).

### Retry Policy (VirtualService)

Archivo: [`k8s/istio/virtual-services.yaml`](../../k8s/istio/virtual-services.yaml)

Aplicado a **peticiones GET** de todos los servicios (operaciones idempotentes — se pueden reintentar sin efectos secundarios):

```yaml
match:
  - method:
      exact: GET
retries:
  attempts: 3             # Hasta 3 intentos
  perTryTimeout: 5s       # Timeout por intento (10s para file-service por archivos grandes)
  retryOn: 5xx,gateway-error,connect-failure,retriable-4xx
```

**Endpoints con retry habilitado:** Cualquier GET en auth-service, dashboard-service, file-service (GET/download), form-service, identity-service, notification-service, promotion-service.

**Endpoints SIN retry:** POST/PUT/DELETE (no idempotentes — un retry podría crear recursos duplicados o ejecutar acciones dos veces). Kafka producers tampoco reciben retry en la capa HTTP.

## Beneficios

- **Fail fast:** El circuito abierto devuelve error inmediatamente en lugar de esperar timeouts largos, reduciendo latencia percibida.
- **Aislamiento de fallos:** Un servicio degradado no afecta al resto — el circuito lo aisla temporalmente.
- **Auto-recuperación:** El circuito pasa a "half-open" tras `baseEjectionTime`, probando si el servicio se recuperó.
- **Zero-code:** Los microservicios Spring Boot no necesitan librerías adicionales (Resilience4j, Hystrix, etc.).

## Trade-offs

- La configuración está en Istio, no en el código — si se elimina Istio, se pierde la resiliencia.
- `outlierDetection` trabaja a nivel de **pod** (host), no de endpoint. Un pod que falla en un endpoint específico es expulsado completamente.
- Los umbrales (5 errores, 30s) son conservadores para un entorno académico — en producción real se ajustarían según el SLA.

## Referencias

- [`k8s/istio/destination-rules.yaml`](../../k8s/istio/destination-rules.yaml) — configuración completa del Circuit Breaker
- [`k8s/istio/virtual-services.yaml`](../../k8s/istio/virtual-services.yaml) — configuración completa de Retry
- [Istio Circuit Breaking docs](https://istio.io/latest/docs/tasks/traffic-management/circuit-breaking/)
