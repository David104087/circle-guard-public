# CircleGuard — Presentation Slides Outline

SE5 Proyecto Final — Ingeniería de Software V

---

## Slide 1: Title

**CircleGuard**
*University Health Monitoring Platform*

SE5 Proyecto Final | David Artunduaga Peñagos
Stack: Spring Boot · GKE · Terraform · Istio · Jenkins

---

## Slide 2: What is CircleGuard?

- University contact tracing and health monitoring platform
- 8 microservices, Java 21, Spring Boot 3.2
- **Privacy-first**: k-anonymity, AES encryption, anonymous UUIDs
- Migrated from DigitalOcean → **GCP/GKE** for this project

```
Form → Kafka → Promotion (Neo4j) → Notification
                ↓
          Dashboard (k-anonymity)
```

---

## Slide 3: Architecture

*(show docs/diagrams/architecture.md — system overview diagram)*

- 8 services, 3 environments (dev/stage/prod)
- Terraform: VPC + GKE + Secret Manager + IAM
- Istio service mesh on all pods (Envoy sidecars)
- GCP Secret Manager → External Secrets Operator → K8s Secrets

---

## Slide 4: Phase 1 — Terraform (20%)

- **3 GKE regional clusters** (us-central1) via modular Terraform
- Modules: vpc, gke, artifact_registry, secrets, iam
- Remote state: GCS bucket with versioning
- Constraint solved: CPUS_ALL_REGIONS=12 → sequential deployment + autoscaler min=0

---

## Slide 5: Phase 2 — K8s Migration

- StorageClass: `do-block-storage` → `standard-rwo`
- Ingress: removed → Istio Gateway (Phase 3)
- 8 services deployed, all namespaces created
- Smoke test script passes: 6/8 Running (gateway+identity built in Phase 4)

---

## Slide 6: Phase 3 — Istio Service Mesh (Bonus)

- **STRICT mTLS** across all 3 environments
- Circuit Breaker: 5 consecutive 5xx → pod ejected 30s
- Retry: 3 attempts on GET, idempotent only
- **Canary routing**: 90%/10% via VirtualService subsets
- Kiali: live service graph with mTLS lock icons

---

## Slide 7: Phase 4 — CI/CD Pipeline (15%)

| Stage | Tool | Gate |
|-------|------|------|
| Build | Gradle | Compile all 8 services |
| Code analysis | SonarQube | Quality gate must pass |
| Unit tests | JUnit + Testcontainers | 0 failures |
| Integration + E2E | JUnit + Testcontainers | 0 failures |
| Security scan | Trivy | HIGH/CRITICAL report |
| Coverage | JaCoCo | ≥60% lines |
| Deploy + Canary | kubectl + Istio | Human approval |
| Release Notes | semver.sh + gh | Auto-published |

---

## Slide 8: Phase 5 — Design Patterns (10%)

**12 existing patterns identified** including:
- API Gateway, Database per Service, Event-Driven (Kafka)
- k-Anonymity, JWT, Dual Auth Chain, Two-Hop Graph (Neo4j)

**3 new patterns implemented:**
1. **Circuit Breaker + Retry** (Istio DestinationRule/VirtualService)
2. **External Configuration** (GCP Secret Manager + ESO)
3. **Sidecar** (Istio Envoy — offloads mTLS, metrics, routing)

---

## Slide 9: Phase 6 — Testing (15%)

- **43 tests total**: 33 unit + 5 integration + 5 E2E → 100% pass rate
- JaCoCo aggregate coverage: ~67% (threshold 60%)
- OWASP ZAP baseline scan in stage pipeline (non-blocking)
- Locust performance: 21.77 RPS, 230ms median, 0% errors

---

## Slide 10: Phase 7 — Observability (10%)

| Layer | Tool | What it shows |
|-------|------|--------------|
| Metrics | Prometheus + Grafana | Request rate, latency, JVM heap, business metrics |
| Logs | Fluent Bit → Elasticsearch + Kibana | All container logs |
| Traces | Jaeger (Istio spans) | Multi-service request traces |
| Mesh | Kiali | Service graph + mTLS status |
| Alerts | PrometheusRule + Alertmanager | 5 rules → Slack |

Business metrics: `surveys_submitted_total`, `files_uploaded_total`, `notifications_sent_total`

---

## Slide 11: Phase 8 — Security (5%)

- ✅ Zero plaintext secrets (`grep password: k8s/` = 0 results)
- ✅ RBAC: each service SA reads only its own secrets
- ✅ Istio AuthorizationPolicy: default-deny + explicit allowlist
- ✅ cert-manager + Let's Encrypt TLS manifest ready
- ✅ Daily Trivy scan → Slack report

---

## Slide 12: Phase 9 — Change Management (5%)

- Conventional Commits → semver auto-bump
- Release Notes grouped by feat/fix/perf/chore/ci
- GitHub Release auto-published on every master pipeline run
- Rollback drill documented: Kubernetes rollout undo + Istio traffic revert < 2min

---

## Slide 13: Lessons Learned

**What worked well:**
- Istio handles cross-cutting concerns (mTLS, retries, canary) without touching Java code
- Terraform modules make environment creation reproducible and fast
- External Secrets Operator eliminates all plaintext credentials from Git

**What was challenging:**
- GCP quota (12 vCPU) — never run 2 full clusters simultaneously
- Istio sidecar timing → CrashLoopBackOff on pod restarts (fixed: `holdApplicationUntilProxyStarts`)
- GitHub PAT doesn't support `git push` for tags — used `gh api` instead

**What we'd change:**
- Use GKE Autopilot instead of Standard (cheaper for variable workloads)
- Implement Workload Identity (keyless) instead of JSON key for ESO
- Upgrade Spring Boot to 3.2.12+ to fix CRITICAL CVEs

---

## Slide 14: Demo Flow

1. Show running GKE cluster: `kubectl get pods -n circleguard-dev`
2. Trigger DEV pipeline → watch stages pass
3. SonarQube dashboard — quality gate green
4. Kiali — mTLS lock icons on all edges
5. Grafana — metrics flowing from all services
6. Trigger MASTER → approve canary at 10% → 100%
7. GitHub Release with auto-generated release notes
