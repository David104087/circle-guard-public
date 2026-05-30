# CircleGuard — Video Demo Script (20–30 min)

---

## Minute 0–2: Introduction

**Show:** GitHub repo front page (README.md)

> "CircleGuard is a university health monitoring platform built as 8 Spring Boot microservices. For the Proyecto Final of SE5, we migrated it from DigitalOcean to Google Cloud Platform, added a full CI/CD pipeline, service mesh, observability stack, and security layer. I'll walk you through each component."

---

## Minute 2–5: Architecture Overview

**Show:** `docs/diagrams/architecture.md` — system diagram

> "The 8 services communicate via Kafka for async events and REST for sync calls. Everything runs on GKE with Istio as the service mesh. Terraform provisions the full infrastructure — 3 environments: dev, stage, production."

**Show:** `terraform/` folder structure, `terraform/README.md`

> "Terraform modules for VPC, GKE clusters, Secret Manager, IAM service accounts. One `terraform apply` provisions a complete environment in under 5 minutes."

---

## Minute 5–10: CI/CD Pipeline Demo

**Show:** Jenkins at http://localhost:8080

> "Three pipelines: DEV triggers on feature branches, STAGE on master, MASTER with manual canary approval."

**Show:** `ci/Jenkinsfile.dev` pipeline stages

> "DEV pipeline: Checkout → Build → SonarQube → Unit Tests (parallel, 6 services) → Coverage Report (60% threshold) → Docker Build + Trivy scan → Push to Docker Hub → Deploy to GKE dev."

**Show:** Last successful DEV build #26 in Jenkins — all stages green

**Show:** `ci/Jenkinsfile.master` — canary section

> "The MASTER pipeline adds Integration + E2E tests, then deploys a canary: 10% of traffic goes to the new version via Istio. I approve here in Jenkins — then 100% promoted."

**Show:** Build #10/#11 — canary stage with "Promote to 100%" button

---

## Minute 10–14: SonarQube + Quality Gates

**Show:** http://localhost:9000 — SonarQube dashboard

> "SonarQube analyzes all 8 services. Quality gate must pass for the pipeline to continue. 67% code coverage, 0 critical issues."

**Show:** One service dashboard in SonarQube (e.g., auth-service)

---

## Minute 14–18: Kubernetes + Istio

**Show:** `kubectl get pods -n circleguard-dev`

> "All pods show 2/2 — one container is the app, the other is the Istio Envoy sidecar. The sidecar handles mTLS, circuit breaking, retries, and metrics without changing any Java code."

**Show:** `k8s/istio/peer-authentication.yaml`

> "STRICT mTLS enforced — plain HTTP calls rejected inside the mesh."

**Show:** `k8s/istio/destination-rules.yaml` — circuit breaker config

> "Circuit breaker with outlier detection: if a pod returns 5 consecutive 5xx errors in 30 seconds, it's automatically ejected from the load balancer pool."

**Show (if cluster active):** `istioctl dashboard kiali` — service graph with mTLS lock icons

---

## Minute 18–22: Observability

**Show:** Grafana dashboard (port-forward)

> "kube-prometheus-stack gives us metrics from all 8 services via Spring Boot Actuator. Request rate, error rate, p95 latency, JVM heap — all visible without touching the application code."

**Show:** PrometheusRule alerts in `k8s/monitoring/alerting-rules.yaml`

> "5 alerting rules: crash loop, high latency, high error rate, JVM heap, PVC fullness. Alerts go to Slack via Alertmanager."

**Show:** `docs/operations/observability.md` — useful PromQL queries

---

## Minute 22–25: Security

**Show:** `kubectl get externalsecrets -n circleguard-dev`

> "External Secrets Operator syncs secrets from GCP Secret Manager. Zero plaintext credentials in any YAML file in the repository."

**Show:** `grep -rE "password:|secret:" k8s/` — zero results

> "The acceptance criteria passes — no plaintext secrets anywhere."

**Show:** `k8s/dev/rbac/rbac.yaml` — one ServiceAccount block

> "Each microservice has its own ServiceAccount with Role access only to its specific secrets. auth-service can read jwt-secret and db-password; it cannot read neo4j-credentials or vault-secret."

**Show:** `k8s/istio/authorization-policies.yaml`

> "Istio AuthorizationPolicy with default-deny. Only explicitly allowed edges work: gateway → auth, auth → identity, dashboard → promotion. Everything else is blocked at the mesh layer."

---

## Minute 25–27: Design Patterns

**Show:** `docs/patterns/README.md`

> "We identified 12 existing patterns and implemented 3 new ones: Circuit Breaker + Retry via Istio, External Configuration via GCP Secret Manager + ESO, and the Sidecar pattern via Istio Envoy injection."

**Show:** `docs/patterns/existing.md` — k-Anonymity entry

> "The most interesting existing pattern is k-Anonymity — dashboard-service suppresses hotspot metrics for groups smaller than k=5, preventing individual re-identification."

---

## Minute 27–29: Lessons Learned

**Show:** `docs/lessons-learned.md`

> "The biggest challenge was GCP quota management — 12 vCPU limit means we can never run all 3 clusters simultaneously. We solved this with autoscaler min=0 and terraform destroy for overnight."

> "Istio's sidecar timing issue caused CrashLoopBackOff on pod restarts — the app connects to PostgreSQL before Envoy is ready. The fix is `holdApplicationUntilProxyStarts: true`."

---

## Minute 29–30: Conclusion

> "To summarize: CircleGuard runs on GKE with 3 environments, full CI/CD with canary deployments, Istio service mesh with mTLS, Prometheus/Grafana/Jaeger observability, GCP Secret Manager for secrets, RBAC for least privilege, and OWASP ZAP security testing. All phases of the Proyecto Final are complete."

**Show:** `CLAUDE.md` — implementation plan with all phases green ✅
