# CircleGuard — Test Inventory

Source of truth for all automated tests in the project (from Taller 2, reused in Proyecto Final).

---

## Summary

| Type | Count | Framework | Status |
|------|-------|-----------|--------|
| Unit | 27 | JUnit 5 + Mockito | ✅ All passing |
| Integration | 6 | JUnit 5 + Testcontainers (PostgreSQL, Kafka) | ✅ All passing |
| E2E | 5 | JUnit 5 + Testcontainers (full stack) | ✅ All passing |
| Performance | 1 file | Locust | ✅ 2,558 req, 21.77 RPS, 0% errors |
| Security | ZAP baseline | OWASP ZAP | 🟡 Integrated in stage pipeline (non-blocking) |

**Total automated test classes: 38**

---

## Unit Tests (27 classes)

| Service | Test Class | What it tests |
|---------|-----------|---------------|
| auth-service | `JwtTokenServiceTest` | Token generation, expiry, claims |
| auth-service | `LoginControllerTest` | Login endpoint, LDAP fallback |
| dashboard-service | `AnalyticsServiceTest` | Hotspot aggregation logic |
| dashboard-service | `KAnonymityFilterTest` | k=5 suppression of small groups |
| dashboard-service | `AnalyticsControllerTest` | REST endpoints, 200/403 responses |
| file-service | `FileStorageServiceTest` | S3 upload/download, virus check stub |
| file-service | `FileUploadControllerTest` | Multipart upload endpoint |
| form-service | `HealthSurveyServiceTest` | Survey creation, Kafka publish |
| form-service | `SymptomMapperTest` | Symptom → severity mapping |
| form-service | `HealthSurveyControllerTest` | Survey REST endpoints |
| form-service | `QuestionnaireControllerTest` | Questionnaire CRUD |
| form-service | `AttachmentControllerTest` | File attachment to surveys |
| notification-service | `TemplateServiceTest` | Email template rendering |
| notification-service | `NotificationDispatcherTest` | Multi-channel parallel dispatch |
| notification-service | `PriorityAlertListenerTest` | Priority alert Kafka consumer |
| notification-service | `ExposureNotificationListenerTest` | Exposure event listener |
| notification-service | `NotificationRetryTest` | Retry logic on send failure |
| notification-service | `LmsServiceTest` | LMS integration stub |
| notification-service | `RoomReservationServiceTest` | Room reservation notifications |
| promotion-service | `HealthStatusServiceTest` | Status lifecycle transitions |
| promotion-service | `FloorServiceTest` | Floor-level hotspot detection |
| promotion-service | `HealthStatusReevaluationTest` | Re-evaluation on new evidence |
| promotion-service | `StatusLifecycleTest` | CONFIRMED → SUSPECT → PROBABLE |
| promotion-service | `AdministrativeCorrectionTest` | Admin override of status |
| promotion-service | `SurveyListenerTest` | Kafka survey event consumer |
| promotion-service | `HealthStatusControllerTest` | Status REST endpoints |
| identity-service | *(tested via auth-service integration)* | Identity mapping, encryption |

---

## Integration Tests (6 classes)

All use **Testcontainers** — no mocks for DB or Kafka.

| Service | Test Class | Infrastructure used |
|---------|-----------|-------------------|
| auth-service | `AuthLoginIntegrationTest` | PostgreSQL (H2 fallback) |
| dashboard-service | `DashboardIntegrationTest` | PostgreSQL |
| file-service | `FileUploadIntegrationTest` | PostgreSQL, S3 (mock) |
| form-service | `FormKafkaIntegrationTest` | PostgreSQL, Kafka |
| notification-service | `NotificationKafkaIntegrationTest` | Kafka, PostgreSQL |
| promotion-service | *(inline with unit tests)* | Neo4j + Redis (Testcontainers) |

---

## E2E Tests (5 classes)

Full-stack tests using Testcontainers — boot the entire service with all dependencies.

| Service | Test Class | Scenario covered |
|---------|-----------|-----------------|
| auth-service | `AuthLoginE2ETest` | Login → JWT → access protected endpoint |
| dashboard-service | `DashboardAnalyticsE2ETest` | Submit survey → analytics updated |
| file-service | `FileUploadDownloadE2ETest` | Upload → download → verify checksum |
| form-service | `HealthSurveyE2ETest` | Submit form → Kafka event emitted |
| promotion-service | `PromotionStatusE2ETest` | Status change → graph propagation |

---

## Performance Tests (Locust)

**File:** `tests/performance/locustfile.py`

**Target host:** `http://${GATEWAY_HOST}` (env var, default `http://localhost:8087`)

**Last results (Taller 2 — pre-GKE):**

| Endpoint | Requests | RPS | Median (ms) | p95 (ms) | Errors |
|----------|----------|-----|-------------|----------|--------|
| POST /surveys | 850 | 7.2 | 180 | 340 | 0% |
| GET /surveys/pending | 420 | 3.5 | 290 | 580 | 0% |
| POST /files/upload | 310 | 2.6 | 320 | 650 | 0% |
| GET /analytics/hotspots | 510 | 4.3 | 210 | 410 | 0% |
| GET /status/{id} | 468 | 4.0 | 150 | 290 | 0% |
| **Total** | **2558** | **21.77** | **230** | **460** | **0%** |

Run command:
```bash
locust -f tests/performance/locustfile.py \
  --host http://<GATEWAY_IP> \
  --headless --users 50 --spawn-rate 5 -t 2m \
  --html tests/performance/report.html
```

---

## Security Tests (OWASP ZAP)

**Script:** `tests/security/zap-baseline.sh`
**Target:** Istio ingress gateway external IP
**Mode:** Baseline scan (non-blocking in pipeline, see `docs/operations/security-tests.md`)

---

## Coverage Policy

See [`docs/operations/coverage-policy.md`](coverage-policy.md).

Current threshold: **60% line coverage** per service (enforced in pipeline).
