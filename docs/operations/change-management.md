# CircleGuard — Change Management Process

## Overview

CircleGuard follows a pipeline-gated change management process. Every change to production must pass automated quality gates and a human approval step before deployment.

---

## Who Can Request a Change

| Role | Can request | Can approve |
|------|-------------|-------------|
| Developer | ✅ Open PR | ❌ |
| Tech Lead | ✅ Open PR | ✅ Merge PR |
| DevOps | ✅ Open PR | ✅ Canary approve |

---

## Change Flow

```
Developer opens PR (feat/... or fix/...)
        │
        ▼
Automated checks on PR:
  • SonarQube quality gate
  • Unit + Integration tests (DEV pipeline)
  • Trivy scan (no new CRITICAL)
        │
        ▼
Tech Lead reviews + approves PR
        │
        ▼
PR merged to master
        │
        ▼
MASTER pipeline triggers:
  1. Build + SonarQube
  2. Unit + Integration + E2E tests
  3. Docker build + Trivy
  4. Deploy to production
  5. Canary at 10% traffic (auth-service v2)
  6. ⏳ Human approves canary (30 min window)
        │
        ▼
Canary promoted to 100%
        │
        ▼
Release Notes generated + GitHub Release published
```

---

## Quality Gates

| Gate | Tool | Threshold | Blocking? |
|------|------|-----------|-----------|
| Code quality | SonarQube | Quality gate "Passed" | ✅ Yes |
| Test coverage | JaCoCo | ≥60% line coverage | ✅ Yes |
| Vulnerability scan | Trivy | No new CRITICAL | ✅ Yes (after Spring Boot upgrade) |
| Unit tests | JUnit | 0 failures | ✅ Yes |
| Integration tests | JUnit + Testcontainers | 0 failures | ✅ Yes |
| E2E tests | JUnit + Testcontainers | 0 failures | ✅ Yes |
| Canary approval | Jenkins input | Human sign-off | ✅ Yes |

---

## Rollback Triggers

Rollback is triggered automatically if:
- Canary approval window expires (30 min) → traffic reverts to 100% v1
- Canary approval is manually aborted → same

Manual rollback: see [`docs/operations/rollback.md`](rollback.md).

---

## Emergency Changes (Hotfixes)

1. Create branch `fix/...` from master
2. PR requires only 1 reviewer (instead of Tech Lead review)
3. DEV pipeline must pass; MASTER pipeline mandatory
4. Canary window can be shortened by immediately approving

---

## Change Log

Every production deployment produces a `RELEASE_NOTES_vX.Y.Z.md` file attached to a GitHub Release. Full history: see GitHub Releases tab.
