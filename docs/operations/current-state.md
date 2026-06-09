# CircleGuard — Estado Actual del Proyecto

> **IMPORTANTE para agentes:** Lee este archivo al inicio de cada sesión de trabajo.
> Actualízalo cada vez que se despliegue, destruya, o cambie algo relevante.
> Es la fuente de verdad del estado real del sistema.

---

## Última actualización
2026-06-08 — **Fin de sesión. Phase 11 (Multi-Cloud) COMPLETA 🟢.** Todos los clusters DO destruidos. GCP prod destruido con `terraform destroy`. Próxima tarea: Phase 13 — FinOps.

---

## Estado de las Fases

| Fase | Estado |
|------|--------|
| Phase 0 — Foundation | 🟡 9/10 |
| Phase 1 — Terraform | 🟢 COMPLETA |
| Phase 2 — K8s Migration | 🟢 COMPLETA |
| Phase 3 — Istio (Bonus) | 🟡 13/14 (screenshot Kiali pendiente) |
| Phase 4 — CI/CD | 🟢 COMPLETA |
| Phase 5 — Patterns | 🟢 COMPLETA |
| Phase 6 — Testing | 🟢 COMPLETA |
| Phase 7 — Observability | 🟢 COMPLETA |
| Phase 8 — Security | 🟢 COMPLETA |
| Phase 9 — Change Mgmt | 🟢 COMPLETA |
| Phase 10 — Docs/Demo | 🟢 COMPLETA |
| Phase 11 — Multi-Cloud (Bonus) | 🟢 COMPLETA |
| Phase 12 — Chaos Engineering | 🔴 No iniciada |
| Phase 13 — FinOps | 🟡 Parcial (tasks 13.1–13.8 pendientes) |

---

## Identidad GCP

| Campo | Valor |
|-------|-------|
| Project ID | `tallerfinal-496702` |
| Region | `us-central1` |
| Cuenta | `dartunduagapenagos@gmail.com` |
| Terraform SA | `terraform-sa@tallerfinal-496702.iam.gserviceaccount.com` |
| Terraform key | `~/.gcp/terraform-key.json` (local, nunca en el repo) |
| Terraform state | `gs://circle-guard-tfstate-496702/` |

---

## Infraestructura GCP (estado actual: TODO DESTRUIDO)

**2026-06-08 — TODO APAGADO (fin de sesión).** Costo en GCP ≈ $0.

| Cluster | Estado | Notas |
|---------|--------|-------|
| circleguard-dev | 0 nodos | State existe en GCS — `terraform apply` lo recrea |
| circleguard-stage | destruido | State limpio |
| circleguard-prod | **destruido** (`terraform destroy` 2026-06-08) | Zona `us-central1-a` (zonal, no regional — ver Known Issues GCE_STOCKOUT) |

**0 clusters, 0 VMs, 0 discos persistentes activos.**

Para recrear prod desde cero:
```bash
cd terraform/envs/prod && terraform apply -auto-approve
gcloud container clusters get-credentials circleguard-prod --zone=us-central1-a --project=tallerfinal-496702
```

Para recrear dev:
```bash
gcloud container clusters list --project=tallerfinal-496702
cd terraform/envs/dev && terraform apply -auto-approve
gcloud container clusters get-credentials circleguard-dev --region=us-central1 --project=tallerfinal-496702
```

---

## Infraestructura DO (estado actual: DESTRUIDA)

| Cluster | Estado |
|---------|--------|
| circleguard-do-dev | Destruido (terraform state vacío) |
| circleguard-do-stage | Destruido (terraform state vacío) |
| circleguard-do-prod | Destruido (terraform state vacío) |

Para recrear (necesita DO token):
```bash
export TF_VAR_do_token="dop_v1_..."
for env in do-dev do-stage do-prod; do
  cd terraform/envs/$env && terraform apply -auto-approve
  terraform output -raw kube_config > ~/.kube/circleguard-$env
  cd -
done
```

---

## Rama activa

`feat/multi-cloud-bonus` — PR abierto hacia `master`. Phase 11 completa.

---

## Próxima sesión: Phase 13 — FinOps

### Tareas a completar (13.1–13.8)

**13.1 — GCP Billing Export a BigQuery** *(acción manual en consola GCP)*
- GCP Console → Billing → Billing export → BigQuery export
- Dataset: `billing_export`, project: `tallerfinal-496702`
- Tarda 24–48h en acumular datos

**13.2 — Kubecost** *(requiere cluster activo)*
```bash
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm install kubecost kubecost/cost-analyzer -n kubecost --create-namespace
```

**13.3 — Dashboard Grafana de costos** — JSON en `k8s/monitoring/dashboards/finops.json`

**13.4 — Automatizar scale-to-zero** — actualizar `ci/session-stop.sh`

**13.5 — Variable spot_node_pool** — añadir a `terraform/modules/gke/`

**13.6 — Auditar resource requests/limits** — verificar todos los Deployments en `k8s/dev/`, `k8s/stage/`, `k8s/production/`

**13.7 — Cost optimization analysis** — actualizar `docs/operations/costs.md`

**13.8 — FinOps strategies doc** — crear `docs/operations/finops.md`

---

## Jenkins

- Container: `circleguard-jenkins` — `docker start circleguard-jenkins && docker exec --user root circleguard-jenkins chmod 666 /var/run/docker.sock`
- URL: http://localhost:8080 | Password: `0de72cfcad744533ad0b8dca62e9b879`
