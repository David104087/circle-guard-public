# CircleGuard — Design Patterns

Overview of all design patterns implemented in the project, organized by category.

---

## Existing Patterns (found in codebase)

Documented in [`existing.md`](existing.md).

| Pattern | Services | Summary |
|---------|----------|---------|
| **API Gateway** | gateway-service | Single entry point; routes, validates, and controls external traffic |
| **Database per Service** | All 8 | Each service owns its schema; promotion-service uses PostgreSQL + Neo4j |
| **Event-Driven (Kafka)** | form, notification, promotion, dashboard | Async publish-subscribe via Kafka topics; loose coupling between domains |
| **JWT Authentication** | auth-service, gateway-service | HS256-signed tokens; stateless auth enforced on every request |
| **k-Anonymity Privacy Filter** | dashboard-service, identity-service | Suppresses metrics for groups <5 users; AES encryption of real identities |
| **Repository Pattern** | All 8 | Spring Data JpaRepository / Neo4jRepository abstracts all data access |
| **REST Client** | auth→identity, dashboard→promotion | Synchronous HTTP calls for request-response interactions |
| **Dual Auth Chain** | auth-service | LDAP + local DB authentication with fallback |
| **Strategy (Notification Dispatch)** | notification-service | Parallel multi-channel dispatch (email, SMS, push) via CompletableFuture |
| **Two-Hop Graph Propagation** | promotion-service | Cypher query propagates health status through contact-tracing graph |
| **Distributed Cache (Caffeine + Redis)** | promotion-service | L1 local + L2 Redis two-tier caching with @Cacheable / @CacheEvict |
| **Encryption at Rest (JPA Converter)** | identity-service | Transparent AES encryption/decryption of identity fields via @Converter |

---

## New Patterns (implemented for Proyecto Final)

### 1. Resilience: Circuit Breaker + Retry (Istio)

Documented in [`resilience.md`](resilience.md).

Istio `DestinationRule` configures circuit breakers (outlier detection, 5xx ejection) and `VirtualService` defines retry policies (3 attempts on GET, skip on mutations). Zero application code required — Envoy proxies handle it transparently.

**Benefit:** Prevents cascading failures. If `auth-service` starts returning 5xx errors, unhealthy pods are automatically ejected from the load-balancing pool within 30 seconds.

**Tradeoff:** Retry logic is at the mesh level, so application-level retry libraries (Resilience4j) would conflict — only one should be active.

**Files:** `k8s/istio/destination-rules.yaml`, `k8s/istio/virtual-services.yaml`

---

### 2. Configuration: External Configuration (GCP Secret Manager + ESO)

Documented in this section (task 5.3 — implemented in Phase 5).

`ExternalSecret` resources sync secrets from GCP Secret Manager into Kubernetes Secrets at deployment time via the External Secrets Operator. Services mount K8s Secrets as environment variables — no plaintext in manifests.

**Benefit:** Secrets never appear in Git. Rotation happens in Secret Manager without redeploying services. Audit trail via GCP IAM.

**Tradeoff:** Adds ESO as a cluster dependency; if ESO is unavailable, new pods won't start (secrets won't sync). Mitigated by ESO's high-availability deployment.

**Files:** `k8s/dev/external-secrets/`, `k8s/stage/external-secrets/`, `k8s/production/external-secrets/`

---

### 3. Sidecar (Istio Envoy Proxy)

Documented in [`sidecar.md`](sidecar.md).

Istio injects an Envoy sidecar into every pod in labeled namespaces. The sidecar handles mTLS (STRICT mode via `PeerAuthentication`), traffic shaping, observability (metrics/traces to Prometheus/Jaeger), and canary routing — all without modifying any Java service.

**Benefit:** Cross-cutting infrastructure concerns (security, observability, traffic control) are completely decoupled from business logic. Adding a new service automatically gets all these capabilities.

**Tradeoff:** 2 containers per pod increases resource overhead (~50MB RAM per sidecar). Pod startup is slower because the app container must wait for Envoy to initialize.

**Files:** `k8s/istio/peer-authentication.yaml`, `k8s/dev/*.yaml` (sidecar injected via namespace label `istio-injection=enabled`)

---

## Pattern Interaction Map

```
External Client
      │
      ▼
[Istio Gateway] ──── API Gateway Pattern
      │
      ▼
[Envoy Sidecar] ──── Sidecar + Circuit Breaker + Retry + mTLS
      │
      ▼
[Microservice] ──── JWT Auth + Repository + REST Client
      │         └── Event-Driven (Kafka)
      │
      ▼
[Database] ──── Database per Service + Encryption at Rest + Distributed Cache
```
