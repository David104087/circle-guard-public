# CircleGuard — Multi-Cloud Strategy

## Overview

CircleGuard runs on **two cloud providers simultaneously**, with full environment parity — each provider hosts **dev, stage, and prod** clusters following identical standards.

| | Primary (GCP) | Secondary (DigitalOcean) |
|--|---------------|--------------------------|
| **Provider** | Google Cloud Platform | DigitalOcean |
| **Service** | GKE (Google Kubernetes Engine) | DOKS (DigitalOcean Kubernetes Service) |
| **Clusters** | `circleguard-dev/stage/prod` | `circleguard-do-dev/do-stage/do-prod` |
| **Region** | `us-central1` (Iowa) | `nyc1` (New York) |
| **Namespaces** | `circleguard-dev/stage/production` | `circleguard-do-dev/do-stage/do-prod` |
| **Control plane cost** | $0.10/h per cluster | **$0 — free** |
| **Node cost** | ~$0.024/h spot (e2-standard-2) | ~$0.018/h (s-2vcpu-4gb) |
| **Terraform state** | `gs://circle-guard-tfstate-496702/envs/dev\|stage\|prod` | `gs://circle-guard-tfstate-496702/envs/do-dev\|do-stage\|do-prod` |

## Deployment Strategy: Full Environment Mirroring

### What is mirroring?

**Full Environment Mirroring** means that every environment (dev, stage, prod) is replicated identically across both cloud providers. There is no division of responsibility — both clouds run the complete stack of 8 microservices, Istio mesh, mTLS, same K8s manifests, same pipeline.

This contrasts with other multi-cloud strategies:

| Strategy | Description | Used here? |
|----------|-------------|------------|
| **Active-Active** | Traffic split between both clouds in real time | ❌ |
| **Active-Passive** (DNS level) | One cloud handles traffic; other is on standby | ✅ (prod) |
| **Full Mirroring** | All environments replicated on both clouds | ✅ |
| **Cloud Bursting** | Secondary cloud absorbs overflow spikes only | ❌ |
| **Partial Migration** | Each cloud hosts different services | ❌ |

### How mirroring is implemented

Every cloud has the exact same stack:
- 3 environments: dev / stage / prod
- 8 microservices deployed via identical K8s manifests (only `StorageClass` differs)
- Istio service mesh with STRICT mTLS PeerAuthentication
- Same Jenkins pipeline (`ci/Jenkinsfile.dev` deploys to both GCP dev and DO dev in parallel)
- Same Terraform workflow (separate provider, same structure)
- Same observability (Prometheus, Grafana, Jaeger, ELK — applied to each cluster)

Traffic strategy (active-passive at DNS level):
- **Production:** GCP is primary; DO prod is hot standby. Failover = DNS TTL 60s update to DO LB IP
- **Dev/Stage:** both clouds receive identical deployments simultaneously from the pipeline

### Advantages of full mirroring

1. **True DR at application level.** If GCP goes down entirely (not just a zone), the DO cluster is already running the same version of every service. Recovery is a DNS change, not a full redeploy.
2. **Cross-cloud regression detection.** If a service behaves differently on GCP vs DO (different JVM GC behavior, Linux kernel version, network MTU), the pipeline catches it before it reaches users.
3. **Zero cold-start on failover.** Active-Passive with a cold standby requires spinning up a cluster and redeploying — minutes of downtime. With mirroring, the standby is already warm.
4. **Cost-optimized dev/stage.** DO's cheaper nodes ($0.024/h, free control plane) reduce the cost of running dev and stage environments where absolute latency is not critical.
5. **Vendor independence.** The application runs on standard Kubernetes + Istio — no GCP-specific services (no Cloud SQL, no Pub/Sub). Portability is validated continuously.

### Tradeoffs and limitations

1. **Operational overhead.** Every manifest change must be applied to both clouds. The pipeline handles this automatically, but debugging issues requires context-switching between two kubeconfig targets.
2. **State divergence risk.** If the DO cluster is offline when the pipeline runs (nodes scaled to 0), GCP gets the update but DO doesn't. Must re-sync manually after scaling DO back up.
3. **Resource duplication cost.** Running 3 environments on two clouds doubles infrastructure costs when both are active. Mitigated by scale-to-zero between sessions.
4. **Performance asymmetry.** GCP is 32–68% faster on p50–p99 latency (250ms vs 370ms for visitor/handoff). Under full load DO nodes run CPU-constrained on 2 vCPUs. Acceptable for standby; not equivalent for prod traffic under load.
5. **Database state not replicated.** Both clouds have independent Postgres, Redis, and Neo4j instances. In a real failover, state would need to be synchronized (not implemented — out of scope for this project). This makes DO prod a cold replica from a data perspective, not truly active.

### Why mirroring was chosen for this project

1. **Academic completeness.** The bonus requires demonstrating multi-cloud deployment across all environments. Mirroring is the clearest evidence of full multi-cloud capability — there is nothing left "only on one cloud."
2. **Istio already handles service mesh.** Since Istio with STRICT mTLS is already the standard across all environments, adding DO clusters uses the exact same manifests. The delta effort was Terraform + StorageClass.
3. **Pipeline integration is natural.** Adding a parallel `Deploy to DO DEV` stage to the Jenkinsfile only required adding a `withCredentials` block — the `kubectl apply` commands are identical.
4. **Scale-to-zero makes cost acceptable.** With `min_nodes=0` on all DO clusters, the cost when idle is only the Terraform state (GCS bucket — fractions of a cent). The DO clusters are only active during active sessions.

## Why DigitalOcean as the Second Cloud?

1. **Free control plane** — DOKS does not charge for Kubernetes master nodes
2. **Project history** — CircleGuard originally ran on DigitalOcean before migrating to GCP
3. **Simple Terraform provider** — `digitalocean/digitalocean` requires only a token; no VPC/subnet/firewall complexity
4. **Cost-effective nodes** — `s-2vcpu-4gb` at ~$18/mo vs comparable GKE on-demand

## Environment Parity

Both clouds mirror each other exactly across 3 environments:

| Environment | GCP Cluster | DO Cluster | Node sizing |
|-------------|-------------|------------|-------------|
| Dev | `circleguard-dev` | `circleguard-do-dev` | 1 node, min=0, max=3 |
| Stage | `circleguard-stage` | `circleguard-do-stage` | 1 node, min=0, max=3 |
| Prod | `circleguard-prod` | `circleguard-do-prod` | 2 nodes, min=0, max=5 |

All clusters use `min_nodes=0` — scaled to 0 between sessions to minimize cost.

## Architecture

```
Internet
    │
    ├── GCP Load Balancers
    │       ├── circleguard-dev    (GKE, us-central1) → circleguard-dev namespace
    │       ├── circleguard-stage  (GKE, us-central1) → circleguard-stage namespace
    │       └── circleguard-prod   (GKE, us-central1) → circleguard-production namespace
    │               └── 8 microservices + Istio (STRICT mTLS)
    │
    └── DigitalOcean Load Balancers
            ├── circleguard-do-dev   (DOKS, nyc1) → circleguard-do-dev namespace
            ├── circleguard-do-stage (DOKS, nyc1) → circleguard-do-stage namespace
            └── circleguard-do-prod  (DOKS, nyc1) → circleguard-do-prod namespace
                    └── 8 microservices + Istio (STRICT mTLS)
```

## Cross-Cloud Load Balancing Strategy

For this implementation, cross-cloud traffic distribution is **active-passive at the DNS level**:

- **Primary:** GCP GKE handles all production traffic
- **Secondary:** DOKS serves as a hot standby / DR site
- **Failover:** DNS TTL set to 60s — in case of GCP outage, update the DNS A record to point to the DOKS prod LB IP

### Future: Active-Active with Cloudflare

```
Cloudflare DNS (health-checked)
    ├── A record → GCP external IP    (weight: 50%)
    └── A record → DO external IP     (weight: 50%)
```

## Terraform Setup

### Prerequisites

```bash
# DigitalOcean Personal Access Token
export TF_VAR_do_token="dop_v1_xxxxxxxxxxxxxxxx"

# GCS backend credentials (same as GCP envs)
gcloud auth application-default login
```

### Apply DO clusters (sequential to avoid API rate limits)

```bash
# DO dev
cd terraform/envs/do-dev && terraform init && terraform apply
terraform output -raw kube_config > ~/.kube/circleguard-do-dev

# DO stage
cd ../do-stage && terraform init && terraform apply
terraform output -raw kube_config > ~/.kube/circleguard-do-stage

# DO prod
cd ../do-prod && terraform init && terraform apply
terraform output -raw kube_config > ~/.kube/circleguard-do-prod
```

### Scale DO clusters to 0 (end of session)

```bash
# Using doctl (once clusters exist)
for cluster in circleguard-do-dev circleguard-do-stage circleguard-do-prod; do
  CLUSTER_ID=$(doctl kubernetes cluster get $cluster --format ID --no-header)
  POOL_ID=$(doctl kubernetes cluster node-pool list $CLUSTER_ID --format ID --no-header)
  doctl kubernetes cluster node-pool update $CLUSTER_ID $POOL_ID --count 0
done
```

### Destroy DO clusters (overnight)

```bash
cd terraform/envs/do-dev && terraform destroy -auto-approve
cd ../do-stage && terraform destroy -auto-approve
cd ../do-prod && terraform destroy -auto-approve
```

## Kubernetes Deployment

### Key differences from GKE manifests

| Config | GKE (`k8s/dev/`) | DOKS (`k8s/do-dev/`) |
|--------|------------------|----------------------|
| StorageClass | `standard-rwo` | `do-block-storage` |
| Namespace (dev) | `circleguard-dev` | `circleguard-do-dev` |
| LoadBalancer | GCP L4 LB (automatic) | DO LB (automatic) |
| Istio injection | ✅ enabled | ✅ enabled |
| mTLS | STRICT | STRICT |

### Deploy to DO dev

```bash
export KUBECONFIG=~/.kube/circleguard-do-dev

# Namespace + infrastructure
kubectl apply -f k8s/do-dev/00-namespace.yaml
kubectl apply -f k8s/do-dev/infrastructure/

# Wait for Postgres
kubectl wait --for=condition=ready pod -l app=postgres -n circleguard-do-dev --timeout=180s

# Services
kubectl apply -f k8s/do-dev/

# Istio
istioctl install --set profile=demo -y
kubectl label namespace circleguard-do-dev istio-injection=enabled --overwrite
kubectl apply -f k8s/istio/
```

Repeat with `do-stage` and `do-prod` using corresponding kubeconfig and manifests.

## Current Deployment Status (2026-06-08)

Tasks 11.6–11.9 complete. All 3 DO clusters have 8/8 services Running with Istio STRICT mTLS:

| Cluster | Services | Istio | PeerAuthentication |
|---------|----------|-------|--------------------|
| `circleguard-do-dev` | 8/8 `2/2 Running` | ✅ | STRICT |
| `circleguard-do-stage` | 8/8 `2/2 Running` | ✅ | STRICT |
| `circleguard-do-prod` | 8/8 `2/2 Running` | ✅ | STRICT |

**Note on infra in do-stage/do-prod:** Kafka and Neo4j may be Pending on `s-2vcpu-4gb` nodes due to memory constraints. Infrastructure sidecars are disabled (`sidecar.istio.io/inject: "false"`) to conserve memory. App services are unaffected.

**Probe strategy:** All DO env manifests use `tcpSocket` probes (not `httpGet /actuator/health`) because the Docker Hub images were built before actuator was added to the codebase.

## Jenkins Pipeline Integration

Credentials required in Jenkins (Task 11.10):

| ID | Type | Purpose |
|----|------|---------|
| `do-dev-kubeconfig` | FileCredentials | DOKS kubeconfig for do-dev |
| `do-stage-kubeconfig` | FileCredentials | DOKS kubeconfig for do-stage |
| `do-prod-kubeconfig` | FileCredentials | DOKS kubeconfig for do-prod |

To register kubeconfigs in Jenkins:
1. Refresh kubeconfig: `cd terraform/envs/do-dev && terraform output -raw kube_config > /tmp/do-dev-kube.yaml`
2. Jenkins → Manage Jenkins → Credentials → Global → Add Credential
3. Type: **Secret file**, ID: `do-dev-kubeconfig`, upload `/tmp/do-dev-kube.yaml`
4. Repeat for stage and prod

The `ci/Jenkinsfile.dev` now deploys in parallel to GCP dev and DO dev. The `Jenkinsfile.master` stage for DO prod:

```groovy
stage('Deploy to DO Production') {
    when { branch 'master' }
    steps {
        withCredentials([file(credentialsId: 'do-prod-kubeconfig', variable: 'KUBECONFIG_DO')]) {
            sh '''
                export KUBECONFIG=$KUBECONFIG_DO
                kubectl apply -f k8s/do-prod/
                kubectl rollout status deployment/auth-service -n circleguard-do-prod --timeout=300s || true
            '''
        }
    }
}
```

## Performance Comparison

**Test date:** 2026-06-08 · **Tool:** Locust 2.43.4 · **Profile:** 50 users, spawn 5/s, 2 min  
**Endpoint:** `POST /api/v1/auth/visitor/handoff` via `kubectl port-forward svc/auth-service 8180:8180`  
**Full results:** [`tests/performance/comparison-results.md`](../../tests/performance/comparison-results.md)

```bash
# Reproducir el test contra cualquier cloud:
kubectl port-forward -n <namespace> svc/auth-service 8180:8180 &
locust -f tests/performance/locustfile_comparison.py \
  --host http://localhost:8180 --headless -u 50 -r 5 --run-time 2m \
  --html results-<cloud>.html --csv results-<cloud>
```

| Metric | GCP prod (us-central1-a) | DO prod (nyc1) | Winner |
|--------|--------------------------|----------------|--------|
| visitor/handoff — p50 | **250 ms** | 370 ms | GCP ✅ |
| visitor/handoff — p95 | **530 ms** | 1 000 ms | GCP ✅ |
| visitor/handoff — p99 | **710 ms** | 2 200 ms | GCP ✅ |
| login — p50 | **18 000 ms** | 21 000 ms | GCP ✅ |
| login — p95 | **20 000 ms** | 25 000 ms | GCP ✅ |
| Total RPS | **4.04** | 3.47 | GCP ✅ |
| Error rate | **0%** | 0% | Tie |
| Node cost/hr | $0.033 (e2-medium) | **$0.024** (s-2vcpu-4gb) | DO ✅ |
| Control plane cost | $0.10/h | **$0 (free)** | DO ✅ |

**Key finding:** GCP is 32–68% faster on p50–p99 latency for visitor/handoff (250ms vs 370ms p50).
DO node runs under CPU pressure with all 8 services + Istio on 2 vCPUs; GCP test used a dedicated node.
DO is the cost-optimal choice for dev/staging; GCP is correct for production traffic.
This validates the **active-passive DNS strategy**: GCP as primary, DO as hot standby.

## Cost Comparison

| Cost item | GCP (per cluster) | DigitalOcean (per cluster) |
|-----------|-------------------|---------------------------|
| Control plane | $0.10/h | **$0** |
| 1 node `dev/stage` (8h/day) | ~$0.19/day spot | ~$0.14/day |
| 2 nodes `prod` (8h/day) | ~$0.38/day spot | ~$0.29/day |
| Monthly `dev` (8h/day) | ~$5.70 | ~$4.30 |
| Monthly `prod` (8h/day) | ~$11.40 + $72 CP | ~$8.70 + **$0 CP** |
| **Winner** | | **DigitalOcean ~24-30% cheaper** |
