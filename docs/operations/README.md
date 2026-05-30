# CircleGuard — Operations Manual Index

All operational documentation for running and maintaining CircleGuard.

---

## Infrastructure

| Document | Description |
|----------|-------------|
| [current-state.md](current-state.md) | **Start here** — live system state, cluster status, phase completion |
| [k8s-migration.md](k8s-migration.md) | GKE migration from DigitalOcean — decisions and manifest changes |
| [costs.md](costs.md) | Monthly GCP cost estimates per environment |

## CI/CD & Releases

| Document | Description |
|----------|-------------|
| [change-management.md](change-management.md) | Who can request/approve changes, quality gates, emergency process |
| [versioning.md](versioning.md) | Semantic versioning convention (vMAJOR.MINOR.PATCH) |
| [rollback.md](rollback.md) | Rollback commands for K8s deployments and Istio canary |
| [notifications.md](notifications.md) | Slack webhook for pipeline failure alerts |

## Security

| Document | Description |
|----------|-------------|
| [security.md](security.md) | Threat model, mitigations in place, gaps |
| [network-policies.md](network-policies.md) | Istio AuthorizationPolicy allowed edges |
| [security-tests.md](security-tests.md) | OWASP ZAP baseline scan setup and graduation criteria |

## Observability

| Document | Description |
|----------|-------------|
| [observability.md](observability.md) | How to access Prometheus, Grafana, Jaeger, Kibana, Kiali |

## Testing

| Document | Description |
|----------|-------------|
| [test-inventory.md](test-inventory.md) | All 38 test classes: unit, integration, E2E, Locust, ZAP |
| [coverage-policy.md](coverage-policy.md) | 60% line coverage threshold, how to check locally |
| [test-results.md](test-results.md) | Results from last successful master pipeline run |

## Istio / Service Mesh

| Document | Description |
|----------|-------------|
| [istio-verification.md](istio-verification.md) | mTLS verification commands |
| [canary-deployments.md](canary-deployments.md) | How to deploy a canary and monitor it in Kiali |
