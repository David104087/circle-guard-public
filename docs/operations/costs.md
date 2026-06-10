# CircleGuard — GCP Cost Analysis

## Infrastructure: GKE Regional Clusters (us-central1)

### Per-environment costs (nodes active)

| Component | Dev | Stage | Prod | Unit cost |
|-----------|-----|-------|------|-----------|
| GKE control plane | $0.10/h | $0.10/h | $0.10/h | per cluster |
| e2-standard-2 nodes (Spot) | 3 × $0.024/h | 3 × $0.024/h | — | per node |
| e2-standard-2 nodes (Regular) | — | — | 3 × $0.067/h | per node |
| pd-standard 50GB per node | 3 × $0.004/h | 3 × $0.004/h | 3 × $0.004/h | per disk |
| **Total per env (nodes up)** | **~$0.39/h** | **~$0.39/h** | **~$0.51/h** | |
| **Total 3 envs simultaneous** | | | **~$1.29/h** | |

> Note: All 3 envs cannot run simultaneously — CPUS_ALL_REGIONS quota = 12 vCPUs. Sequential deployment required.

### Monthly estimates (8h/day usage)

| Scenario | Monthly cost |
|----------|-------------|
| Dev only, 8h/day, nodes scaled to 0 rest of time | ~$25/month |
| Dev + Stage alternating, 8h/day each | ~$45/month |
| All 3 envs with terraform destroy at night | ~$20/month (control planes only during off hours) |

### Actual quotas observed

| Quota | Current limit | Usage (session active) |
|-------|--------------|----------------------|
| CPUS_ALL_REGIONS | 12 vCPUs | 2–12 vCPUs |
| IN_USE_ADDRESSES | 8 | 1–5 |
| SSD_TOTAL_GB | 250 GB | 0 (pd-standard used) |

---

## Cost Optimization Recommendations

### 1. Scale to 0 between sessions (already doing this)
- Control planes: $0.10/h × 3 = $0.30/h even at 0 nodes
- **Savings vs keeping nodes up:** ~$1/h saved while inactive

### 2. Use Spot instances for dev/stage (already configured)
- Dev/stage use `spot = true` in Terraform node pool
- Spot e2-standard-2: $0.024/h vs $0.067/h regular = **64% savings**

### 3. Use `terraform destroy` for overnight (already documented)
- Destroys control planes too: $0 while sleeping
- Recreate time: ~5 minutes per cluster

### 4. Reduce node count from 1/zone to 1 total (future)
- Currently: 1 node per zone = 3 nodes = 6 vCPUs
- Regional clusters require ≥1 node/zone for HA, but for dev zonal clusters work
- Switch to zonal cluster: 1 node = 2 vCPUs → could run all 3 simultaneously

### 5. Use Autopilot (future)
- GKE Autopilot: pay per pod CPU/memory, not per node
- Estimated 40% cheaper for dev workloads with variable traffic

---

## Additional Costs

| Service | Cost | Notes |
|---------|------|-------|
| GCS bucket (Terraform state) | ~$0.02/month | Negligible |
| Artifact Registry | ~$0.10/month | 8 Docker images × ~50MB each |
| Secret Manager | Free tier | <6 secrets accessed <10K times/month |
| Cloud Monitoring | Free tier | Within included quota |
| **Total non-compute** | **~$0.15/month** | |

---

## FinOps — Implemented Savings

> For full strategy documentation see [`docs/operations/finops.md`](finops.md).

### Savings implemented and measured

| Strategy | Monthly savings | Status |
|----------|----------------|--------|
| Scale to zero between sessions (`ci/session-stop.sh`) | ~$380 vs 24/7 baseline | ✅ Automated |
| Spot VMs for dev + stage (`use_spot = true`) | ~$62/month (dev+stage) | ✅ Active |
| Accurate memory requests (64Mi → 256Mi) | Enables correct Kubecost attribution | ✅ Applied |
| Sequential cluster ops (quota enforcement) | Prevents accidental double-run | ✅ Enforced |
| **Total estimated monthly savings** | **~$442/month vs naïve baseline** | |

### Kubecost per-service cost attribution (dev, estimated)

| Service | CPU Request | Memory Request | Est. cost/h |
|---------|------------|----------------|------------|
| 8 CircleGuard services | 750m total | 2048Mi total | $0.0090/h |
| Istio sidecars | ~400m | ~512Mi | ~$0.005/h |
| Infrastructure (Kafka, PG, etc.) | ~500m | ~1536Mi | ~$0.006/h |
| **Dev namespace total** | **~1650m** | **~4096Mi** | **~$0.020/h** |

Cost per 8-hour dev session: ~$0.16 (application layer only, node cost separate).
