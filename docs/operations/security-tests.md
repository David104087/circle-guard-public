# CircleGuard — Security Tests

## OWASP ZAP Baseline Scan

**Script:** `tests/security/zap-baseline.sh`
**Target:** Istio ingress gateway external IP (auto-detected from `kubectl`)
**Mode:** Baseline scan — passive analysis only, no active attacks

### How to run manually

```bash
# Auto-detect IP from kubectl
./tests/security/zap-baseline.sh

# Specify IP explicitly
./tests/security/zap-baseline.sh 35.253.156.137

# With INGRESS_IP env var
INGRESS_IP=35.253.156.137 ./tests/security/zap-baseline.sh
```

Report is saved to `tests/security/zap-report.html`.

### Pipeline integration (stage)

The `ZAP Security Scan` stage in `ci/Jenkinsfile.stage` runs automatically after deploy. It is **non-blocking** (`|| true`) — pipeline passes even if ZAP finds issues. Report is archived as a Jenkins artifact.

### Graduation criteria (when to make it blocking)

Make the stage fail the build (`remove || true`) when:
1. No CRITICAL findings remain (ZAP risk level = HIGH or CRITICAL causes failure)
2. All known false positives have been suppressed via a ZAP context file

Current status: **non-blocking** (informational only).

### Known findings (from first baseline run)

To be populated after first pipeline run against live environment.
