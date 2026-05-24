# CircleGuard – Agile Management

## GitHub Projects Board

**Board:** CircleGuard Proyecto Final
**URL:** https://github.com/users/David104087/projects/1
**Columns:** Backlog · To Do · In Progress · Review · Done
**Repository:** https://github.com/David104087/circle-guard-public

---

## User Stories

All user stories are created as GitHub Issues in the fork repository with phase labels.

| ID | GitHub Issue | Phase | Title |
|----|-------------|-------|-------|
| US-01 | [#1](https://github.com/David104087/circle-guard-public/issues/1) | Phase 1 | Provision reproducible GCP infrastructure via Terraform |
| US-02 | [#2](https://github.com/David104087/circle-guard-public/issues/2) | Phase 2 | Migrate K8s manifests to GKE |
| US-03 | [#3](https://github.com/David104087/circle-guard-public/issues/3) | Phase 3 | Secure all inter-service communication with Istio mTLS |
| US-04 | [#4](https://github.com/David104087/circle-guard-public/issues/4) | Phase 4 | Enhanced CI/CD pipeline with quality gates and canary deployments |
| US-05 | [#5](https://github.com/David104087/circle-guard-public/issues/5) | Phase 5 | Implement and document design patterns (resilience, config, sidecar) |
| US-06 | [#6](https://github.com/David104087/circle-guard-public/issues/6) | Phase 6 | Coverage reports and OWASP ZAP security scans in pipeline |
| US-07 | [#7](https://github.com/David104087/circle-guard-public/issues/7) | Phase 7 | Full observability stack (Prometheus, Grafana, ELK, Jaeger) |
| US-08 | [#8](https://github.com/David104087/circle-guard-public/issues/8) | Phase 8 | Secrets managed via GCP Secret Manager with RBAC and TLS |
| US-09 | [#9](https://github.com/David104087/circle-guard-public/issues/9) | Phase 9 | Automated release notes and rollback runbooks |
| US-10 | [#10](https://github.com/David104087/circle-guard-public/issues/10) | Phase 10 | Complete documentation enabling a new developer to onboard independently |

---

## Sprint Definitions

### Sprint 1 — Infrastructure & Deployment

**Goal:** Provision the GCP/GKE environment, migrate existing manifests, and establish the service mesh foundation.
**Duration:** 2 weeks (Semana 1–2 of Proyecto Final)
**Scope:** Phases 0, 1, 2, 3

| Issue | US | Story Points | Status |
|-------|----|-------------|--------|
| [#1](https://github.com/David104087/circle-guard-public/issues/1) | US-01 | 13 | Backlog |
| [#2](https://github.com/David104087/circle-guard-public/issues/2) | US-02 | 8 | Backlog |
| [#3](https://github.com/David104087/circle-guard-public/issues/3) | US-03 | 13 | Backlog |

**Sprint 1 Definition of Done:**
- Three GKE clusters (dev/stage/prod) provisioned via Terraform and reachable with `kubectl`.
- All 8 microservices Running in each namespace (6 running now; gateway+identity images built in Phase 4).
- Istio mTLS STRICT mode enforced; Kiali graph shows lock icons on all edges.
- Smoke test script `ci/smoke-test.sh` passes against all three environments.

---

### Sprint 2 — Quality, Security & Observability

**Goal:** Harden the system with quality gates, observability, security controls, and finalize documentation.
**Duration:** 2 weeks (Semana 3–4 of Proyecto Final)
**Scope:** Phases 4, 5, 6, 7, 8, 9, 10

| Issue | US | Story Points | Status |
|-------|----|-------------|--------|
| [#4](https://github.com/David104087/circle-guard-public/issues/4) | US-04 | 13 | Backlog |
| [#5](https://github.com/David104087/circle-guard-public/issues/5) | US-05 | 8 | Backlog |
| [#6](https://github.com/David104087/circle-guard-public/issues/6) | US-06 | 8 | Backlog |
| [#7](https://github.com/David104087/circle-guard-public/issues/7) | US-07 | 13 | Backlog |
| [#8](https://github.com/David104087/circle-guard-public/issues/8) | US-08 | 8 | Backlog |
| [#9](https://github.com/David104087/circle-guard-public/issues/9) | US-09 | 5 | Backlog |
| [#10](https://github.com/David104087/circle-guard-public/issues/10) | US-10 | 5 | Backlog |

**Sprint 2 Definition of Done:**
- All pipelines include SonarQube + Trivy; master pipeline performs canary deployment.
- JaCoCo coverage ≥ 60% published to Jenkins; ZAP scan archives report in pipeline.
- Prometheus/Grafana/ELK/Jaeger stack running; dashboards show live data for all 8 services.
- No plaintext secrets in `k8s/`; RBAC enforced per service; TLS on public endpoints.
- GitHub Release created automatically with parsed release notes on master pipeline run.
- `README.md` and all `docs/` deliverables complete per `Workshop_statement.md § Entregables`.
