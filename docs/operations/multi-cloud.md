# CircleGuard — Multi-Cloud Strategy

## Overview

CircleGuard runs on **two cloud providers simultaneously**:

| | Primary (Cloud 1) | Secondary (Cloud 2) |
|--|-------------------|---------------------|
| **Provider** | Google Cloud Platform (GCP) | DigitalOcean |
| **Service** | GKE (Google Kubernetes Engine) | DOKS (DigitalOcean Kubernetes Service) |
| **Cluster** | `circleguard-dev/stage/prod` | `circleguard-cloud2` |
| **Region** | `us-central1` | `nyc1` (New York) |
| **Namespace** | `circleguard-dev` | `circleguard-cloud2` |
| **Control plane cost** | $0.10/h | **$0 — free** |
| **Node cost** | ~$0.024/h spot (e2-standard-2) | ~$0.018/h (s-2vcpu-4gb) |

## Why DigitalOcean as the Second Cloud?

1. **Free control plane** — DOKS does not charge for the Kubernetes master nodes
2. **Project history** — CircleGuard originally ran on DigitalOcean before migrating to GCP. The `do-block-storage` StorageClass and DOKS manifests were already partially known
3. **Simple Terraform provider** — `digitalocean/digitalocean` requires only a token; no VPC/subnet/firewall complexity like AWS
4. **Cost-effective nodes** — `s-2vcpu-4gb` at ~$18/mo vs comparable GKE on-demand

## Architecture

```
Internet
    │
    ├── GCP Load Balancer ──────── GKE cluster (us-central1)
    │                                   └── circleguard-dev namespace
    │                                         └── 8 microservices + Istio
    │
    └── DigitalOcean Load Balancer ─ DOKS cluster (nyc1)
                                        └── circleguard-cloud2 namespace
                                              └── 8 microservices + Istio
```

## Cross-Cloud Load Balancing Strategy

For this implementation, cross-cloud traffic distribution is handled at the **DNS level** (active-passive):

- Primary: GCP GKE handles all production traffic
- Secondary: DOKS serves as a hot standby / DR site
- Failover: DNS TTL set to 60s — in case of GCP outage, update DNS A record to point to DOKS LB IP

A full active-active setup would require a global DNS provider like Cloudflare with health checks (documented below as future improvement).

### Future: Active-Active with Cloudflare
```
Cloudflare DNS (health-checked)
    ├── A record → GCP external IP    (weight: 50%)
    └── A record → DO external IP     (weight: 50%)
```

## Terraform Setup

### Prerequisites

```bash
# DigitalOcean Personal Access Token (from partner's account or your own)
export TF_VAR_do_token="dop_v1_xxxxxxxxxxxxxxxx"

# GCS backend credentials (same as GCP envs — uses Application Default Credentials)
gcloud auth application-default login
```

### Apply cloud2 cluster

```bash
cd terraform/envs/cloud2
terraform init
terraform apply
```

Expected output: DOKS cluster `circleguard-cloud2` created in ~5 minutes.

### Configure kubectl for cloud2

```bash
# Save kubeconfig
terraform output -raw kube_config > ~/.kube/circleguard-cloud2
export KUBECONFIG=~/.kube/circleguard-cloud2

# Verify
kubectl get nodes
```

### Destroy cloud2 (to stop costs)

```bash
cd terraform/envs/cloud2
terraform destroy -auto-approve
```

## Kubernetes Deployment

### Deploy to cloud2

```bash
export KUBECONFIG=~/.kube/circleguard-cloud2

# Namespace
kubectl apply -f k8s/cloud2/00-namespace.yaml

# Infrastructure (Postgres, Kafka, Redis, Neo4j)
kubectl apply -f k8s/cloud2/infrastructure/

# Wait for infrastructure pods
kubectl wait --for=condition=ready pod -l app=postgres -n circleguard-cloud2 --timeout=120s

# Services
kubectl apply -f k8s/cloud2/

# Install Istio (same as GKE)
istioctl install --set profile=demo -y
kubectl apply -f k8s/istio/
```

### Key differences from GKE manifests

| Config | GKE (k8s/dev/) | DOKS (k8s/cloud2/) |
|--------|----------------|---------------------|
| StorageClass | `standard-rwo` | `do-block-storage` |
| Namespace | `circleguard-dev` | `circleguard-cloud2` |
| LoadBalancer | GCP L4 LB (automatic) | DO LB (automatic) |
| Istio injection | ✅ same | ✅ same |

## Performance Comparison

> To be completed after both clusters are running — run Locust against both endpoints with the same load profile.

```bash
# GCP endpoint
locust -f tests/performance/locustfile.py --host=http://<GCP_EXTERNAL_IP> --headless -u 50 -r 5 --run-time 2m --html=results-gcp.html

# DigitalOcean endpoint  
locust -f tests/performance/locustfile.py --host=http://<DO_EXTERNAL_IP> --headless -u 50 -r 5 --run-time 2m --html=results-do.html
```

| Metric | GCP (us-central1) | DigitalOcean (nyc1) |
|--------|-------------------|---------------------|
| p50 latency | TBD | TBD |
| p95 latency | TBD | TBD |
| p99 latency | TBD | TBD |
| RPS | TBD | TBD |
| Error rate | TBD | TBD |

## Cost Comparison

| Cost item | GCP | DigitalOcean |
|-----------|-----|--------------|
| Control plane | $0.10/h | **$0** |
| 2 nodes (8h/day) | ~$0.38/day spot | ~$0.29/day |
| Monthly (8h/day) | ~$11.40 | ~$8.70 |
| **Winner** | | **DigitalOcean ~24% cheaper** |

## Jenkins Pipeline Integration

The master Jenkinsfile deploys to cloud2 after GCP prod as an optional stage.
Credential required: `kubeconfig-cloud2` (FileCredentials in Jenkins).

```groovy
stage('Deploy to Cloud2 (DigitalOcean)') {
    when { branch 'master' }
    steps {
        withCredentials([file(credentialsId: 'kubeconfig-cloud2', variable: 'KUBECONFIG_CLOUD2')]) {
            sh '''
                export KUBECONFIG=$KUBECONFIG_CLOUD2
                kubectl apply -f k8s/cloud2/
            '''
        }
    }
}
```
