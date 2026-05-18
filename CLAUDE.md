# CircleGuard – CLAUDE.md

Project and operational context for AI-assisted development on this repository.

---

## RULES (NEVER VIOLATE)

1. **No AI mentions in git commits.** Never add `Co-Authored-By: Claude`, `Generated with Claude Code`, or any similar line to commit messages or PR descriptions. Commits must appear as normal human commits.
2. **Only push to the fork.** The working remote is `https://github.com/David104087/circle-guard-public.git`. Never push or open PRs toward the upstream (original) repository.
3. **Working branch is `master`.** All CI pipelines checkout `master`.

---

## Project Overview

**Course:** SE5 – Software Engineering 5, Semestre 8
**Current Assignment:** Proyecto Final IngeSoft V (see `Workshop_statement.md` for full requirements)
**Previous Assignment:** Taller 2: Pruebas y Lanzamiento (completed — tests, pipelines, release notes)
**Repo (fork):** https://github.com/David104087/circle-guard-public.git
**Stack:** Spring Boot 3.2.x · Java 21 · Gradle Kotlin DSL · Docker · Jenkins · Kubernetes (GCP/GKE) · Terraform

CircleGuard is a university health-monitoring platform. Six microservices communicate via Kafka and REST.

> **Infrastructure migration:** The project has moved from DigitalOcean to **Google Cloud Platform (GCP)**.
> The Kubernetes cluster is now GKE. All new `k8s/` manifests and Terraform code target GCP.
> DigitalOcean kubeconfig references in the old Jenkinsfiles are obsolete.

---

## The Six Microservices

| Service | Port | Description |
|---------|------|-------------|
| `circleguard-auth-service` | 8180 | JWT authentication, LDAP integration |
| `circleguard-dashboard-service` | 8084 | Geospatial hotspot analytics (k-anonymity / privacy-preserving) |
| `circleguard-file-service` | 8085 | Secure certificate and document storage (S3-compatible) |
| `circleguard-form-service` | 8086 | Health survey forms, Kafka producer |
| `circleguard-notification-service` | 8082 | Email and alert notifications, Kafka consumer |
| `circleguard-promotion-service` | 8088 | Health status lifecycle management (Neo4j + Redis) |

Docker Hub image prefix: `davidartunduaga/circleguard-{auth,dashboard,file,form,notification,promotion}`

---

## Infrastructure

### Cloud Provider: Google Cloud Platform (GCP)

- **Project:** TBD (classmate's GCP project — get Owner role on it)
- **Region:** `us-central1` (preferred for cost)
- **Kubernetes:** GKE (Google Kubernetes Engine)
- **Namespaces:** `circleguard-dev`, `circleguard-stage`, `circleguard-production`
- **Terraform state backend:** GCS bucket (`gs://circle-guard-tfstate-XXXXX/`)
- **Container registry:** Artifact Registry (GCP) or Docker Hub (already configured)
- **Secrets:** GCP Secret Manager
- **Local kubeconfig:** `~/.kube/config` (generated via `gcloud container clusters get-credentials`)

#### GCP APIs required
```
container.googleapis.com        # GKE
compute.googleapis.com          # VMs, Load Balancers
artifactregistry.googleapis.com # Container images
storage.googleapis.com          # GCS / Terraform state
secretmanager.googleapis.com    # Secrets
cloudresourcemanager.googleapis.com
iamcredentials.googleapis.com
```

#### Terraform Service Account setup
```bash
gcloud iam service-accounts create terraform-sa \
  --display-name="Terraform Service Account" --project=PROJECT_ID

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:terraform-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/editor"

gcloud iam service-accounts keys create ~/terraform-key.json \
  --iam-account=terraform-sa@PROJECT_ID.iam.gserviceaccount.com
```

### Jenkins (local Docker container — unchanged from Taller 2)
- **Container name:** `circleguard-jenkins`
- **Image:** `circleguard-jenkins:local` (built from `ci/Dockerfile.jenkins`)
- **Ports:** 8080 (UI), 50000 (agent)
- **Admin password:** `0de72cfcad744533ad0b8dca62e9b879`
- **Volume:** `jenkins_home` (persistent; survives container restarts)
- **Docker socket mount:** `/run/host-services/docker.proxy.sock → /var/run/docker.sock`
- **Start command:** `docker start circleguard-jenkins`
- **Rebuild image:** `docker build -t circleguard-jenkins:local -f ci/Dockerfile.jenkins ci/`

### Jenkins Credentials (update kubeconfig credentials to GKE)
| ID | Type | Purpose |
|----|------|---------|
| `dockerhub-credentials` | UsernamePassword | Docker Hub login (`davidartunduaga`) |
| `github-token` | SecretText | GitHub API access |
| `gcp-service-account-key` | SecretFile | GCP service account JSON key for Terraform + kubectl |
| `kubeconfig-dev` | FileCredentials | GKE kubeconfig for dev namespace |
| `kubeconfig-stage` | FileCredentials | GKE kubeconfig for stage namespace |
| `kubeconfig-production` | FileCredentials | GKE kubeconfig for production namespace |

To update kubeconfig credentials after cluster creation:
```bash
gcloud container clusters get-credentials CLUSTER_NAME --region us-central1 --project PROJECT_ID
docker cp ~/.kube/config circleguard-jenkins:/tmp/kube_for_jenkins.yaml
```
Then use the Jenkins Groovy Script Console (same script as before) to update `kubeconfig-dev/stage/production`.

---

## Terraform Layout (Proyecto Final)

```
terraform/
  modules/
    gke/          # GKE cluster definition
    vpc/          # VPC, subnets, firewall rules
    gcs/          # Buckets (Terraform state, file-service storage)
    dns/          # Cloud DNS (optional)
  envs/
    dev/          # dev.tfvars + main.tf calling modules
    stage/        # stage.tfvars + main.tf
    prod/         # prod.tfvars + main.tf
  backend.tf      # GCS remote state config
```

---

## CI/CD Pipelines

| Pipeline | Jenkinsfile | Jenkins Job | Trigger |
|----------|-------------|-------------|---------|
| DEV | `ci/Jenkinsfile.dev` | `circleguard-dev` | push to any non-main branch |
| STAGE | `ci/Jenkinsfile.stage` | `circleguard-stage` | push to main / manual |
| MASTER | `ci/Jenkinsfile.master` | `circleguard-master` | manual / tag |

### DEV pipeline stages
1. Checkout → 2. Build All Services → 3. Setup Docker Proxy → 4. Unit Tests (parallel, 6 services) → 5. Docker Build & Push → 6. Deploy to K8s DEV

### STAGE pipeline stages
1. Checkout → 2. Build → 3. Docker Proxy → 4. Unit Tests → 5. Integration Tests → 6. Docker Push → 7. Deploy to K8s STAGE

### MASTER pipeline stages
1. Checkout → 2. Build → 3. Docker Proxy → 4. Unit Tests → 5. Integration Tests → 6. E2E Tests → 7. Docker Push → 8. Deploy to K8s PRODUCTION → 9. Generate Release Notes

### Proyecto Final additions to pipelines
- SonarQube analysis stage (after build)
- Trivy vulnerability scan stage (after Docker build)
- Semantic versioning (auto-tag via `ci/semver.sh`)
- Slack/email notifications on failure
- Manual approval gate before PRODUCTION deploy

To trigger a build from the CLI:
```bash
JENKINS_PASS="0de72cfcad744533ad0b8dca62e9b879"
CRUMB=$(curl -s -c /tmp/jc.txt -u "admin:$JENKINS_PASS" http://localhost:8080/crumbIssuer/api/json | python3 -c "import json,sys; print(json.load(sys.stdin)['crumb'])")
curl -s -b /tmp/jc.txt -u "admin:$JENKINS_PASS" -H "Jenkins-Crumb: $CRUMB" -X POST http://localhost:8080/job/circleguard-dev/build
```

---

## Key Technical Details (carried over from Taller 2)

### Docker API Version Proxy
Jenkins runs inside Docker (DooD). The `docker-java` library (used by Testcontainers) hardcodes `/v1.32/` API paths. Docker 29.x requires minimum API 1.44.

**Fix:** `ci/docker-version-proxy.py` — a Unix-socket proxy that rewrites every HTTP request line from `/v1.XX/` to `/v1.44/`. It listens on `/tmp/docker-proxy.sock` and forwards to `/var/run/docker.sock`.

The proxy rewrites **every chunk** per TCP connection (HTTP/1.1 keep-alive sends multiple requests per connection — rewriting only the first chunk caused 400 errors).

Required environment variables for tests:
```
DOCKER_HOST=unix:///tmp/docker-proxy.sock
TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/tmp/docker-proxy.sock
TESTCONTAINERS_RYUK_DISABLED=true
DOCKER_API_VERSION=1.44
TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal
```

Also write `~/.testcontainers.properties`:
```
docker.host=unix:///tmp/docker-proxy.sock
ryuk.disabled=true
host.override=host.docker.internal
```

### DooD Networking for Testcontainers
Jenkins runs inside Docker. Testcontainers starts containers (Neo4j, Redis) on the **host** Docker daemon. `localhost` inside Jenkins ≠ Docker host. The mapped ports ARE reachable via `host.docker.internal` → `192.168.65.254` (Docker Desktop macOS gateway).

Setting `TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal` fixes the `ContainerLaunchException` / `HostPortWaitStrategy` timeout.

### Dockerfiles (Pre-Built JAR Pattern)
All 6 service Dockerfiles use a single-stage build that copies the pre-compiled JAR from the Jenkins workspace. This reduces Docker build time from ~2 min to ~30 sec per service.
```dockerfile
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY services/circleguard-{svc}-service/build/libs/*.jar app.jar
EXPOSE {port}
ENTRYPOINT ["java","-jar","app.jar"]
```
The `./gradlew bootJar` compilation happens in the **Build All Services** stage, before Docker build.

---

## Tests (completed in Taller 2 — reusable as-is)

### Test Files Per Service
| Service | Unit | Integration | E2E |
|---------|------|-------------|-----|
| auth-service | JwtTokenServiceTest, LoginControllerTest | AuthLoginIntegrationTest | AuthLoginE2ETest |
| dashboard-service | AnalyticsServiceTest, KAnonymityFilterTest, AnalyticsControllerTest | DashboardIntegrationTest | DashboardAnalyticsE2ETest |
| file-service | FileStorageServiceTest, FileUploadControllerTest | FileUploadIntegrationTest | FileUploadDownloadE2ETest |
| form-service | HealthSurveyServiceTest, SymptomMapperTest, HealthSurveyControllerTest, QuestionnaireControllerTest, AttachmentControllerTest | FormKafkaIntegrationTest | HealthSurveyE2ETest |
| notification-service | TemplateServiceTest, NotificationDispatcherTest, PriorityAlertListenerTest, ExposureNotificationListenerTest, NotificationRetryTest, LmsServiceTest, RoomReservationServiceTest | NotificationKafkaIntegrationTest | (included in notification integration) |
| promotion-service | HealthStatusServiceTest, FloorServiceTest, HealthStatusReevaluationTest, StatusLifecycleTest, AdministrativeCorrectionTest, SurveyListenerTest, HealthStatusControllerTest | (uses Neo4j + Redis Testcontainers) | PromotionStatusE2ETest |

### Performance Tests (Locust)
File: `tests/performance/locustfile.py`

Results from Taller 2: 2,558 requests, 21.77 RPS, 230ms median, 0% failure rate on all endpoints except GET /surveys/pending (to be investigated).

### New for Proyecto Final: Security Tests (OWASP ZAP)
To be added in `tests/security/`. Run against dev environment after deployment.

### Release Notes
Script: `ci/release-notes.sh <VERSION_TAG>`
Runs automatically in the MASTER pipeline. Generates `RELEASE_NOTES_<tag>.md` from git log since last tag.

---

## K8s Manifests Layout

```
k8s/
  00-namespaces.yaml          # Creates dev/stage/production namespaces
  infrastructure/             # Kafka, Zookeeper, Postgres, Redis, Neo4j, Mailhog
  dev/                        # Per-service Deployment+Service+ConfigMap+Secret for dev
  stage/                      # Same for stage
  production/                 # Same for production
  monitoring/                 # Prometheus, Grafana, ELK, Jaeger (Proyecto Final)
```

Infrastructure manifests cover both dev and stage namespaces (resources are namespace-scoped).
Production manifests in `k8s/production/` are applied by the MASTER pipeline.

> GKE-specific: LoadBalancer Services get a GCP external IP automatically.
> Ingress uses `kubernetes.io/ingress.class: "gce"` annotation instead of nginx (unless nginx ingress controller is installed).
