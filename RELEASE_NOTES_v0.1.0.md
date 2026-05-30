# Release Notes – CircleGuard v0.1.0

**Release Date:** 2026-05-30 21:38 UTC
**Environment:** Production
**Docker Hub:** `davidartunduaga/circleguard-*:v0.1.0`

---

## Deployed Services

| Service | Port | Image Tag |
|---------|------|-----------|
| auth-service | 8180 | `v0.1.0` |
| dashboard-service | 8084 | `v0.1.0` |
| file-service | 8085 | `v0.1.0` |
| form-service | 8086 | `v0.1.0` |
| gateway-service | 8087 | `v0.1.0` |
| identity-service | 8083 | `v0.1.0` |
| notification-service | 8082 | `v0.1.0` |
| promotion-service | 8088 | `v0.1.0` |

---

## Changes in this Release

### New Features

- feat(phase-10): architecture diagrams, README operational sections, operations index, costs, test results, release index, video script, slides, lessons learned (#22)
- feat(phase-9): release notes grouped by CC type, CM process doc, rollback runbook, versioning convention (#21)
- feat(phase-8): RBAC, AuthorizationPolicies, secrets to SecretManager, cert-manager TLS, daily Trivy scan, security review (#20)
- feat(phase-7): observability stack — Prometheus/Grafana, Jaeger, Fluent Bit, alerting rules, health probes, business metrics, Actuator (#19)
- feat(phase-6): JaCoCo aggregate, ZAP baseline, coverage+ZAP pipeline stages, test inventory, Locust GKE — Phase 6 done (#18)
- feat(phase-5): install ESO, ClusterSecretStore + ExternalSecrets for all 3 envs — task 5.3 complete, Phase 5 done
- feat(phase-5): add pattern docs (existing, resilience, sidecar, README) — tasks 5.1 5.2 5.4 5.5
- feat(phase-4): implement CI/CD advanced pipeline with SonarQube, Trivy, canary, and semver (#13)
- feat(phase-3): Istio service mesh - mTLS, circuit breaker, canary, Kiali
- feat(phase-2): K8s migration from DigitalOcean to GKE with 8 microservices
- feat(phase-1): complete GKE infrastructure provisioning for all 3 environments
- feat(phase-1): add Terraform modules and all three environment configs
- feat(ops): add Rule 6 - auto-run session scripts on start/stop signals
- feat(ops): add session-start/stop scripts for GCP cost management
- feat(phase-0): complete GCP setup, GitHub Projects board, and user stories
- feat(phase-0): mark task 0.4 complete - all local tooling installed
- feat(phase-0): scaffold repo structure, branching strategy, and user stories
- feat: Add QA project initialization and metrics calculation scripts

### Bug Fixes

- fix(ci): replace git push with gh api for tag creation in release notes (#17)
- fix(ci): use x-access-token format for git push in release notes stage (#16)
- fix(ci): add gateway+identity to master pipeline docker build and deploy loops (#15)
- fix(ci): add gateway and identity services to docker build loop and deploy restart (#14)
- fix(ci): fix bash 3.x incompatibility in session-stop.sh - replace case sensitive expansion with case statement
- fix(ci): add USE_GKE_GCLOUD_AUTH_PLUGIN env for deploy stage
- fix(ci): make trivy fully non-blocking - known CVEs from spring-boot 3.2.4 tomcat 10.1.19
- fix(ci): make trivy HIGH non-blocking, only CRITICAL fails pipeline; fix docker socket in session-start
- fix(sonar): correct source/test paths from kotlin to java for all 8 services
- fix(terraform): add pd-standard node_config to cluster to fix initial pool SSD quota
- fix(terraform): change upgrade_settings to max_surge=0 to avoid SSD quota issues
- fix(ops): rewrite session scripts for bash 3.x compatibility

### Refactoring

- refactor(ci): remove session scripts, describe manual lifecycle in CLAUDE.md

### Documentation

- docs: mark Phase 4 complete (4.10 done), update current-state, add 3 known issues
- docs(claude): clarify GitHub Flow branching convention in rule 3
- docs(claude): mark tasks 4.1 and 4.9 done; add known issues for sonar paths, docker socket, gke-auth-plugin, trivy CVEs
- docs(rules): add rules 9-10 for change documentation and mandatory release notes
- docs(ops): update current-state - Phase 3 Istio complete
- docs(ops): update current-state - dev RUNNING, stage+prod applying
- docs(ops): update current-state - dev cluster recreating after SSD quota fix
- docs(ops): document GKE node pool SSD quota failure and recovery steps

### Maintenance

- chore: add CLAUDE.md and Workshop_statement.md for project documentation

### All Commits

- [`343f2f6`](https://github.com/David104087/circle-guard-public/commit/343f2f6fe1be99a3088344ffcd65994cf380b430) feat(phase-10): architecture diagrams, README operational sections, operations index, costs, test results, release index, video script, slides, lessons learned (#22) (David Artunduaga, 2026-05-30)
- [`7ee1b31`](https://github.com/David104087/circle-guard-public/commit/7ee1b31328bde4324695c32025340d9e73cdb664) feat(phase-9): release notes grouped by CC type, CM process doc, rollback runbook, versioning convention (#21) (David Artunduaga, 2026-05-30)
- [`58e97b0`](https://github.com/David104087/circle-guard-public/commit/58e97b043464b584bf26dbb6eea4313d06352e4d) feat(phase-8): RBAC, AuthorizationPolicies, secrets to SecretManager, cert-manager TLS, daily Trivy scan, security review (#20) (David Artunduaga, 2026-05-30)
- [`b06735c`](https://github.com/David104087/circle-guard-public/commit/b06735c59ef06262ab5597031031bc5e06be2547) feat(phase-7): observability stack — Prometheus/Grafana, Jaeger, Fluent Bit, alerting rules, health probes, business metrics, Actuator (#19) (David Artunduaga, 2026-05-30)
- [`76ac2e7`](https://github.com/David104087/circle-guard-public/commit/76ac2e762ff394c2a17784f479de7b928ebd8ab1) feat(phase-6): JaCoCo aggregate, ZAP baseline, coverage+ZAP pipeline stages, test inventory, Locust GKE — Phase 6 done (#18) (David Artunduaga, 2026-05-30)
- [`87b7b60`](https://github.com/David104087/circle-guard-public/commit/87b7b60f9383d90e75d53b66f4a1698ea9cf777d) feat(phase-5): install ESO, ClusterSecretStore + ExternalSecrets for all 3 envs — task 5.3 complete, Phase 5 done (David104087, 2026-05-30)
- [`383c825`](https://github.com/David104087/circle-guard-public/commit/383c8253f43d12b34be905fa590748641ace11a9) feat(phase-5): add pattern docs (existing, resilience, sidecar, README) — tasks 5.1 5.2 5.4 5.5 (David104087, 2026-05-30)
- [`2e8b2af`](https://github.com/David104087/circle-guard-public/commit/2e8b2af6eed31bb3515534c4df9e80ee8a734937) refactor(ci): remove session scripts, describe manual lifecycle in CLAUDE.md (David104087, 2026-05-30)
- [`c0018c3`](https://github.com/David104087/circle-guard-public/commit/c0018c374fb8a9ff31b246a4bd5aa5003308f446) docs: mark Phase 4 complete (4.10 done), update current-state, add 3 known issues (David104087, 2026-05-24)
- [`c208827`](https://github.com/David104087/circle-guard-public/commit/c2088279234b2221324d40b77004c4e7d88985da) fix(ci): replace git push with gh api for tag creation in release notes (#17) (David Artunduaga, 2026-05-24)
- [`ccb0e9e`](https://github.com/David104087/circle-guard-public/commit/ccb0e9eb3262701af88f8d9b4a151674a5f6c2ff) fix(ci): use x-access-token format for git push in release notes stage (#16) (David Artunduaga, 2026-05-24)
- [`5b6f9a3`](https://github.com/David104087/circle-guard-public/commit/5b6f9a3bf50bc643caf2ae6060d67d6eab092f67) fix(ci): add gateway+identity to master pipeline docker build and deploy loops (#15) (David Artunduaga, 2026-05-24)
- [`0869737`](https://github.com/David104087/circle-guard-public/commit/0869737f518f479e724d56604ac4d97053845b0b) docs(claude): clarify GitHub Flow branching convention in rule 3 (David104087, 2026-05-24)
- [`da845b8`](https://github.com/David104087/circle-guard-public/commit/da845b81e959cb0b4ef37a3d581db8f88624fcb1) fix(ci): add gateway and identity services to docker build loop and deploy restart (#14) (David Artunduaga, 2026-05-24)
- [`4d94440`](https://github.com/David104087/circle-guard-public/commit/4d94440d07deda8f15803f7395ed8011b3a34e3e) fix(ci): fix bash 3.x incompatibility in session-stop.sh - replace case sensitive expansion with case statement (David104087, 2026-05-24)
- [`468274a`](https://github.com/David104087/circle-guard-public/commit/468274a5cde6479c2466698e0560b81d9f6d3394) docs(claude): mark tasks 4.1 and 4.9 done; add known issues for sonar paths, docker socket, gke-auth-plugin, trivy CVEs (David104087, 2026-05-24)
- [`0d74752`](https://github.com/David104087/circle-guard-public/commit/0d74752f05239a12c0cf9c9013640ef0bc033bf8) fix(ci): add USE_GKE_GCLOUD_AUTH_PLUGIN env for deploy stage (David104087, 2026-05-24)
- [`2beddee`](https://github.com/David104087/circle-guard-public/commit/2beddee978b32d5a670e8ca73c6a4e515eaacf02) fix(ci): make trivy fully non-blocking - known CVEs from spring-boot 3.2.4 tomcat 10.1.19 (David104087, 2026-05-24)
- [`021a50e`](https://github.com/David104087/circle-guard-public/commit/021a50e84c98dbc529208d5df1bb5393f2bda013) fix(ci): make trivy HIGH non-blocking, only CRITICAL fails pipeline; fix docker socket in session-start (David104087, 2026-05-24)
- [`84ade3c`](https://github.com/David104087/circle-guard-public/commit/84ade3ccb784d2f73257110d8c39803c37076342) fix(sonar): correct source/test paths from kotlin to java for all 8 services (David104087, 2026-05-24)
- [`10c0b5f`](https://github.com/David104087/circle-guard-public/commit/10c0b5ffa6da1799d36ea62845e4af2136aec7a8) docs(rules): add rules 9-10 for change documentation and mandatory release notes (David104087, 2026-05-24)
- [`0970117`](https://github.com/David104087/circle-guard-public/commit/0970117087dbde5e7c5cefca65276e37c59c81eb) feat(phase-4): implement CI/CD advanced pipeline with SonarQube, Trivy, canary, and semver (#13) (David Artunduaga, 2026-05-24)
- [`c1dc7d6`](https://github.com/David104087/circle-guard-public/commit/c1dc7d6c05a94e6eb0c86e44f6d78f1829fc6993) docs(ops): update current-state - Phase 3 Istio complete (David104087, 2026-05-24)
- [`4c2afd5`](https://github.com/David104087/circle-guard-public/commit/4c2afd53262f58820ea00a800cab479dc73bf2a5) feat(phase-3): Istio service mesh - mTLS, circuit breaker, canary, Kiali (David Artunduaga, 2026-05-24)
- [`31d4a07`](https://github.com/David104087/circle-guard-public/commit/31d4a07075500dadb40bbd7760471319da954e31) feat(phase-2): K8s migration from DigitalOcean to GKE with 8 microservices (David Artunduaga, 2026-05-24)
- [`94d72d9`](https://github.com/David104087/circle-guard-public/commit/94d72d96f58f34a5091056744614ad9e782769a0) feat(phase-1): complete GKE infrastructure provisioning for all 3 environments (David104087, 2026-05-23)
- [`d978aa2`](https://github.com/David104087/circle-guard-public/commit/d978aa223a07c7305b06fa20011852c89219f825) docs(ops): update current-state - dev RUNNING, stage+prod applying (David104087, 2026-05-23)
- [`2a78ba9`](https://github.com/David104087/circle-guard-public/commit/2a78ba9c712facfda4620970178ca9be4f426a20) fix(terraform): add pd-standard node_config to cluster to fix initial pool SSD quota (David104087, 2026-05-23)
- [`38f8f81`](https://github.com/David104087/circle-guard-public/commit/38f8f8183af1e5cb7829820351eff5591676fcc1) docs(ops): update current-state - dev cluster recreating after SSD quota fix (David104087, 2026-05-23)
- [`54c4ce9`](https://github.com/David104087/circle-guard-public/commit/54c4ce9ba1737d9b98623d18ac3a4d17793f9537) fix(terraform): change upgrade_settings to max_surge=0 to avoid SSD quota issues (David104087, 2026-05-23)
- [`6499d99`](https://github.com/David104087/circle-guard-public/commit/6499d9903d11069a676e27381a594136edca7863) docs(ops): document GKE node pool SSD quota failure and recovery steps (David104087, 2026-05-23)
- [`28004e3`](https://github.com/David104087/circle-guard-public/commit/28004e32d80c4795abc57e16b64e2da56268ee95) feat(phase-1): add Terraform modules and all three environment configs (David104087, 2026-05-23)
- [`36d88af`](https://github.com/David104087/circle-guard-public/commit/36d88af13c0b52b04d90b8b8f6605afabe16e9ca) fix(ops): rewrite session scripts for bash 3.x compatibility (David104087, 2026-05-18)
- [`2779915`](https://github.com/David104087/circle-guard-public/commit/277991575c68a8cedeffb523d8549ff4831ec9ac) feat(ops): add Rule 6 - auto-run session scripts on start/stop signals (David104087, 2026-05-18)
- [`79735d4`](https://github.com/David104087/circle-guard-public/commit/79735d42c6a219dc1a28e4197a9251af8f006bcf) feat(ops): add session-start/stop scripts for GCP cost management (David104087, 2026-05-18)
- [`c918149`](https://github.com/David104087/circle-guard-public/commit/c9181490e8fb4e127ddc75d74f3ef45db33e6b78) feat(phase-0): complete GCP setup, GitHub Projects board, and user stories (David104087, 2026-05-18)
- [`c3e8adb`](https://github.com/David104087/circle-guard-public/commit/c3e8adb217a68ed024fc75d5972529f93648b68e) feat(phase-0): mark task 0.4 complete - all local tooling installed (David104087, 2026-05-18)
- [`06fd363`](https://github.com/David104087/circle-guard-public/commit/06fd3638ff81a138626dd80c75f4ad31f20680f4) feat(phase-0): scaffold repo structure, branching strategy, and user stories (David104087, 2026-05-17)
- [`3b8e4e5`](https://github.com/David104087/circle-guard-public/commit/3b8e4e551972838c745aaf1fe19ad7fadefb63fe) feat: Add QA project initialization and metrics calculation scripts (David104087, 2026-05-17)
- [`fcfcf7b`](https://github.com/David104087/circle-guard-public/commit/fcfcf7b443016b6d88e2c2725ce01375754607b0) chore: add CLAUDE.md and Workshop_statement.md for project documentation (David104087, 2026-05-17)
- [`eb168e2`](https://github.com/David104087/circle-guard-public/commit/eb168e232e0cbdfc75ef429de1ba4f9196c585f8) Remove outdated local run instructions from run-project.md (David104087, 2026-05-10)
- [`d00633e`](https://github.com/David104087/circle-guard-public/commit/d00633e2d1e5eb8c6e76bf0fcaaf0bb4e2653ce8) Update .gitignore: ignore screenshots, test reports, and local files (David104087, 2026-05-10)
- [`396a1fe`](https://github.com/David104087/circle-guard-public/commit/396a1fedab60b227a84f5c392b9b912db95249bd) Make Neo4j schema initialization resilient to startup failures (David104087, 2026-05-10)
- [`d576b61`](https://github.com/David104087/circle-guard-public/commit/d576b612ad1146ffacded2fdefd6878b7396ba6b) Update CLAUDE.md: all three pipelines now green (David104087, 2026-05-04)
- [`264b533`](https://github.com/David104087/circle-guard-public/commit/264b533f82b869ec190afebbb1e6180d0b6eae98) Enable Neo4j for promotion-service: remove SPRING_AUTOCONFIGURE_EXCLUDE (David104087, 2026-05-04)
- [`f57ee0b`](https://github.com/David104087/circle-guard-public/commit/f57ee0b9ab485c1ea62aa5a46a4d6daa4e19b23a) Fix production deployment: probes, rolling update strategy, and pipeline order (David104087, 2026-05-04)
- [`0e68ed3`](https://github.com/David104087/circle-guard-public/commit/0e68ed30ce4d20d666bd416611977cc744cdd1af) Add production infrastructure and fix postgres password for production (David104087, 2026-05-04)
- [`94f6aef`](https://github.com/David104087/circle-guard-public/commit/94f6aefa545c6b2d66e60411ac547c97115aea92) Fix psql connection: add -d postgres to CREATE DATABASE exec commands (David104087, 2026-05-04)
- [`cd96895`](https://github.com/David104087/circle-guard-public/commit/cd9689597f720ce4a0a0f612be5c96dc8b0f00e9) Fix shell escaping in postgres DB creation — loop in outer shell (David104087, 2026-05-04)
- [`34fb8a6`](https://github.com/David104087/circle-guard-public/commit/34fb8a61e4226c9e2f1869d6116ca133869db2e8) Ensure postgres databases exist before deploying services in all pipelines (David104087, 2026-05-04)
- [`8b3e883`](https://github.com/David104087/circle-guard-public/commit/8b3e8833f9a2ee8028835887aa35c43b36170c75) Set PGDATA to subdirectory to avoid lost+found conflict on fresh PVCs (David104087, 2026-05-04)
- [`4408ca5`](https://github.com/David104087/circle-guard-public/commit/4408ca57e88321b7a3e6146eb859ba4dd9add7e5) Reduce infrastructure CPU requests to 100m to fit 2-node cluster (David104087, 2026-05-04)
- [`7d6bdfb`](https://github.com/David104087/circle-guard-public/commit/7d6bdfb8110a2ac6989264653ca1f306b41e7a54) Add postgres-init ConfigMap for all namespaces and mount init scripts in StatefulSets (David104087, 2026-05-04)
- [`92883c8`](https://github.com/David104087/circle-guard-public/commit/92883c87265205a8f13e7ed139591f79026c3641) Add Docker proxy env vars to Integration/E2E test stages in STAGE and MASTER pipelines (David104087, 2026-05-04)
- [`a9e4d94`](https://github.com/David104087/circle-guard-public/commit/a9e4d9464e7968d63999b599fd56d3d313e1b941) Reduce probe initialDelay to 30s and increase rollout timeout to 300s in DEV (David104087, 2026-05-04)
- [`e10a474`](https://github.com/David104087/circle-guard-public/commit/e10a474158493c39ed58c37f494180e43a93c498) Fix Neo4j 5.x env var: pagecache_size (dot) not pagecache__size (underscore) (David104087, 2026-05-04)
- [`7a14450`](https://github.com/David104087/circle-guard-public/commit/7a14450660a4bc3b1328b43e896341d5b7dd7a3a) Reduce K8s memory requests to fit 2-node 4GB cluster in DEV/STAGE/PROD (David104087, 2026-05-04)
- [`c3ab065`](https://github.com/David104087/circle-guard-public/commit/c3ab065abad24b8f009832d03f6ef26d80278d31) Fix kubectl infrastructure apply: remove -n flag that conflicts with multi-namespace YAMLs (David104087, 2026-05-04)
- [`6ee11a4`](https://github.com/David104087/circle-guard-public/commit/6ee11a44601716896f962d93b74691ca8c2409ae) Relax performance test CI threshold from 1s to 5s for Testcontainers overhead (David104087, 2026-05-04)
- [`5972365`](https://github.com/David104087/circle-guard-public/commit/59723656bd36baa8fb40e83c9549c4e7b57cf4a5) Add CLAUDE.md with project context, rules, and operational guide (David104087, 2026-05-04)
- [`818f1ee`](https://github.com/David104087/circle-guard-public/commit/818f1ee6c237b752a088fe95bf44a6f269ca2955) Speed up Docker builds: use pre-built JARs from Build stage (David104087, 2026-05-03)
- [`c79e6c5`](https://github.com/David104087/circle-guard-public/commit/c79e6c58b9db0b436087e5adad72a10b76d2f806) Add Docker CE CLI, buildx and kubectl to Jenkins image (David104087, 2026-05-03)
- [`5bb62d4`](https://github.com/David104087/circle-guard-public/commit/5bb62d49b5feebcf031265dd2c1fbd832402778b) Fix DooD networking: use host.docker.internal for Testcontainers (David104087, 2026-05-03)
- [`9c582f8`](https://github.com/David104087/circle-guard-public/commit/9c582f88df972ea528a4f706fe1d39cb37346832) Fix Docker API version mismatch in Testcontainers for Jenkins CI (David104087, 2026-05-03)
- [`4921190`](https://github.com/David104087/circle-guard-public/commit/4921190823ad0d2a933225db1468944f84b10f00) Write ~/.testcontainers.properties in CI to configure Docker proxy socket (David104087, 2026-05-03)
- [`0000993`](https://github.com/David104087/circle-guard-public/commit/0000993302a2929d81aae87776d848f7981ceaae) Forward Docker env vars to Gradle test JVM and fix Jenkinsfile issues (David104087, 2026-05-03)
- [`eee2b96`](https://github.com/David104087/circle-guard-public/commit/eee2b96f574dddf911f0f15e908c017e90c38e86) Add Docker API version proxy for Testcontainers in Jenkins CI (David104087, 2026-05-03)
- [`24bf12c`](https://github.com/David104087/circle-guard-public/commit/24bf12c928f9bd1b0df32be888400811ddd026e5) Fix promotion-service tests: Testcontainers 1.20.4, Docker proxy, Redis containers, Flyway disabled (David104087, 2026-05-03)
- [`aa93a7a`](https://github.com/David104087/circle-guard-public/commit/aa93a7a266617102d03bbb7c1150919855f20784) Fix k8s deployments: conditional Neo4j, auth probes, kafka heap, CI pipelines (David104087, 2026-05-03)
- [`26d9faf`](https://github.com/David104087/circle-guard-public/commit/26d9faf42765fe998de5a88a849d80c83ad60bed) Add CI/CD pipelines, K8s manifests, tests and Dockerfiles for 6 microservices (David104087, 2026-05-02)
- [`538bd0f`](https://github.com/David104087/circle-guard-public/commit/538bd0fc9b8a39a3397bd77555fbc706737602f9) complement front (Juan Carlos Muñoz, 2026-04-22)
- [`a1d5f41`](https://github.com/David104087/circle-guard-public/commit/a1d5f419fdb3b7d079c268c0341a56e68b679705) startup and tests fixed (Juan Carlos Muñoz, 2026-04-22)
- [`dce49ac`](https://github.com/David104087/circle-guard-public/commit/dce49ac36a8fb425dfd6f04b03e9f43288b20016) Add implementation on front and back (Juan Carlos Muñoz, 2026-04-21)

---

## Test Summary

| Metric | Value |
|--------|-------|
| Total Tests | 11 |
| Passed | 11 |
| Failed | 0 |
| Build Number | N/A |

---

## Deployment Checklist

- [x] Unit tests passed
- [x] Integration tests passed
- [x] E2E tests passed
- [x] SonarQube quality gate passed
- [x] Trivy scan completed (no new CRITICAL blockers)
- [x] Docker images pushed to Docker Hub
- [x] Kubernetes manifests applied to production
- [x] Canary approved at 10% → promoted to 100%
- [x] All rollouts healthy

---

*Generated automatically by CircleGuard CI/CD pipeline.*
