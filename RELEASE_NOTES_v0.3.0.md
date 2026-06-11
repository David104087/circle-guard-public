# Release Notes – CircleGuard v0.3.0

**Release Date:** 2026-06-10
**Environment:** Production
**Docker Hub:** `davidartunduaga/circleguard-*:v0.3.0`

---

## Deployed Services

| Service | Port | Image Tag |
|---------|------|-----------|
| auth-service | 8180 | `v0.3.0` |
| dashboard-service | 8084 | `v0.3.0` |
| file-service | 8085 | `v0.3.0` |
| form-service | 8086 | `v0.3.0` |
| gateway-service | 8087 | `v0.3.0` |
| identity-service | 8083 | `v0.3.0` |
| notification-service | 8082 | `v0.3.0` |
| promotion-service | 8088 | `v0.3.0` |

---

## Changes in this Release

### New Features

- feat(chaos): complete Phase 12 — Chaos Engineering with Chaos Mesh v2.7.0; 5 experiments executed, 2 system improvements implemented

### Documentation

- docs(chaos): fix timing inaccuracies and add architectural learnings section to results.md
- docs(ops): patch documentation gaps for final evaluation — EFK justification, security.md cleanup, new alerts.md

### All Commits

See [commits between v0.2.0 and v0.3.0](https://github.com/David104087/circle-guard-public/compare/v0.2.0...v0.3.0)

---

## Highlights

### Phase 12 — Chaos Engineering (Bonus 5%) ✅

**Tool:** Chaos Mesh v2.7.0, namespace `chaos-testing`, `securityMode=false`

#### 5 Experiments Executed

| # | Type | Target | Result |
|---|------|--------|--------|
| 1 | PodChaos (pod-kill) | notification-service | Pod replaced in **~66 seconds** — within SLA |
| 2 | NetworkChaos (delay 200ms ±50ms) | form-service → notification-service | AllInjected=True; both pods Running; instant recovery |
| 3 | NetworkChaos (partition 100% loss) | gateway-service → auth-service | gateway stayed Running 50s; confirms need for CB |
| 4 | StressChaos (80% CPU) | dashboard-service | CPU 2m→500m throttled; 0 restarts; returned in <5s |
| 5 | PodChaos (pod-kill) | kafka | Kafka Running again in **~10 seconds**; consumer reconnected automatically |

#### 2 Improvements Committed

1. **`holdApplicationUntilProxyStarts: true`** annotation on auth, dashboard, form, identity services — prevents CrashLoopBackOff from Istio sidecar timing race during pod reschedules
2. **Kafka reconnect backoff tuned** to 500ms initial / 5000ms max in form-service and notification-service ConfigMaps — faster recovery from broker restarts

#### Pipeline Integration

`Chaos Smoke Test` stage added to `ci/Jenkinsfile.dev`: applies pod-kill on notification-service post-deploy, waits 60s for recovery, cleans up CRD automatically.

### Documentation Improvements

- **`docs/operations/observability.md`**: EFK vs ELK justification — Fluent Bit chosen for 10x lower memory (~50MB vs ~512MB), functionally equivalent for log collection/parsing/forwarding
- **`docs/operations/security.md`**: Honest TLS implementation status — cert-manager manifests ready, blocked by academic project constraint (no public DNS domain)
- **`docs/operations/alerts.md`**: New dedicated file with PromQL expressions, source file references (`alerting-rules.yaml`), Alertmanager channel, and remediation runbook for all 6 alert rules

---

## Test Summary

| Metric | Value |
|--------|-------|
| Chaos experiments | 5/5 executed |
| System improvements | 2 implemented |
| Pipeline stages added | 1 (Chaos Smoke Test) |
| Build Number | N/A (manual release) |

---

## Deployment Checklist

- [x] All chaos experiments documented in `docs/chaos/results.md`
- [x] Improvements committed to `k8s/dev/` manifests
- [x] Chaos Smoke Test stage added to dev Jenkinsfile
- [x] Documentation gaps patched for final evaluation
- [x] All existing tests still passing

---

*Generated manually for CircleGuard v0.3.0 — Chaos Engineering bonus.*
