# 🛡️ CircleGuard Monorepo

**Absolute Privacy. High-Speed Containment. Secure Campus.**

CircleGuard is a state-of-the-art university contact tracing and fencing system designed to identify interconnected contact groups ("Circles") and apply rapid health fences while preserving individual anonymity.

---

## 🌟 Vision & Mission

Our vision is a university campus where health containment speed outpaces lab confirmation timelines without compromising student privacy. CircleGuard leverages campus-native intelligence—class schedules and WiFi infrastructure—to deliver a human-validated, graph-based protection ecosystem.

### Key Differentiators
- **Privacy-as-Code**: Zero real-name exposure outside a secure Health Center vault.
- **Recursive Containment**: Status promotion cascades (Suspect → Probable → Confirmed) that trigger in milliseconds.
- **Campus Integration**: Smart check-ins using existing WiFi AP triangulation and Bluetooth Low Energy (BLE).

---

## 📊 Success Metrics

| Metric | Target | Measurement |
|:---|:---|:---|
| **Containment Speed** | < 60 Seconds | Automated test of promotion engine cascade |
| **Privacy Compliance** | 100% Anonymity | Penetration test on graph database (Zero real names) |
| **Check-in Adoption** | > 70% | Analytics on scheduled class contact validation |
| **False Positive Rate** | < 15% | Post-fence surveys of actual vs. suspected contact |
| **System Uptime** | 99.5% | 7:00 AM – 10:00 PM (Academic Peak Hours) |

---

## 🏗️ Architecture Overview

CircleGuard follows a **Microservice Architecture** built on a **Hybrid Data Model**.

### Core Engine
1. **Status Promotion Machine**: Uses **Neo4j** for recursive graph traversals to identify contacts within a 14-day temporal window.
2. **Anonymization Vault**: A segregated **PostgreSQL** vault handles salted-hash identity mapping, compliant with **FERPA** regulations.
3. **Event-Driven Core**: **Apache Kafka** manages asynchronous status changes, audit logs, and notification dispatches.

### Services Directory
- **Auth Service**: Dual-chain LDAP (University) / Local (Guest) auth with Dynamic RBAC.
- **Identity Service**: Cryptographic vault for anonymizing real identities.
- **Promotion Service**: The status engine (Recursive Graph Processing).
- **Notification Service**: Multi-channel dispatcher (Push/Email/SMS).
- **Form Service**: Dynamic health questionnaire engine.
- **Gateway Service**: Campus entry validation via signed, time-limited QR tokens.
- **Dashboard Service**: Geospatial hotspot analytics (Privacy-preserving).
- **File Service**: Secure certificate and document storage (S3-compatible).

---

## 🛠️ Technical Stack

| Layer | Technology | Rationale |
|:---|:---|:---|
| **Backend** | Spring Boot 4 / Java 21 | Enterprise-grade maturity & low-latency Jakarta EE support. |
| **Graph DB** | Neo4j 5.26 | High-performance recursive traversals unreachable with SQL. |
| **Relational DB**| PostgreSQL 16 | ACID compliant storage for identity and configuration. |
| **Message Bus** | Apache Kafka 7.6 | Persistent, audit-trailed event log for status dispatches. |
| **Caching** | Redis 7.2 | L2 distributed cache for rapid entry-gate status validation. |
| **Mobile/Web** | Expo (React Native) | Unified codebase across iOS, Android, and Browser. |
| **Infra** | Kubernetes | Orchestration for high availability and auto-scaling. |

---

## 🗺️ Roadmap

### Phase 1: MVP — The Intelligence Core (Current)
- [x] Status Promotion Machine (Suspect → Probable → Confirmed).
- [x] Temporal graph with 14-day TTL edges.
- [x] Multi-channel fence notifications (Push/Email/SMS).
- [ ] Health Center de-identification console.

### Phase 2: Growth — Spatial Intelligence
- [ ] WiFi AP triangulation integration.
- [ ] Campus entry validation (Gatekeeper) QR integration.
- [ ] LMS integration for "Remote Attendance" status automation.

### Phase 3: Vision — Full Ecosystem
- [ ] Off-campus circle detection via P2P Bluetooth.
- [ ] Global Health Dashboard with hotspot visualization.
- [ ] Lab API bridge for automated test result ingestion.

---

## 💻 Local Development

### 1. Infrastructure
Ensure Docker is installed, then start the middleware stack:
```bash
docker-compose -f docker-compose.dev.yml up -d
```
*Middleware includes: PostgreSQL, Neo4j, Kafka, Zookeeper, Redis, and OpenLDAP.*

### 2. Build & Run
CircleGuard uses Gradle for parallel builds across services:
```bash
# Start all microservices in parallel
./gradlew bootRun --parallel

# Start a specific service
./gradlew :services:<service-name>:bootRun
```

### 3. API Exploration
Every service exposes an OpenAPI 3.0 interface. Once running, visit:
`http://localhost:<service-port>/swagger-ui/index.html`

---

## 📱 Frontend Development

The frontend is built using **Expo (React Native)**, supporting iOS, Android, and Web from a single codebase located in `/mobile`.

### 1. Prerequisites
Ensure you have Node.js installed and dependencies loaded:
```bash
cd mobile
npm install
```

### 2. Run the Application
You can run the app in various modes depending on your target platform:

| Platform | Command | Notes |
|:---|:---|:---|
| **Development Menu** | `npm run start` | Opens the Expo Go start-up menu. |
| **Android** | `npm run android` | Requires Android Studio / Emulator or a connected device. |
| **iOS** | `npm run ios` | Requires macOS with Xcode / Simulator installed. |
| **Web Browser** | `npm run web` | Launches the dashboard/app in your default browser. |

### 3. Testing
To run frontend unit and component tests:
```bash
npm run test
```

---

## 🧪 Testing

We maintain high system integrity via multi-level testing:

| Command | Scope |
|:---|:---|
| `./gradlew test` | Full system suite (Unit + Integration) |
| `./gradlew :services:<name>:test` | Single service testing |

**Note**: Integration tests use **Testcontainers** to spawn ephemeral Neo4j and PostgreSQL instances for zero-side-effect validation.

---

## 🔐 Privacy & Compliance

- **FERPA Compliance**: Student identities are never stored in the contact graph.
- **Right to be Forgotten**: Users can trigger complete data purging via the Identity Vault.
- **Temporal Privacy**: All contact edges are automatically purged after 14 days.

---

## Infrastructure & Deployment (Proyecto Final SE5)

> The project has been migrated from DigitalOcean to **Google Cloud Platform (GKE)** with full Terraform automation, Istio service mesh, and a complete CI/CD pipeline.

### Quick Start

**1. Provision infrastructure**
```bash
# Requires: gcloud, terraform >= 1.6, kubectl >= 1.28
cd terraform/envs/dev
terraform init && terraform apply -auto-approve
gcloud container clusters get-credentials circleguard-dev --region us-central1 --project tallerfinal-496702
```
See [terraform/README.md](terraform/README.md) for full details.

**2. Deploy to Kubernetes**
```bash
kubectl apply -f k8s/00-namespaces.yaml
kubectl apply -f k8s/infrastructure/
kubectl apply -f k8s/dev/
kubectl apply -f k8s/dev/external-secrets/  # requires ESO installed
```

**3. Run pipelines**
```bash
# Start Jenkins + SonarQube
docker start circleguard-jenkins sonarqube
docker exec --user root circleguard-jenkins chmod 666 /var/run/docker.sock
# Trigger dev pipeline via Jenkins UI: http://localhost:8080/job/circleguard-dev/
```

### Development

```bash
# Build all services
./gradlew build -x test

# Run all tests
./gradlew test

# Coverage report
./gradlew aggregateCoverageReport
# HTML: build/reports/jacoco-aggregate/html/index.html

# SonarQube analysis
./gradlew sonar -Dsonar.host.url=http://localhost:9000 -Dsonar.token=<token>
```

### Accessing Dashboards

| Tool | Command | URL |
|------|---------|-----|
| Grafana | `kubectl port-forward svc/kube-prometheus-grafana -n monitoring 3000:80` | http://localhost:3000 |
| Prometheus | `kubectl port-forward svc/kube-prometheus-kube-prome-prometheus -n monitoring 9090:9090` | http://localhost:9090 |
| Jaeger | `kubectl port-forward svc/jaeger-query -n istio-system 16686:16686` | http://localhost:16686 |
| Kibana | `kubectl port-forward svc/kibana -n logging 5601:5601` | http://localhost:5601 |
| Kiali | `istioctl dashboard kiali` | Auto-opened |
| Jenkins | — | http://localhost:8080 |

### Documentation

| Topic | Document |
|-------|---------|
| Architecture | [docs/diagrams/architecture.md](docs/diagrams/architecture.md) |
| Terraform | [terraform/README.md](terraform/README.md) |
| Operations index | [docs/operations/README.md](docs/operations/README.md) |
| Observability | [docs/operations/observability.md](docs/operations/observability.md) |
| Rollback | [docs/operations/rollback.md](docs/operations/rollback.md) |
| Security | [docs/operations/security.md](docs/operations/security.md) |
| Design Patterns | [docs/patterns/README.md](docs/patterns/README.md) |
| Test inventory | [docs/operations/test-inventory.md](docs/operations/test-inventory.md) |
