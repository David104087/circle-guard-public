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
