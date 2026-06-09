# CircleGuard — Estado Actual del Proyecto

> **IMPORTANTE para agentes:** Lee este archivo al inicio de cada sesión de trabajo.
> Actualízalo cada vez que se despliegue, destruya, o cambie algo relevante.
> Es la fuente de verdad del estado real del sistema.

---

## Última actualización
2026-06-09 — **Phase 13 (FinOps) COMPLETA 🟢.** Kubecost 2.8.6 instalado en dev cluster (zona us-central1-a). UI responde HTTP 200 en port-forward :9090. Dev cluster ahora es zonal (us-central1-a) en lugar de regional — cambio de Terraform aplicado para evitar stockouts.

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

## Infraestructura GCP (estado actual: DEV ACTIVO)

**2026-06-09 — Dev cluster RUNNING (FinOps session).** Kubecost instalado en namespace `kubecost`.

| Cluster | Estado | Notas |
|---------|--------|-------|
| circleguard-dev | **RUNNING — 1 nodo** | Zona `us-central1-a` (zonal — cambiado de regional para evitar GCE_STOCKOUT). Kubecost v2.8.6 instalado. |
| circleguard-stage | destruido | State limpio |
| circleguard-prod | destruido | State limpio. Zona `us-central1-a`. |

**IMPORTANTE: Ejecutar `ci/session-stop.sh` al terminar la sesión.**

Para recrear dev:
```bash
cd terraform/envs/dev && terraform apply -auto-approve
gcloud container clusters get-credentials circleguard-dev --zone=us-central1-a --project=tallerfinal-496702
```

Para recrear prod:
```bash
cd terraform/envs/prod && terraform apply -auto-approve
gcloud container clusters get-credentials circleguard-prod --zone=us-central1-a --project=tallerfinal-496702
```

Para acceder a Kubecost (cluster dev activo):
```bash
kubectl port-forward --namespace kubecost deployment/kubecost-cost-analyzer 9090
# Abrir: http://localhost:9090
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
