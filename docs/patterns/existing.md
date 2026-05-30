# CircleGuard — Existing Design Patterns

Patterns identified across the 8 microservices by reading source code.

---

## 1. API Gateway

**Services:** `gateway-service`
**Files:**
- `services/circleguard-gateway-service/src/main/java/com/circleguard/gateway/controller/GateController.java`
- `k8s/istio/gateway.yaml`, `k8s/istio/virtual-services.yaml`

Single entry point (port 8087) that receives all external traffic through the Istio Ingress Gateway, validates QR/tokens, and routes requests to backend microservices via Istio VirtualServices. Hides internal topology from clients and enables cross-cutting concerns (auth, rate limiting) in one place.

---

## 2. Database per Service (Polyglot Persistence)

**Services:** All 8 services
**Files:**
- `k8s/dev/auth-service.yaml` → `circleguard_auth`
- `k8s/dev/identity-service.yaml` → `circleguard_identity`
- `services/circleguard-promotion-service/src/main/java/com/circleguard/promotion/config/Neo4jConfig.java`
- `services/circleguard-promotion-service/src/main/java/com/circleguard/promotion/config/DataLayerConfig.java`

Each service owns its isolated database schema. `promotion-service` uniquely uses both PostgreSQL (relational data) and Neo4j (graph-based contact tracing). Ensures services can be deployed, scaled, and changed independently without shared-schema coupling.

---

## 3. Event-Driven Architecture (Apache Kafka)

**Services:** `form-service` (producer), `notification-service`, `promotion-service`, `dashboard-service` (consumers)
**Files:**
- `services/circleguard-form-service/src/main/java/com/circleguard/form/service/HealthSurveyService.java` — publishes `survey.submitted`, `certificate.validated`
- `services/circleguard-promotion-service/src/main/java/com/circleguard/promotion/listener/SurveyListener.java` — consumes survey events
- `services/circleguard-notification-service/src/main/java/com/circleguard/notification/service/ExposureNotificationListener.java` — consumes `promotion.status.changed`
- `services/circleguard-notification-service/src/main/java/com/circleguard/notification/service/CircleFencedListener.java` — consumes `circle.fenced`

Services communicate asynchronously via Kafka topics. Producers emit domain events; consumers react independently with `@KafkaListener`. Enables loose coupling — form-service doesn't know who will process a submitted survey.

---

## 4. JWT / Token-Based Authentication

**Services:** `auth-service` (issuer), `gateway-service` (enforcer)
**Files:**
- `services/circleguard-auth-service/src/main/java/com/circleguard/auth/service/JwtTokenService.java`
- `services/circleguard-auth-service/src/main/java/com/circleguard/auth/security/JwtAuthenticationFilter.java`
- `services/circleguard-auth-service/src/main/java/com/circleguard/auth/security/SecurityConfig.java`

HS256-signed JWTs carry `anonymousId` and permission claims. `JwtAuthenticationFilter` (extends `OncePerRequestFilter`) validates every incoming Bearer token. Stateless — no session required on backend, enabling horizontal scaling.

---

## 5. k-Anonymity Privacy Filter

**Services:** `dashboard-service`, `identity-service`
**Files:**
- `services/circleguard-dashboard-service/src/main/java/com/circleguard/dashboard/service/KAnonymityFilter.java`
- `services/circleguard-identity-service/src/main/java/com/circleguard/identity/util/IdentityEncryptionConverter.java`
- `services/circleguard-identity-service/src/main/java/com/circleguard/identity/service/IdentityVaultService.java`

`KAnonymityFilter` suppresses hotspot metrics for groups with fewer than k=5 users, preventing individual re-identification in analytics. `IdentityVaultService` maps real identities to anonymous UUIDs; real data is AES-encrypted at rest via a JPA `@Converter`. Privacy is enforced at the data layer, not the API layer.

---

## 6. Repository Pattern

**Services:** All 8 services
**Files:**
- `services/circleguard-auth-service/src/main/java/com/circleguard/auth/repository/LocalUserRepository.java`
- `services/circleguard-form-service/src/main/java/com/circleguard/form/repository/HealthSurveyRepository.java`
- `services/circleguard-promotion-service/src/main/java/com/circleguard/promotion/repository/graph/UserNodeRepository.java`

All data access goes through Spring Data `JpaRepository` (SQL) or `Neo4jRepository` (graph). Encapsulates query logic and provides transactional consistency boundaries. Services depend on repository interfaces, not concrete SQL.

---

## 7. REST Client Pattern

**Services:** `auth-service` → `identity-service`, `dashboard-service` → `promotion-service`, `notification-service` → LMS
**Files:**
- `services/circleguard-auth-service/src/main/java/com/circleguard/auth/client/IdentityClient.java`
- `services/circleguard-dashboard-service/src/main/java/com/circleguard/dashboard/client/PromotionClient.java`
- `services/circleguard-notification-service/src/main/java/com/circleguard/notification/service/PushServiceImpl.java`

Synchronous HTTP calls using `RestTemplate` or `WebClient` for request-response interactions. Used where the caller needs an immediate result (e.g., resolving an anonymous ID before issuing a JWT).

---

## 8. Dual Authentication Chain

**Services:** `auth-service`
**Files:**
- `services/circleguard-auth-service/src/main/java/com/circleguard/auth/security/SecurityConfig.java`
- `services/circleguard-auth-service/src/main/java/com/circleguard/auth/security/DualChainAuthenticationProvider.java`

Spring Security chains an LDAP provider (corporate directory) with a DAO provider (local database). Falls back to local auth if LDAP is unavailable. Supports institutional users and standalone accounts in one unified flow.

---

## 9. Multi-Channel Notification Dispatch (Strategy Pattern)

**Services:** `notification-service`
**Files:**
- `services/circleguard-notification-service/src/main/java/com/circleguard/notification/service/NotificationDispatcher.java`

`NotificationDispatcher` composes email, SMS, and push strategies, dispatching all channels in parallel via `CompletableFuture.allOf`. Adding a new channel requires only a new strategy implementation — the dispatcher doesn't change.

---

## 10. Two-Hop Graph Propagation (Neo4j)

**Services:** `promotion-service`
**Files:**
- `services/circleguard-promotion-service/src/main/java/com/circleguard/promotion/service/HealthStatusService.java`

Custom Cypher query propagates health status changes through `ENCOUNTERED` and `MEMBER_OF` graph relationships up to two hops (direct + secondary contacts). Status downgrades follow CONFIRMED → SUSPECT → PROBABLE. Optimized to meet the <1s NFR-1 response target.

---

## 11. Distributed Caching (Caffeine + Redis)

**Services:** `promotion-service`
**Files:**
- `services/circleguard-promotion-service/src/main/java/com/circleguard/promotion/config/CacheConfig.java`
- `services/circleguard-promotion-service/src/main/java/com/circleguard/promotion/service/HealthStatusService.java`

Two-tier cache: Caffeine (local, L1, 5-min TTL) and Redis (distributed, L2). `@Cacheable` reads hit L1 first; `@CacheEvict` on status mutations purges both tiers. Prevents stale reads across pod replicas.

---

## 12. Encryption at Rest (JPA Converter)

**Services:** `identity-service`
**Files:**
- `services/circleguard-identity-service/src/main/java/com/circleguard/identity/util/IdentityEncryptionConverter.java`

JPA `@Converter` transparently AES-encrypts the `real_identity` field on INSERT/UPDATE and decrypts on SELECT using Spring Security `TextEncryptor`. Application code never handles raw plaintext identity data.
