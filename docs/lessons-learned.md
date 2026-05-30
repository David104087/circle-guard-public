# CircleGuard — Lessons Learned

SE5 Proyecto Final — what worked, what didn't, what we'd change.

---

## What Worked Well

### Terraform + GKE
Provisioning an entire environment (VPC + GKE cluster + Secret Manager + IAM) with a single `terraform apply` was the biggest productivity win of the project. The module structure made it easy to replicate dev→stage→prod with different sizing parameters. Remote state in GCS with versioning prevented state corruption even when apply was interrupted mid-way.

### Istio for cross-cutting concerns
Enforcing mTLS, circuit breaking, retries, and canary deployments at the mesh layer — without a single line of Java code change — demonstrated the power of the sidecar pattern. Adding a new service automatically gets all these capabilities via namespace label injection.

### GitHub Flow + Conventional Commits
Using `feat/...` and `fix/...` branches for every change kept the commit history clean and made `semver.sh` deterministic. Conventional Commits also made release notes grouping automatic — no manual categorization needed.

### Parallel Testcontainers tests
Running 6 services' unit tests in parallel in Jenkins (each in its own stage) cut test time from ~6 minutes serial to ~2.5 minutes. Testcontainers spinning up PostgreSQL and Neo4j containers per test class provided strong isolation without mocking.

### External Secrets Operator
ESO + GCP Secret Manager eliminated all secrets from Git completely. The `ExternalSecret` resources with 1h refresh interval mean secrets can rotate without redeploying services. The ClusterSecretStore pattern (one store per cluster) simplified the setup.

---

## What Was Challenging

### GCP quota management (12 vCPU limit)
The project account had `CPUS_ALL_REGIONS = 12`. Three GKE regional clusters (1 node/zone = 3 nodes × 2 vCPUs = 6 vCPUs each) → can never run more than 2 clusters simultaneously. Required careful sequential deployment, autoscaler `min_node_count = 0`, and `terraform destroy` between sessions. Added significant operational overhead.

### Istio sidecar startup timing
When pods restart on new nodes, there's a window where the Envoy sidecar isn't fully initialized but the app container starts connecting to PostgreSQL. DNS resolution through the mesh fails → `UnknownHostException` → CrashLoopBackOff. The fix (`holdApplicationUntilProxyStarts: true`) is not yet applied to all deployments. This caused many debugging sessions.

### Jenkins DooD (Docker-outside-Docker)
Running Jenkins inside Docker with `/var/run/docker.sock` mounted caused multiple issues:
- Docker socket permissions (`root:root 660`) must be fixed manually after restart
- Testcontainers `localhost` != Docker host → needed `TESTCONTAINERS_HOST_OVERRIDE`
- Kubeconfigs referencing macOS paths → needed gcloud reinstallation inside container

### GitHub PAT limitations
The `github-token` credential in Jenkins can call `gh` CLI APIs but fails for `git push` tags over HTTPS. Spent time debugging different auth formats (`user:token`, `x-access-token:token`) before discovering the correct fix: `gh api` to create the tag reference directly.

### Neo4j PVC zone affinity
StatefulSet PVCs are bound to a specific GCP zone. When cluster nodes scaled down and came back in a different zone, Neo4j couldn't be scheduled. Required manual PVC deletion and recreation. Long-term fix: use `WaitForFirstConsumer` StorageClass or multi-zone volumes.

---

## What We'd Change

### GKE Autopilot instead of Standard
Autopilot charges per pod resource request, not per node. For dev workloads with variable usage, this would be ~40% cheaper and eliminates node quota constraints. The tradeoff is less control over node configuration.

### Workload Identity instead of JSON key
Currently the External Secrets Operator authenticates to GCP using a terraform-sa JSON key stored in a K8s Secret. Workload Identity (keyless auth via GKE node identity) is more secure and eliminates the need to manage key rotation. The setup is more complex but worth it for production.

### Spring Boot upgrade to 3.2.12+
Spring Boot 3.2.4 has CRITICAL CVEs in Tomcat 10.1.19 and Spring Security 6.2.3. Trivy reports them on every build. Upgrading to 3.2.12+ would resolve ~15 CVEs and unblock the Trivy `--exit-code 1` enforcement.

### Zonal clusters for dev/stage
Regional clusters (3 zones) consume 3× the vCPU quota of zonal clusters. For dev/stage, a single-zone cluster would cut CPU usage to 2 vCPUs per env, allowing all 3 envs to run simultaneously within quota.

### Automated canary promotion
The 30-minute manual approval window for the canary is adequate for demos but too slow for real CI/CD. In production, we'd integrate automatic canary analysis: if Prometheus error rate stays < 1% for 10 minutes, auto-promote; otherwise auto-rollback. Flagger or Argo Rollouts would handle this automatically.

### `holdApplicationUntilProxyStarts` in all deployments
Apply this Istio annotation to all 8 service deployments to prevent the CrashLoopBackOff race condition on pod restarts. Should have been added when Istio was installed in Phase 3.
