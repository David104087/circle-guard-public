# Infrastructure Diagram

CircleGuard infrastructure across GCP (primary) and DigitalOcean (secondary), each with dev, stage, and prod environments.

## System overview

```mermaid
graph TB
    subgraph GCP["GCP Project: tallerfinal-496702 (us-central1)"]

        AR["Artifact Registry\nus-central1-docker.pkg.dev\n/tallerfinal-496702/circleguard"]
        SM["Secret Manager\nSecrets per env\n(passwords, JWT, Docker Hub)"]
        GCS["GCS Bucket\ncircle-guard-tfstate-496702\nTerraform remote state"]

        subgraph DEV["VPC: circleguard-dev (10.10.0.0/16)"]
            SN_DEV["Subnet: 10.10.0.0/24\nPods: 10.10.4.0/22\nSvcs: 10.10.8.0/24"]
            subgraph GKE_DEV["GKE: circleguard-dev (regional)"]
                NP_DEV["Node Pool: default-pool\ne2-standard-2 Spot\n0–3 nodes/zone"]
                subgraph NS_DEV["Namespace: circleguard-dev"]
                    AUTH_D["auth-service :8180"]
                    DASH_D["dashboard-service :8084"]
                    FILE_D["file-service :8085"]
                    FORM_D["form-service :8086"]
                    GW_D["gateway-service :8087"]
                    ID_D["identity-service :8083"]
                    NOTIF_D["notification-service :8082"]
                    PROMO_D["promotion-service :8088"]
                end
            end
            LB_DEV["GCP External LB"]
        end

        subgraph STAGE["VPC: circleguard-stage (10.20.0.0/16)"]
            SN_STG["Subnet: 10.20.0.0/24\nPods: 10.20.4.0/22\nSvcs: 10.20.8.0/24"]
            subgraph GKE_STG["GKE: circleguard-stage (regional)"]
                NP_STG["Node Pool: default-pool\ne2-standard-2 Spot\n0–3 nodes/zone"]
                NS_STG["Namespace: circleguard-stage\n8 microservices"]
            end
        end

        subgraph PROD["VPC: circleguard-prod (10.30.0.0/16)"]
            SN_PRD["Subnet: 10.30.0.0/24\nPods: 10.30.4.0/22\nSvcs: 10.30.8.0/24"]
            subgraph GKE_PRD["GKE: circleguard-prod (regional)"]
                NP_PRD["Node Pool: default-pool\ne2-standard-2 regular\n0–5 nodes/zone"]
                NS_PRD["Namespace: circleguard-production\n8 microservices"]
            end
            LB_PRD["GCP External LB"]
        end

    end

    subgraph DO["DigitalOcean (nyc1) — Multi-Cloud Secondary (3 envs)"]

        subgraph DOKS_DEV["DOKS: circleguard-do-dev"]
            NP_DO_DEV["Node Pool: default-pool\ns-4vcpu-8gb\nmax 1 node (DO account limit)"]
            subgraph NS_DO_DEV["Namespace: circleguard-do-dev"]
                SVCS_DO_DEV["8 microservices\n+ Istio sidecar\n+ STRICT mTLS\n+ infra: Kafka/Postgres/Redis/Neo4j/Mailhog"]
            end
        end
        LB_DO_DEV["DO Load Balancer (dev)"]

        subgraph DOKS_STG["DOKS: circleguard-do-stage"]
            NP_DO_STG["Node Pool: default-pool\ns-2vcpu-4gb\nmax 1 node (DO account limit)"]
            subgraph NS_DO_STG["Namespace: circleguard-do-stage"]
                SVCS_DO_STG["8 microservices + Istio STRICT mTLS\n(infra sidecars disabled to save memory)"]
            end
        end

        subgraph DOKS_PRD["DOKS: circleguard-do-prod"]
            NP_DO_PRD["Node Pool: default-pool\ns-2vcpu-4gb\nmax 1 node (DO account limit)"]
            subgraph NS_DO_PRD["Namespace: circleguard-do-prod"]
                SVCS_DO_PRD["8 microservices + Istio STRICT mTLS\n(infra sidecars disabled to save memory)"]
            end
        end
        LB_DO_PRD["DO Load Balancer (prod)"]

    end

    Internet --> LB_DEV
    Internet --> LB_PRD
    Internet --> LB_DO_DEV
    Internet --> LB_DO_PRD
    LB_DEV --> NS_DEV
    LB_PRD --> NS_PRD
    LB_DO_DEV --> NS_DO_DEV
    LB_DO_PRD --> NS_DO_PRD
    NS_DEV --> AR
    NS_STG --> AR
    NS_PRD --> AR
    NS_DEV --> SM
    NS_STG --> SM
    NS_PRD --> SM
    GCS -.->|"Terraform state\nenvs/do-dev\|do-stage\|do-prod"| DOKS_DEV
    GCS -.->|"Terraform state\nenvs/do-dev\|do-stage\|do-prod"| DOKS_STG
    GCS -.->|"Terraform state\nenvs/do-dev\|do-stage\|do-prod"| DOKS_PRD
```

## Terraform state layout

```
gs://circle-guard-tfstate-496702/
  envs/
    dev/      ← VPC + GKE dev + AR + Secrets dev + IAM dev
    stage/    ← VPC + GKE stage + Secrets stage + IAM stage
    prod/     ← VPC + GKE prod + Secrets prod + IAM prod
    do-dev/   ← DOKS circleguard-do-dev
    do-stage/ ← DOKS circleguard-do-stage
    do-prod/  ← DOKS circleguard-do-prod
```

## IAM service accounts per GCP environment

Each GCP env creates the following Google Service Accounts, bound to Kubernetes SAs via Workload Identity:

| GCP SA | Purpose |
|--------|---------|
| `cg-auth-<env>` | auth-service pod identity |
| `cg-dashboard-<env>` | dashboard-service pod identity |
| `cg-file-<env>` | file-service pod identity |
| `cg-form-<env>` | form-service pod identity |
| `cg-notification-<env>` | notification-service pod identity |
| `cg-promotion-<env>` | promotion-service pod identity |
| `cg-eso-<env>` | External Secrets Operator (Secret Manager access) |
| `cg-jenkins-<env>` | Jenkins deploy SA |
| `cg-gke-<env-short>` | GKE node pool SA (logging, monitoring, AR pull) |

> DigitalOcean clusters do not use Workload Identity — RBAC and K8s Secrets are used directly. External Secrets Operator on DO clusters can optionally pull from GCP Secret Manager using a service account key stored as a K8s Secret.
