# K8s Migration: DigitalOcean → GKE

## Status

| Task | Status | Notes |
|------|--------|-------|
| 2.1 Manifest inventory | ✅ Done | This document |
| 2.2 StorageClass references | ✅ Done | Added `storageClassName: standard-rwo` to all PVCs |
| 2.3 LoadBalancer annotations | ✅ Done | No DO-specific annotations found — no changes needed |
| 2.4 Ingress strategy | ✅ Done | Using GKE LoadBalancer; Istio Gateway replaces it in Phase 3 |
| 2.5 Deploy infra → dev | ✅ Done | All infra pods Running |
| 2.6 Verify Postgres + DBs | ✅ Done | 5 databases created |
| 2.7 Verify Kafka + Zookeeper | ✅ Done | Broker reachable |
| 2.8 Verify Redis + Neo4j | ✅ Done | Both reachable |
| 2.9 Deploy services → dev | ✅ Done | All 8 services Running |
| 2.10 Smoke test dev | ✅ Done | All health endpoints 200 |
| 2.11 Repeat for stage | ✅ Done | |
| 2.12 Repeat for prod | ✅ Done | |

---

## 1. Manifest Inventory

### k8s/00-namespaces.yaml
- Creates: `circleguard-dev`, `circleguard-stage`, `circleguard-production`
- GKE compatible as-is: ✅

### k8s/infrastructure/

| File | Resources | GKE changes needed |
|------|-----------|-------------------|
| `postgres.yaml` | StatefulSet + Service (3 namespaces) | ✅ Add `storageClassName: standard-rwo` to PVC |
| `kafka.yaml` | Deployment + Service for Kafka + Zookeeper (3 namespaces) | ✅ Add missing `targetPort` in stage/prod services |
| `redis.yaml` | Deployment + Service (3 namespaces) | ✅ No PVC — reusable as-is |
| `neo4j.yaml` | StatefulSet + Service (3 namespaces) | ✅ Add `storageClassName: standard-rwo` to PVC |
| `mailhog.yaml` | Deployment + Service (3 namespaces) | ✅ Add missing `targetPort` in stage/prod services |

### k8s/dev/ (and equivalent stage/, production/)

| File | Service | Port | Image | Changes needed |
|------|---------|------|-------|----------------|
| `auth-service.yaml` | circleguard-auth-service | 8180 | `davidartunduaga/circleguard-auth:latest` | ✅ None |
| `dashboard-service.yaml` | circleguard-dashboard-service | 8084 | `davidartunduaga/circleguard-dashboard:latest` | ✅ None |
| `file-service.yaml` | circleguard-file-service | 8085 | `davidartunduaga/circleguard-file:latest` | ✅ None |
| `form-service.yaml` | circleguard-form-service | 8086 | `davidartunduaga/circleguard-form:latest` | ✅ None |
| `gateway-service.yaml` | circleguard-gateway-service | 8087 | `davidartunduaga/circleguard-gateway:latest` | ❌ **MISSING — created in this PR** |
| `identity-service.yaml` | circleguard-identity-service | 8083 | `davidartunduaga/circleguard-identity:latest` | ❌ **MISSING — created in this PR** |
| `notification-service.yaml` | circleguard-notification-service | 8082 | `davidartunduaga/circleguard-notification:latest` | ✅ None |
| `promotion-service.yaml` | circleguard-promotion-service | 8088 | `davidartunduaga/circleguard-promotion:latest` | ✅ None |

---

## 2. StorageClass Decision

GKE does not have `do-block-storage`. No DO storage class was referenced in the existing manifests — PVCs had no `storageClassName` set, which on GKE uses the default class.

**Decision:** Explicitly set `storageClassName: standard-rwo` on all PVCs.

`standard-rwo` is the GKE default for ReadWriteOnce persistent disks (pd-standard). It replaces any implicit default and ensures portability across GKE versions.

Affected PVCs:
- `postgres`: `pgdata` (5 Gi) — dev, stage, production
- `neo4j`: `neo4j-data` (5 Gi) — dev, stage, production

---

## 3. LoadBalancer Annotations

**Finding:** The existing manifests have zero DigitalOcean-specific annotations. All Services use `ClusterIP: None` (headless) or plain ClusterIP — no LoadBalancer type services exist yet.

**No changes required for task 2.3.**

---

## 4. Ingress Strategy

**Decision: No Ingress controller for Phase 2. Use GKE LoadBalancer when external access is needed.**

Rationale:
- Phase 3 installs Istio and replaces all external traffic routing with an Istio `Gateway` resource.
- Installing nginx-ingress or GCE Ingress would be immediately superseded.
- For Phase 2 smoke tests, all verification is done from inside the cluster.
- If external access is needed before Phase 3, a single `type: LoadBalancer` Service can be patched temporarily.

**Documented external endpoints (post Phase 3 Istio Gateway):**
- Single external IP on `istio-ingressgateway` routes to all services.

---

## 5. New Services: gateway-service and identity-service

Both services exist in `services/` but were missing k8s manifests and Dockerfiles.

### circleguard-gateway-service
- **Port:** 8087
- **Dependencies:** Redis, JWT secret, QR secret
- **Docker image:** `davidartunduaga/circleguard-gateway:latest`
- **Dockerfile:** `services/circleguard-gateway-service/Dockerfile` (created in this PR)

### circleguard-identity-service
- **Port:** 8083
- **Dependencies:** PostgreSQL (`circleguard_identity` DB), JWT secret, vault secrets
- **Docker image:** `davidartunduaga/circleguard-identity:latest`
- **Dockerfile:** `services/circleguard-identity-service/Dockerfile` (created in this PR)
- **DB note:** `circleguard_identity` is already in the Postgres init script — no changes needed.

---

## 6. Minor Fixes Applied

- `k8s/infrastructure/kafka.yaml` stage zookeeper service: added `targetPort: 2181`
- `k8s/infrastructure/mailhog.yaml` stage/production services: added `targetPort` for smtp/web-ui
- `k8s/infrastructure/neo4j.yaml` stage/production: added port `name:` fields for bolt/http
