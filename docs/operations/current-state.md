# CircleGuard — Estado Actual del Proyecto

> **IMPORTANTE para agentes:** Lee este archivo al inicio de cada sesión de trabajo.
> Actualízalo cada vez que se despliegue, destruya, o cambie algo relevante.
> Es la fuente de verdad del estado real del sistema.

---

## Última actualización
2026-06-10 — **En sesión. Phase 12 (Chaos Engineering) COMPLETA 🟢.** Dev cluster activo (3 nodos, autoscaler escaló). Chaos Mesh v2.7.0 instalado en `chaos-testing`. 5 experimentos ejecutados. 2 mejoras implementadas en `k8s/dev/`. Rama `feat/chaos-engineering` lista para PR.

---

## Estado de las Fases

| Fase | Estado |
|------|--------|
| Phase 0 — Foundation | 🟡 9/10 |
| Phase 1 — Terraform | 🟢 COMPLETA |
| Phase 2 — K8s Migration | 🟢 COMPLETA |
| Phase 3 — Istio (Bonus) | 🟢 COMPLETA (screenshot tomado, pendiente agregar archivo al repo) |
| Phase 4 — CI/CD | 🟢 COMPLETA |
| Phase 5 — Patterns | 🟢 COMPLETA |
| Phase 6 — Testing | 🟢 COMPLETA |
| Phase 7 — Observability | 🟢 COMPLETA |
| Phase 8 — Security | 🟢 COMPLETA |
| Phase 9 — Change Mgmt | 🟢 COMPLETA |
| Phase 10 — Docs/Demo | 🟢 COMPLETA |
| Phase 11 — Multi-Cloud (Bonus) | 🟢 COMPLETA |
| Phase 12 — Chaos Engineering | 🟢 COMPLETA |
| Phase 13 — FinOps | 🟢 COMPLETA |

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

## Infraestructura GCP (estado actual: DEV ACTIVO — destruir al terminar sesión)

**2026-06-10 — SESIÓN EN CURSO. Phase 12 chaos engineering activo.**

| Cluster | Estado | Notas |
|---------|--------|-------|
| circleguard-dev | **ACTIVO** — 3 nodos (autoscaler) | Zona `us-central1-a`. 6 vCPUs en uso. Chaos Mesh instalado. |
| circleguard-stage | destruido | State limpio |
| circleguard-prod | destruido | State limpio. Zona `us-central1-a`. |

**⚠️ DESTRUIR DEV AL TERMINAR SESIÓN:**
```bash
cd terraform/envs/dev && terraform destroy -auto-approve
# Luego eliminar discos huérfanos
gcloud compute disks list --project=tallerfinal-496702 --format="csv[no-heading](name,zone)" | \
  while IFS=, read -r NAME ZONE; do
    gcloud compute disks delete "$NAME" --zone="$(basename "$ZONE")" --project=tallerfinal-496702 --quiet
  done
```

Para recrear dev en la próxima sesión:
```bash
cd terraform/envs/dev && terraform apply -auto-approve
gcloud container clusters get-credentials circleguard-dev --zone=us-central1-a --project=tallerfinal-496702
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

`feat/chaos-engineering` — Phase 12 completa. Listo para PR hacia `master`.

### Contenido de la rama
- `docs/chaos/experiments.md` — 5 experimentos diseñados con hipótesis y CRDs
- `docs/chaos/manifests/` — 5 archivos YAML de Chaos Mesh
- `docs/chaos/results.md` — Resultados documentados de los 5 experimentos
- `docs/chaos/runbook.md` — Runbook operacional
- `ci/Jenkinsfile.dev` — Stage `Chaos Smoke Test` añadido
- `k8s/dev/` — Mejora 1: `holdApplicationUntilProxyStarts` en 4 servicios
- `k8s/dev/form-service.yaml`, `notification-service.yaml` — Mejora 2: Kafka reconnect backoff

---

## Phase 12 — Chaos Engineering: COMPLETA 🟢

### Todas las tareas completadas

| Tarea | Estado | Entregable |
|-------|--------|-----------|
| 12.1 — Chaos Mesh instalado | ✅ | Namespace `chaos-testing`, v2.7.0, `securityMode=false` |
| 12.2 — 5 experimentos diseñados | ✅ | docs/chaos/experiments.md + manifests/ |
| 12.3 — Exp 1: Pod failure | ✅ | Pod restart en ~66s. docs/chaos/results.md |
| 12.4 — Exp 2: Network delay | ✅ | 200ms delay inyectado. AllInjected=True confirmado |
| 12.5 — Exp 3: Network partition | ✅ | 100% loss por 50s. gateway Running durante toda la partición |
| 12.6 — Exp 4: CPU stress | ✅ | CPU: 2m→500m. Pod sobrevivió (tcpSocket probe) |
| 12.7 — Exp 5: Kafka disruption | ✅ | Kafka restart en ~10s. Consumer reconectó automáticamente |
| 12.8 — 2 mejoras implementadas | ✅ | holdApplicationUntilProxyStarts + Kafka backoff config |
| 12.9 — Runbook | ✅ | docs/chaos/runbook.md |
| 12.10 — Pipeline integration | ✅ | ci/Jenkinsfile.dev: Chaos Smoke Test stage |

---

## Phase 13 — FinOps: COMPLETA 🟢

### Todas las tareas completadas

| Tarea | Estado | Entregable |
|-------|--------|-----------|
| 13.1 — GCP Billing Export | ✅ | docs/diagrams/finops/ (screenshots) |
| 13.2 — Kubecost v2.8.6 | ✅ | Instalado en namespace `kubecost` (dev cluster) |
| 13.3 — Grafana FinOps dashboard | ✅ | k8s/monitoring/dashboards/finops.json |
| 13.4 — Scale-to-zero automatizado | ✅ | ci/session-stop.sh (GCP + DO) |
| 13.5 — Spot VMs (dev+stage) | ✅ | terraform/envs/dev+stage/main.tf `use_spot=true` |
| 13.6 — Resource requests/limits | ✅ | 8 servicios × 3 envs auditados |
| 13.7 — Cost optimization analysis | ✅ | docs/operations/costs.md |
| 13.8 — FinOps strategies doc | ✅ | docs/operations/finops.md (6 estrategias) |

---

## Jenkins

- Container: `circleguard-jenkins` — `docker start circleguard-jenkins && docker exec --user root circleguard-jenkins chmod 666 /var/run/docker.sock`
- URL: http://localhost:8080 | Password: `0de72cfcad744533ad0b8dca62e9b879`
