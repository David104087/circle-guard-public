# CircleGuard — Terraform Infrastructure

Provisions GKE clusters and supporting GCP resources for dev, stage, and prod environments.

## Prerequisites

- `terraform >= 1.6` on PATH
- `gcloud` authenticated: `gcloud auth login && gcloud auth application-default login`
- GCP project: `tallerfinal-496702`
- Terraform SA key at `~/.gcp/terraform-key.json` (for CI; local uses ADC)

## Module layout

```
terraform/
  modules/
    vpc/              VPC network, subnet with secondary IP ranges, firewall rules
    gke/              GKE cluster (regional), node pool with autoscaling + Spot option
    artifact_registry/ Docker repository in Artifact Registry
    secrets/          Secret Manager secret containers (no values — only shells)
    iam/              Service accounts for microservices, Jenkins, ESO + WI bindings
  envs/
    dev/              1 node/zone, Spot e2-standard-2, autoscale 0–3
    stage/            1 node/zone, Spot e2-standard-2, autoscale 0–3
    prod/             1 node/zone, regular e2-standard-2, autoscale 0–5
```

## Remote state

All state stored in GCS: `gs://circle-guard-tfstate-496702/`

| Env   | State prefix   |
|-------|----------------|
| dev   | `envs/dev`     |
| stage | `envs/stage`   |
| prod  | `envs/prod`    |

## Provision a new environment (from scratch)

```bash
# 1. Authenticate
gcloud auth login
gcloud auth application-default login
gcloud config set project tallerfinal-496702

# 2. Init and apply
cd terraform/envs/<env>
terraform init
terraform apply

# 3. Update kubeconfig
gcloud container clusters get-credentials circleguard-<env> \
  --region us-central1 --project tallerfinal-496702
```

## Destroy an environment (to save costs)

```bash
cd terraform/envs/<env>
terraform destroy
```

> `deletion_protection = false` is set explicitly in the GKE module so destroy works without manual intervention.

## Network addressing

| Env   | Nodes           | Pods            | Services        |
|-------|-----------------|-----------------|-----------------|
| dev   | 10.10.0.0/24    | 10.10.4.0/22    | 10.10.8.0/24    |
| stage | 10.20.0.0/24    | 10.20.4.0/22    | 10.20.8.0/24    |
| prod  | 10.30.0.0/24    | 10.30.4.0/22    | 10.30.8.0/24    |

## Key variables per env

| Variable      | dev              | stage            | prod             |
|---------------|------------------|------------------|------------------|
| machine_type  | e2-standard-2    | e2-standard-2    | e2-standard-2    |
| use_spot      | true             | true             | false            |
| node_count    | 1/zone           | 1/zone           | 1/zone           |
| min_nodes     | 0/zone           | 0/zone           | 0/zone           |
| max_nodes     | 3/zone           | 3/zone           | 5/zone           |

## Cost management

Run `./ci/session-stop.sh` to scale nodes to 0 (or destroy) between sessions.
Run `./ci/session-start.sh` to bring nodes back up. See [docs/operations/costs.md](../docs/operations/costs.md).

## Artifact Registry

Created once in `envs/dev`. URL: `us-central1-docker.pkg.dev/tallerfinal-496702/circleguard`

All three environments share the same registry. Stage and prod do not re-create it.
