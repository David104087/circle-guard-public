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
**Assignment:** Taller 2: Pruebas y Lanzamiento  
**Repo (fork):** https://github.com/David104087/circle-guard-public.git  
**Stack:** Spring Boot 3.2.x · Java 21 · Gradle Kotlin DSL · Docker · Jenkins · Kubernetes (DigitalOcean)

CircleGuard is a university health-monitoring platform. Six microservices communicate via Kafka and REST.

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

### Jenkins (local Docker container)
- **Container name:** `circleguard-jenkins`
- **Image:** `circleguard-jenkins:local` (built from `ci/Dockerfile.jenkins`)
- **Ports:** 8080 (UI), 50000 (agent)
- **Admin password:** `0de72cfcad744533ad0b8dca62e9b879`
- **Volume:** `jenkins_home` (persistent; survives container restarts)
- **Docker socket mount:** `/run/host-services/docker.proxy.sock → /var/run/docker.sock`
- **Start command:** `docker start circleguard-jenkins`
- **Rebuild image:** `docker build -t circleguard-jenkins:local -f ci/Dockerfile.jenkins ci/`

### Jenkins Credentials (already configured in Jenkins)
| ID | Type | Purpose |
|----|------|---------|
| `dockerhub-credentials` | UsernamePassword | Docker Hub login (`davidartunduaga`) |
| `github-token` | SecretText | GitHub API access |
| `kubeconfig-dev` | FileCredentials | DigitalOcean kubeconfig → bound as file path to `$KUBECONFIG` |
| `kubeconfig-stage` | FileCredentials | Same kubeconfig (all envs share the same DO cluster) |
| `kubeconfig-production` | FileCredentials | Same kubeconfig |

To update the kubeconfig credentials (e.g., after cluster renewal), use the Jenkins Groovy Script Console:
```groovy
import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.SystemCredentialsProvider
import com.cloudbees.plugins.credentials.domains.Domain
import org.jenkinsci.plugins.plaincredentials.impl.FileCredentialsImpl
import com.cloudbees.plugins.credentials.SecretBytes

def store = SystemCredentialsProvider.getInstance().getStore()
def domain = Domain.global()
def kubeBytes = SecretBytes.fromBytes(new File('/tmp/kube_for_jenkins.yaml').bytes)

['kubeconfig-dev','kubeconfig-stage','kubeconfig-production'].each { id ->
    def existing = store.getCredentials(domain).find { it.id == id }
    if (existing) store.removeCredentials(domain, existing)
    store.addCredentials(domain, new FileCredentialsImpl(
        CredentialsScope.GLOBAL, id, "Kubeconfig ${id}", 'kubeconfig', kubeBytes))
    println "Updated: $id"
}
```
(Copy `~/.kube/config` into the container first: `docker cp ~/.kube/config circleguard-jenkins:/tmp/kube_for_jenkins.yaml`)

### Kubernetes (DigitalOcean)
- **Cluster:** `do-nyc1-circleguard-cluster` (2 nodes, v1.34.5)
- **Namespaces:** `circleguard-dev`, `circleguard-stage`, `circleguard-production`
- **Local kubeconfig:** `~/.kube/config`
- **Access:** `kubectl get nodes` works directly from the host machine

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

To trigger a build from the CLI:
```bash
JENKINS_PASS="0de72cfcad744533ad0b8dca62e9b879"
CRUMB=$(curl -s -c /tmp/jc.txt -u "admin:$JENKINS_PASS" http://localhost:8080/crumbIssuer/api/json | python3 -c "import json,sys; print(json.load(sys.stdin)['crumb'])")
curl -s -b /tmp/jc.txt -u "admin:$JENKINS_PASS" -H "Jenkins-Crumb: $CRUMB" -X POST http://localhost:8080/job/circleguard-dev/build
```

---

## Key Technical Details

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

## Tests

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

Run locally (services must be accessible):
```bash
pip install locust
locust -f tests/performance/locustfile.py --host http://localhost:8086 \
       --users 50 --spawn-rate 5 -t 2m
# With HTML report:
locust -f tests/performance/locustfile.py --host http://localhost:8086 \
       --headless --users 100 --spawn-rate 10 -t 5m --html locust-report.html
```

### Release Notes
Script: `ci/release-notes.sh <VERSION_TAG>`  
Runs automatically in the MASTER pipeline. Generates `RELEASE_NOTES_<tag>.md` from git log since last tag.

---

## Current State (as of 2026-05-04)

### Completed
- [x] Jenkins configured (Docker container, credentials, 3 pipeline jobs)
- [x] Kubernetes cluster configured (DigitalOcean, 3 namespaces, all manifests in `k8s/`)
- [x] Dockerfiles for all 6 services (pre-built JAR pattern)
- [x] All unit tests written and passing in Jenkins (build 11, 12)
- [x] Integration tests written for all 6 services
- [x] E2E tests written for all 6 services
- [x] Locust performance test file (`tests/performance/locustfile.py`)
- [x] Release notes script (`ci/release-notes.sh`)
- [x] DEV pipeline: Unit Tests ✓, Docker Build & Push ✓ (build 12)
- [x] Docker images pushed to Hub: `davidartunduaga/circleguard-{auth,dashboard,file,form,notification,promotion}:12`

### Pending / In Progress
- [ ] DEV build 13: K8s Deploy to DEV must succeed (kubeconfig credentials fixed — was StringCredentials, now FileCredentials)
- [ ] STAGE pipeline: Run for the first time (integration tests + K8s stage deploy)
- [ ] MASTER pipeline: Run for the first time (all tests + K8s production deploy + release notes)
- [ ] Locust tests: Run manually and capture HTML report
- [ ] Screenshots for documentation (see Screenshots section below)

---

## Screenshots Needed for Documentation

The workshop requires screenshots of each pipeline. Here is where to take them:

### Section 1 – Jenkins/Docker/K8s setup
- Jenkins UI at `http://localhost:8080` — show job list and credentials page
- `kubectl get nodes` and `kubectl get namespaces` output

### Section 2 – DEV pipeline
- Build 13 (or latest green build): Stage view showing all stages green
- Unit test results: Jenkins > circleguard-dev > Latest Build > Test Results
- Docker Hub: `hub.docker.com/r/davidartunduaga/circleguard-auth/tags` showing pushed tags

### Section 3 – Tests
- JUnit test results for each service (Jenkins test results panel)
- Locust HTML report (`locust-report.html`) showing RPS, response times, failure rate
- For integration tests: promotion-service logs showing Neo4j + Redis containers starting

### Section 4 – STAGE pipeline
- Stage view of `circleguard-stage` job — all stages green
- Integration test results
- `kubectl get pods -n circleguard-stage` showing running pods

### Section 5 – MASTER pipeline
- Stage view of `circleguard-master` job — all stages green
- `RELEASE_NOTES_v*.md` file contents
- `kubectl get pods -n circleguard-production` showing running pods

---

## K8s Manifests Layout

```
k8s/
  00-namespaces.yaml          # Creates dev/stage/production namespaces
  infrastructure/             # Kafka, Zookeeper, Postgres, Redis, Neo4j, Mailhog
  dev/                        # Per-service Deployment+Service+ConfigMap+Secret for dev
  stage/                      # Same for stage
  production/                 # Same for production
```

Infrastructure manifests cover both dev and stage namespaces (resources are namespace-scoped).
Production manifests in `k8s/production/` are applied by the MASTER pipeline.
