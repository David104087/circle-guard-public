# CircleGuard — Test Results (Last Master Pipeline Run)

**Pipeline run:** Build #11 — 2026-05-25
**Duration:** ~29 minutes
**Result:** SUCCESS (canary approved, Release Notes pending final fix)

---

## Unit Tests

| Service | Tests | Passed | Failed | Duration |
|---------|-------|--------|--------|----------|
| auth-service | 4 | 4 | 0 | 8.2s |
| dashboard-service | 4 | 4 | 0 | 6.1s |
| file-service | 3 | 3 | 0 | 4.8s |
| form-service | 6 | 6 | 0 | 9.4s |
| notification-service | 8 | 8 | 0 | 11.2s |
| promotion-service | 8 | 8 | 0 | 34.7s |
| **Total** | **33** | **33** | **0** | **~74s** |

---

## Integration Tests

| Service | Tests | Passed | Failed | Notes |
|---------|-------|--------|--------|-------|
| auth-service | 1 | 1 | 0 | PostgreSQL via Testcontainers |
| dashboard-service | 1 | 1 | 0 | PostgreSQL via Testcontainers |
| file-service | 1 | 1 | 0 | S3 mock |
| form-service | 1 | 1 | 0 | PostgreSQL + Kafka |
| notification-service | 1 | 1 | 0 | Kafka |
| **Total** | **5** | **5** | **0** | |

---

## E2E Tests

| Service | Tests | Passed | Failed | Scenario |
|---------|-------|--------|--------|----------|
| auth-service | 1 | 1 | 0 | Login → JWT → protected endpoint |
| dashboard-service | 1 | 1 | 0 | Survey → analytics |
| file-service | 1 | 1 | 0 | Upload → download → checksum |
| form-service | 1 | 1 | 0 | Submit → Kafka event |
| promotion-service | 1 | 1 | 0 | Status change → graph propagation |
| **Total** | **5** | **5** | **0** | |

---

## Summary

| Category | Count | Pass rate |
|----------|-------|-----------|
| Unit | 33 | 100% |
| Integration | 5 | 100% |
| E2E | 5 | 100% |
| **Total** | **43** | **100%** |

---

## SonarQube Quality Gate

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| Quality Gate | Passed | — | ✅ |
| Code Coverage | ~67% | ≥60% | ✅ |
| Duplications | <3% | <10% | ✅ |
| Reliability | A | — | ✅ |

---

## Trivy Scan

| Service | CRITICAL | HIGH | Status |
|---------|----------|------|--------|
| All 8 services | Tomcat 10.1.19, Spring Security 6.2.3 | Multiple | ⚠️ Non-blocking |

Known CVEs from Spring Boot 3.2.4 — fix: upgrade to Spring Boot 3.2.12+. Non-blocking in pipeline.

---

## Performance (Locust — Taller 2 baseline, pre-GKE)

| Endpoint | RPS | Median (ms) | p95 (ms) | Errors |
|----------|-----|-------------|----------|--------|
| POST /surveys | 7.2 | 180 | 340 | 0% |
| GET /surveys/pending | 3.5 | 290 | 580 | 0% |
| POST /files/upload | 2.6 | 320 | 650 | 0% |
| GET /analytics/hotspots | 4.3 | 210 | 410 | 0% |
| **Total** | **21.77** | **230** | **460** | **0%** |

> GKE Locust results pending — requires active cluster with Istio gateway IP.

---

## ZAP Security Scan

Not yet run against live GKE environment (cluster was not active during pipeline test).
Stage pipeline stage is in place — will run automatically on next stage pipeline execution.
