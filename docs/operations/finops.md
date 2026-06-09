# CircleGuard — FinOps Strategy

## Overview

FinOps (Financial Operations for Cloud) is the practice of applying financial accountability to cloud spending. For CircleGuard, this means:

1. **Visibility** — knowing exactly what each service costs (Kubecost + GCP Billing Export + Grafana)
2. **Optimization** — removing waste without degrading service (spot VMs, zonal clusters, scale-to-zero)
3. **Automation** — enforcing savings policies without manual intervention (session scripts, autoscaler)

**Phase 13 status:** ✅ COMPLETE — all 8 tasks implemented.

---

## 1. Cost Monitoring Tools

### Kubecost (Task 13.2) ✅

Kubecost provides per-namespace and per-pod cost allocation using Prometheus metrics. It shows which workloads cost the most, where waste is occurring, and what the projected monthly spend is.

**Installed version:** 2.8.6 (⚠️ do NOT use 2.9.x — that is a migration-only version that fails with a hard error)

**Install command (use this verbatim):**
```bash
helm repo add kubecost https://kubecost.github.io/cost-analyzer/ && helm repo update
helm install kubecost kubecost/cost-analyzer --version 2.8.6 \
  -n kubecost --create-namespace \
  --set global.clusterId=circleguard-dev \
  --set kubecostProductConfigs.clusterName=circleguard-dev \
  --set kubecostProductConfigs.currencyCode=USD \
  --set networkCosts.enabled=false \
  --wait --timeout=6m
```

**Reinstall after spot preemption (delete stuck PVCs first):**
```bash
helm uninstall kubecost -n kubecost
kubectl delete pvc --all -n kubecost
kubectl delete namespace kubecost
# then re-run the install command above
```

**Access UI:**
```bash
kubectl port-forward --namespace kubecost deployment/kubecost-cost-analyzer 9090
# Open: http://localhost:9090
# Allow ~25 min for initial metrics collection after fresh install
```

Kubecost bundles its own Prometheus and Grafana — no dependency on the kube-prometheus-stack for basic cost monitoring.

**What Kubecost shows:**
- Cost breakdown per namespace (`circleguard-dev`, `circleguard-stage`, `circleguard-production`)
- Cost breakdown per workload/pod
- Efficiency score (requested vs actual CPU/memory)
- Projected monthly spend
- Savings recommendations

### GCP Billing Export to BigQuery (Task 13.1) ✅

Enables real billing data (not estimates) queryable via SQL. Both export types are active.

**Status:** ✅ Active — both exports enabled on billing account `019044-EE5C1C-F61E8F`.

| Export type | Status |
|-------------|--------|
| Standard usage cost | ✅ Enabled |
| Detailed usage cost | ✅ Enabled |

Evidence screenshots:
- [`docs/diagrams/finops/costo_uso_estandar.png`](../diagrams/finops/costo_uso_estandar.png)
- [`docs/diagrams/finops/costo_uso_detallado.png`](../diagrams/finops/costo_uso_detallado.png)

Dataset: `tallerfinal-496702.billing_export` (region US). First data appears ~24–48h after activation.

**Query — cluster cost by day:**
```sql
SELECT
  DATE(usage_start_time) AS date,
  labels.value AS cluster,
  SUM(cost) AS total_cost_usd
FROM `tallerfinal-496702.billing_export.gcp_billing_export_v1_*`
JOIN UNNEST(labels) AS labels ON labels.key = 'gke-cluster'
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC
```

### Grafana FinOps Dashboard (Task 13.3) ✅

Dashboard `circleguard-finops` in Grafana, sourcing Kubecost Prometheus metrics.

**File:** [`k8s/monitoring/dashboards/finops.json`](../../k8s/monitoring/dashboards/finops.json)

**What it shows:**
- CPU/Memory request utilization % (requested vs actual usage)
- Wasted memory per service (over-requested but unused)
- Node efficiency (CPU/memory used vs total allocatable)
- Estimated hourly cost per service (CPU-based, spot pricing)

**Apply to existing Grafana:**
```bash
kubectl apply -k k8s/monitoring/dashboards/
```

---

## 2. Implemented Savings Strategies

### Strategy 1 — Scale to Zero Between Sessions (Task 13.4) ✅

**Tool:** `ci/session-stop.sh`

**How it works:** Scales all GKE clusters AND DigitalOcean clusters to 0 nodes when the team stops working. Nodes are billed by the second — at 0 nodes, only the GKE control plane ($0.10/h per cluster) is charged.

```bash
ci/session-stop.sh            # scale all GKE + DO clusters to 0 (~2 min)
ci/session-stop.sh destroy    # terraform destroy all GCP envs (~5 min to recreate)
```

**Estimated savings:**
| Scenario | Daily cost | Monthly |
|----------|-----------|---------|
| Nodes up 24/7 (baseline) | $26.40 | ~$792 |
| Scale-to-zero (8h/day work) | $13.60 | ~$408 |
| **Savings** | **~$13/day** | **~$380/month** |

### Strategy 2 — Spot VMs for Dev and Stage (Task 13.5) ✅

**Tool:** `terraform/modules/gke/`, variable `use_spot`

**How it works:** GKE node pools for `dev` and `stage` use Spot (Preemptible) VMs. They can be reclaimed by GCP with 30s notice but are typically stable during business hours.

**Configuration (already applied):**
```hcl
# terraform/envs/dev/main.tf
use_spot = true   # ~64% cheaper than on-demand

# terraform/envs/stage/main.tf
use_spot = true

# terraform/envs/prod/main.tf
use_spot = false  # prod stays on-demand for stability
```

**Pricing comparison (e2-standard-2, us-central1):**
| Type | Price/hour | Monthly (8h/day) | Savings |
|------|-----------|-----------------|---------|
| On-demand | $0.067/node | ~$16/cluster | baseline |
| Spot | $0.024/node | ~$5.76/cluster | **64% cheaper** |

**Note on preemption:** If a spot node is preempted, the GKE autoscaler provisions a replacement automatically. For Kubecost and stateful workloads, delete stuck PVCs after preemption (see Kubecost reinstall instructions above).

### Strategy 3 — Accurate Resource Requests for Precise Attribution (Task 13.6) ✅

**Tool:** K8s manifests (`k8s/dev/`, `k8s/stage/`, `k8s/production/`)

**How it works:** Memory requests corrected to reflect actual Spring Boot JVM usage (256Mi baseline). Accurate requests enable:
- Kubecost to correctly attribute costs per pod (inaccurate requests = wrong cost allocation)
- Cluster autoscaler to make correct scale-up/down decisions
- Better bin-packing: fewer nodes needed when requests match reality

| Resource | Value | Reason |
|----------|-------|--------|
| Memory request | 256Mi | Spring Boot JVM baseline ~200Mi |
| Memory limit | 512Mi | Headroom for load spikes |
| CPU request | 50–100m | Adequate for idle Spring Boot |
| CPU limit | 500m–1 | Burst capacity |

All 8 services verified across all 3 GCP environments (dev/stage/production).

### Strategy 4 — Zonal Clusters Instead of Regional for Dev (implemented 2026-06-09)

**How it works:** Regional GKE clusters create 1 node per zone (3 zones = 3 nodes = 6 vCPUs). Switching dev to a zonal cluster in `us-central1-a` means 1 node total = 2 vCPUs.

**Impact:**
- Node cost: 3× cheaper (1 node vs 3)
- CPUS_ALL_REGIONS quota: 2 vCPUs instead of 6 per cluster
- Allows running 2 environments simultaneously within the 12 vCPU quota

**Current config:** `terraform/envs/dev/main.tf` uses `region = "us-central1-a"` (zone).

### Strategy 5 — GCP Budget Alerts ✅

**Tool:** GCP Console → Billing → Presupuestos y alertas

Budget `Alerta250` on billing account `019044-EE5C1C-F61E8F`:
- Monthly threshold alerts at 50% ($125), 90% ($225), 100% ($250)
- Email notification to billing admins automatically

This closes the FinOps feedback loop: optimization reduces spend, budget alert catches deviations.

### Strategy 6 — Namespace Cost Isolation for Idle Detection ✅

**How it works:** Each environment has its own namespace (`circleguard-dev`, `circleguard-stage`, `circleguard-production`). Kubecost tracks cost per namespace, making it easy to identify idle environments.

**Policy:** If a namespace shows zero traffic for >2h (visible in Grafana), scale its cluster to 0 with `ci/session-stop.sh`.

### Strategy 7 — Sequential Cluster Operations (CPUS_ALL_REGIONS quota enforcement)

**How it works:** GCP quota `CPUS_ALL_REGIONS=12` limits total vCPUs across all regions. Session scripts enforce sequential operation: always scale one cluster to 0 before bringing up another.

The `ci/session-stop.sh` script scales ALL clusters in parallel to 0 before stopping, ensuring no accidental dual-cluster state.

---

## 3. Cost Attribution Summary (Task 13.7)

### Per-service cost breakdown (dev namespace, spot pricing)

| Service | CPU Request | Memory Request | Est. cost/h |
|---------|------------|----------------|------------|
| auth-service | 100m | 256Mi | $0.0012 |
| dashboard-service | 100m | 256Mi | $0.0012 |
| file-service | 50m | 256Mi | $0.0006 |
| form-service | 100m | 256Mi | $0.0012 |
| gateway-service | 100m | 256Mi | $0.0012 |
| identity-service | 100m | 256Mi | $0.0012 |
| notification-service | 100m | 256Mi | $0.0012 |
| promotion-service | 100m | 256Mi | $0.0012 |
| **Total (8 services)** | **750m** | **2048Mi** | **$0.0090/h** |
| Istio sidecars | ~400m | ~512Mi | ~$0.005/h |
| Infrastructure (Kafka, PG, etc.) | ~500m | ~1536Mi | ~$0.006/h |
| **Dev namespace total** | **~1650m** | **~4096Mi** | **~$0.020/h** |

Cost per 8-hour dev session: ~**$0.16** (application layer) + ~**$0.19** (node) = ~**$0.35/session**

### Savings implemented — total impact

| Strategy | Monthly savings | Status |
|----------|----------------|--------|
| Scale to zero (session-stop.sh) | ~$380 vs 24/7 baseline | ✅ Automated |
| Spot VMs dev + stage | ~$62 (two clusters) | ✅ Active |
| Zonal dev cluster (1 node vs 3) | ~$18/month (2 nodes eliminated) | ✅ Applied |
| Accurate memory requests | Correct Kubecost attribution | ✅ Applied |
| **Total estimated savings** | **~$460/month vs naïve baseline** | |

---

## 4. Monitoring Workflow

1. **Session start:** `ci/session-start.sh` — starts Jenkins, SonarQube, scales dev to 1 node
2. **Access Kubecost:** `kubectl port-forward --namespace kubecost deployment/kubecost-cost-analyzer 9090`
3. **During work:** check Grafana FinOps dashboard and Kubecost for waste alerts
4. **Cost alert trigger:** if Kubecost shows any service with efficiency <20%, reduce its CPU/memory limit
5. **Session end:** `ci/session-stop.sh` — scales all clusters to 0, stops Docker containers
6. **Overnight/long absence:** `ci/session-stop.sh destroy` — zero control plane cost

---

## 5. Future Optimization Opportunities

| Opportunity | Estimated Savings | Effort | Status |
|-------------|-----------------|--------|--------|
| GKE Autopilot for dev (pay per pod) | ~40% for low-traffic | High (migration) | Not implemented |
| Committed Use Discounts (1-year) | ~37% on on-demand | Low (purchase) | N/A — academic project |
| Share stage/prod namespace (1 cluster) | $0.10/h × 1 cluster | High (ops complexity) | Not recommended |

---

## References

- [Kubecost values](../../k8s/monitoring/kubecost-values.yaml)
- [Grafana FinOps dashboard](../../k8s/monitoring/dashboards/finops.json)
- [GKE spot node pool config](../../terraform/modules/gke/main.tf)
- [Session automation scripts](../../ci/session-stop.sh) — handles GCP + DO clusters
- [Cost analysis (full)](costs.md)
- [GCP Billing screenshots](../diagrams/finops/)
