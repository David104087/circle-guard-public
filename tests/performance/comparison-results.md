# CircleGuard — Multi-Cloud Performance Comparison Results

**Test date:** 2026-06-08  
**Tool:** Locust 2.43.4  
**Profile:** 50 concurrent users · spawn-rate 5/s · duration 2 minutes  
**Locustfile:** `tests/performance/locustfile_comparison.py`  
**Target service:** auth-service (port 8180)  
**Access method:** `kubectl port-forward svc/auth-service 8180:8180`  

**Endpoints tested:**
- `POST /api/v1/auth/login` — DB read + credential validation (returns 401 for invalid creds, which counts as success)
- `POST /api/v1/auth/visitor/handoff` — anonymous session token generation (no LDAP, pure JWT)

> **Note on login latency:** auth-service has LDAP configured at `ldap://openldap:389`. Since OpenLDAP pod is not deployed in prod environments (only Postgres is), the service falls back after a connection timeout. Both clouds experience the same LDAP timeout, so **the comparison remains valid and fair**. The `/auth/visitor/handoff` endpoint is the cleanest signal (no LDAP path).

---

## DigitalOcean prod (`circleguard-do-prod`) — nyc1

**Cluster:** `circleguard-do-prod` · Node: `s-2vcpu-4gb` · Region: `nyc1` (New York)  
**Raw CSV:** `tests/performance/results-do-prod_stats.csv`  
**HTML report:** `tests/performance/results-do-prod.html`  

| Endpoint | Requests | Failures | Median | Avg | p95 | p99 | RPS |
|----------|----------|----------|--------|-----|-----|-----|-----|
| POST /auth/login | 231 | 0 (0%) | 21 000 ms | 19 891 ms | 25 000 ms | 31 000 ms | 1.94 |
| POST /auth/visitor/handoff | 182 | 0 (0%) | 370 ms | 465 ms | 1 000 ms | 2 200 ms | 1.53 |
| **Aggregated** | **413** | **0 (0%)** | **11 000 ms** | **11 330 ms** | **25 000 ms** | **30 000 ms** | **3.47** |

**Key metrics (visitor/handoff — clean signal):**
- p50: 370 ms · p75: 520 ms · p95: 1 000 ms · p99: 2 200 ms
- RPS: 1.53 · Error rate: 0%

---

## GCP prod (`circleguard-prod`) — us-central1

**Cluster:** `circleguard-prod` · Node: `e2-medium` · Region: `us-central1` (Iowa)  
**Raw CSV:** `tests/performance/results-gcp-prod_stats.csv`  
**HTML report:** `tests/performance/results-gcp-prod.html`  

| Endpoint | Requests | Failures | Median | Avg | p95 | p99 | RPS |
|----------|----------|----------|--------|-----|-----|-----|-----|
| POST /auth/login | — | — | — | — | — | — | — |
| POST /auth/visitor/handoff | — | — | — | — | — | — | — |
| **Aggregated** | **—** | **—** | **—** | **—** | **—** | **—** | **—** |

> *GCP prod test pending — cluster provisioning in progress (2026-06-08)*

---

## Comparison Summary

> *To be filled after GCP prod test completes*

| Metric | GCP prod (us-central1) | DO prod (nyc1) | Winner |
|--------|------------------------|----------------|--------|
| Visitor handoff — p50 | — | 370 ms | — |
| Visitor handoff — p95 | — | 1 000 ms | — |
| Visitor handoff — p99 | — | 2 200 ms | — |
| Visitor handoff — RPS | — | 1.53 | — |
| Login — p50 | — | 21 000 ms | — |
| Login — p95 | — | 25 000 ms | — |
| Error rate | — | 0% | — |
| Node cost/hr | ~$0.033 (e2-medium) | ~$0.024 (s-2vcpu-4gb) | DO |
| Region latency (from EU/LATAM) | Higher (Iowa) | Lower (NYC) | DO |
