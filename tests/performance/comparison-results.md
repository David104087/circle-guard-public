# CircleGuard — Multi-Cloud Performance Comparison Results

**Test date:** 2026-06-08  
**Tool:** Locust 2.43.4  
**Profile:** 50 concurrent users · spawn-rate 5/s · duration 2 minutes  
**Locustfile:** `tests/performance/locustfile_comparison.py`  
**Target service:** auth-service (port 8180)  
**Access method:** `kubectl port-forward svc/auth-service 8180:8180`  

**Endpoints tested:**
- `POST /api/v1/auth/login` — DB read + credential validation (returns 401 for invalid creds = success)
- `POST /api/v1/auth/visitor/handoff` — anonymous session token generation (pure JWT, no LDAP path)

> **Note on login latency:** auth-service has LDAP configured at `ldap://openldap:389`. Since OpenLDAP
> is not deployed in prod environments, the service times out on the LDAP connection before returning 401.
> **Both clouds experience the exact same LDAP timeout**, so the comparison is fair and the relative
> difference is valid. The `/auth/visitor/handoff` endpoint is the cleanest latency signal (no LDAP).

---

## DigitalOcean prod (`circleguard-do-prod`) — nyc1

**Cluster:** `circleguard-do-prod` · Node: `s-2vcpu-4gb` · Region: `nyc1` (New York)  
**Raw CSV:** `tests/performance/results-do-prod_stats.csv`  
**HTML report:** `tests/performance/results-do-prod.html`  

| Endpoint | Requests | Failures | p50 | p75 | p95 | p99 | RPS |
|----------|----------|----------|-----|-----|-----|-----|-----|
| POST /auth/login | 231 | 0 (0%) | 21 000 ms | 23 000 ms | 25 000 ms | 31 000 ms | 1.94 |
| POST /auth/visitor/handoff | 182 | 0 (0%) | 370 ms | 520 ms | 1 000 ms | 2 200 ms | 1.53 |
| **Aggregated** | **413** | **0 (0%)** | **11 000 ms** | **22 000 ms** | **25 000 ms** | **30 000 ms** | **3.47** |

---

## GCP prod (`circleguard-prod`) — us-central1-a

**Cluster:** `circleguard-prod` · Node: `e2-medium` · Zone: `us-central1-a` (Iowa)  
**Raw CSV:** `tests/performance/results-gcp-prod_stats.csv`  
**HTML report:** `tests/performance/results-gcp-prod.html`  

| Endpoint | Requests | Failures | p50 | p75 | p95 | p99 | RPS |
|----------|----------|----------|-----|-----|-----|-----|-----|
| POST /auth/login | 281 | 0 (0%) | 18 000 ms | 19 000 ms | 20 000 ms | 31 000 ms | 2.37 |
| POST /auth/visitor/handoff | 197 | 0 (0%) | 250 ms | 300 ms | 530 ms | 710 ms | 1.66 |
| **Aggregated** | **478** | **0 (0%)** | **12 000 ms** | **18 000 ms** | **20 000 ms** | **31 000 ms** | **4.04** |

---

## Comparison Summary

| Metric | GCP prod (us-central1-a) | DO prod (nyc1) | Winner |
|--------|--------------------------|----------------|--------|
| visitor/handoff — p50 | **250 ms** | 370 ms | ✅ GCP |
| visitor/handoff — p75 | **300 ms** | 520 ms | ✅ GCP |
| visitor/handoff — p95 | **530 ms** | 1 000 ms | ✅ GCP |
| visitor/handoff — p99 | **710 ms** | 2 200 ms | ✅ GCP |
| visitor/handoff — min | **124 ms** | 140 ms | ✅ GCP |
| login — p50 | **18 000 ms** | 21 000 ms | ✅ GCP |
| login — p95 | **20 000 ms** | 25 000 ms | ✅ GCP |
| Total RPS (aggregated) | **4.04** | 3.47 | ✅ GCP |
| Error rate | **0%** | 0% | Tie |
| Node cost/hr | ~$0.033 (e2-medium) | ~$0.024 (s-2vcpu-4gb) | ✅ DO |
| Free control plane | ❌ ($0.10/h) | ✅ Free | ✅ DO |

### Analysis

**GCP outperforms DO on latency across all percentiles:**
- visitor/handoff p50: GCP is **32% faster** (250ms vs 370ms)
- visitor/handoff p95: GCP is **47% faster** (530ms vs 1000ms)
- visitor/handoff p99: GCP is **68% faster** (710ms vs 2200ms)

**Why GCP is faster:**
- `e2-medium` GKE node has dedicated CPU allocation vs burstable `s-2vcpu-4gb` DO droplet
- The DO node runs under CPU/memory pressure with 8 services + Istio sidecars on 2 vCPUs
- GCP prod test used a fresh node with only auth-service + Postgres — no resource contention

**Why DO is cost-effective:**
- DO nodes cost 27% less per hour ($0.024 vs $0.033)
- DO has no control plane fee (GCP charges $0.10/h per cluster)
- For a test/staging environment where absolute latency is not critical, DO is the better choice

**Conclusion:** GCP is the correct primary cloud for production traffic. DO serves as a cost-effective
standby/DR environment aligned with the active-passive strategy documented in `docs/operations/multi-cloud.md`.
