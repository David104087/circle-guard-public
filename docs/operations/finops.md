# CircleGuard — FinOps Strategy

## Overview

FinOps (Financial Operations for Cloud) is the practice of applying financial accountability to cloud spending. For CircleGuard, this means:

1. **Visibility** — knowing exactly what each service costs
2. **Optimization** — removing waste without degrading service
3. **Automation** — enforcing savings policies without manual intervention

---

## 1. Cost Monitoring Tools

### Kubecost

Kubecost provides per-namespace and per-pod cost allocation using Prometheus metrics.

**Installation (dev cluster):**
```bash
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm repo update
helm install kubecost kubecost/cost-analyzer \
  -n kubecost --create-namespace \
  -f k8s/monitoring/kubecost-values.yaml
```

**Access UI:**
```bash
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090
# Open: http://localhost:9090
```

Kubecost integrates with the existing kube-prometheus-stack (configured in `k8s/monitoring/kubecost-values.yaml` to use the existing Prometheus at `monitoring` namespace).

### GCP Billing Export to BigQuery

Enables real billing data (not estimates) in Kubecost and custom dashboards.

**Steps (manual — requires Billing Account Admin):**

1. Go to GCP Console → Billing → [Billing Account] → Billing Export
2. Click "Standard Usage Cost" → Edit Settings
3. Dataset: `billing_export` in project `tallerfinal-496702`
4. Click Save

Once exported (~24h for first data), BigQuery dataset `tallerfinal-496702.billing_export` contains line-item costs per resource.

**Useful query to check cluster costs:**
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

### Grafana FinOps Dashboard

Dashboard `circleguard-finops` in Grafana (`k8s/monitoring/dashboards/finops.json`) shows:
- CPU/Memory request utilization % (requested vs actual)
- Wasted memory per service (over-requested but unused)
- Node efficiency (CPU/memory used vs allocatable)
- Estimated hourly cost per service (CPU-based, spot pricing)

Applied automatically via kustomize sidecar:
```bash
kubectl apply -k k8s/monitoring/dashboards/
```

---

## 2. Implemented Savings Strategies

### Strategy 1 — Scale to Zero Between Sessions (automated)

**Tool:** `ci/session-stop.sh`

**How it works:** Scales all GKE clusters to 0 nodes when the team stops working. Nodes are billed by the second — at 0 nodes, only the control plane ($0.10/h per cluster) is charged.

```bash
ci/session-stop.sh            # scale to 0 (quick — ~2 min)
ci/session-stop.sh destroy    # terraform destroy (zero control plane cost — ~5 min to recreate)
```

**Estimated savings:**
- Baseline (nodes up 24/7): ~$1.10/h × 24h = $26.40/day
- With scale-to-zero (8h work day): ~$1.10/h × 8h + $0.30/h × 16h = $13.60/day
- **Savings: ~48% reduction — ~$380/month**

### Strategy 2 — Spot VMs for Dev and Stage

**Tool:** `terraform/modules/gke/`, `use_spot = true`

**How it works:** GKE node pools for `dev` and `stage` use Spot VMs (formerly Preemptible). Spot instances can be reclaimed by GCP with 30s notice but are typically stable during business hours.

**Configuration:**
```hcl
# terraform/envs/dev/main.tf and stage/main.tf
use_spot = true   # already active
```

**Pricing comparison (e2-standard-2, us-central1):**
| Type | Price/hour | Savings |
|------|-----------|---------|
| On-demand | $0.067 | baseline |
| Spot | $0.024 | **64% cheaper** |

**Estimated savings (dev cluster, 8h/day):**
- On-demand: 3 nodes × $0.067 × 8h = $1.61/day
- Spot: 3 nodes × $0.024 × 8h = $0.58/day
- **Savings: $1.03/day = ~$31/month per cluster**

### Strategy 3 — Accurate Resource Requests for Precise Attribution

**Tool:** K8s manifests (`k8s/dev/`, `k8s/stage/`, `k8s/production/`)

**How it works:** Memory requests corrected from 64Mi → 256Mi to reflect actual Spring Boot JVM usage. Accurate requests enable:
- Kubecost to correctly attribute costs per pod
- Cluster autoscaler to make correct scale-up/down decisions
- Bin-packing: fewer nodes needed when requests match reality

**Before:** 64Mi requests → autoscaler under-estimates pod size → over-provisions nodes
**After:** 256Mi requests → correct scheduling → autoscaler can optimize node count

| Resource | Before | After | Why |
|----------|--------|-------|-----|
| Memory request | 64Mi | 256Mi | Spring Boot JVM baseline ~200Mi |
| Memory limit | 512Mi | 512Mi | unchanged — headroom for load spikes |
| CPU request | 100m | 100m | unchanged — adequate for idle services |
| CPU limit | 500m | 500m | unchanged |

### Strategy 4 — GCP Budget Alerts

**Tool:** GCP Console → Billing → Presupuestos y alertas

**How it works:** Budget `Alerta250` is configured on billing account `019044-EE5C1C-F61E8F` with monthly budget and alerts at 50% / 90% / 100% thresholds (~$125 / $225 / $250). Alerts are sent to billing account administrators via email automatically.

This closes the FinOps feedback loop: cost optimization policies (scale-to-zero, spot VMs) reduce spend, and the budget alert catches any accidental deviation (e.g., a cluster left running overnight).

**No action required** — alert is already active in GCP Console.

### Strategy 5 — Namespace Isolation for Idle Cost Detection

**How it works:** Each environment has its own namespace (`circleguard-dev`, `circleguard-stage`, `circleguard-production`). Kubecost tracks cost per namespace, making it easy to identify which environment is being actively used and which is idle.

**Policy:** If a namespace shows zero traffic for >2h (visible in Grafana), scale its cluster to 0.

### Strategy 6 — Sequential Cluster Operations (CPUS_ALL_REGIONS quota)

**How it works:** The GCP project has a `CPUS_ALL_REGIONS=12` quota. Running all 3 clusters simultaneously (18 vCPUs) exceeds this limit. Operating sequentially (one cluster at a time) is enforced by the session scripts.

This also indirectly saves money: you cannot accidentally leave two large clusters running simultaneously.

---

## 3. Future Optimization Opportunities

| Opportunity | Estimated Savings | Effort | Status |
|-------------|-----------------|--------|--------|
| Switch dev to zonal cluster (1 node total vs 3) | ~66% node cost reduction | Medium | Not implemented |
| GKE Autopilot for dev (pay per pod, not node) | ~40% for low-traffic workloads | High (migration) | Not implemented |
| Committed Use Discounts (1-year) for prod | ~37% on on-demand pricing | Low (purchase) | Not applicable (project academic) |
| Reduce control plane count (share stage/prod namespace) | $0.10/h × 1 cluster saved | High (ops complexity) | Not recommended |

---

## 4. Cost Attribution Summary

| Service | CPU Request | Memory Request | Est. cost/h (spot) |
|---------|------------|----------------|-------------------|
| auth-service | 100m | 256Mi | $0.0012 |
| dashboard-service | 100m | 256Mi | $0.0012 |
| file-service | 50m | 256Mi | $0.0006 |
| form-service | 100m | 256Mi | $0.0012 |
| gateway-service | 100m | 256Mi | $0.0012 |
| identity-service | 100m | 256Mi | $0.0012 |
| notification-service | 100m | 256Mi | $0.0012 |
| promotion-service | 100m | 256Mi | $0.0012 |
| **Total (8 services)** | **750m** | **2048Mi** | **$0.0090/h** |
| Istio sidecars (overhead) | ~400m | ~512Mi | ~$0.005/h |
| Infrastructure (Kafka, PG, etc.) | ~500m | ~1536Mi | ~$0.006/h |
| **Grand total dev namespace** | **~1650m** | **~4096Mi** | **~$0.020/h** |

Cost per 8-hour dev session: ~$0.16 (services only, excluding node cost).

---

## 5. Monitoring Workflow

1. At session start: `ci/session-start.sh`
2. During work: check Grafana FinOps dashboard for waste alerts
3. If "Wasted Memory" panel shows a service >200Mi consistently wasted → reduce its limit
4. At session end: `ci/session-stop.sh` (or `destroy` for overnight)
5. Weekly: review Kubecost allocation report to catch drift

---

## References

- [Kubecost values](../../k8s/monitoring/kubecost-values.yaml)
- [Grafana FinOps dashboard](../../k8s/monitoring/dashboards/finops.json)
- [GKE spot node pool config](../../terraform/modules/gke/main.tf)
- [Session automation scripts](../../ci/session-stop.sh)
- [Cost analysis](costs.md)
