# CircleGuard — Estado Actual del Proyecto

> **IMPORTANTE para agentes:** Lee este archivo al inicio de cada sesión de trabajo.
> Actualízalo cada vez que se despliegue, destruya, o cambie algo relevante.
> Es la fuente de verdad del estado real del sistema.

---

## Última actualización
2026-06-09 — **Inicio de sesión. Phase 13 (FinOps).** 7 de 8 tareas ya completas en sesión anterior. Pendiente: 13.2 (Kubecost install — requiere cluster activo). `session-stop.sh` actualizado para manejar clusters DO.

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
| Phase 13 — FinOps | 🟡 7/8 (solo 13.2 Kubecost pendiente — necesita cluster) |

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

## Sesión actual: Phase 13 — FinOps

### Estado de tareas

| Tarea | Estado | Notas |
|-------|--------|-------|
| 13.1 — GCP Billing Export | ✅ COMPLETA | BigQuery export activo, screenshots en docs/diagrams/finops/ |
| 13.2 — Kubecost installed | ⏳ PENDIENTE | kubecost-values.yaml listo; ejecutar cuando cluster activo |
| 13.3 — Grafana FinOps dashboard | ✅ COMPLETA | k8s/monitoring/dashboards/finops.json |
| 13.4 — Scale-to-zero automatizado | ✅ COMPLETA | ci/session-stop.sh (GCP + DO) |
| 13.5 — Spot VMs configurados | ✅ COMPLETA | dev+stage use_spot=true, prod=false |
| 13.6 — Resource requests/limits | ✅ COMPLETA | 8 servicios en dev/stage/production auditados |
| 13.7 — Cost optimization analysis | ✅ COMPLETA | docs/operations/costs.md actualizado |
| 13.8 — FinOps strategies doc | ✅ COMPLETA | docs/operations/finops.md con 6 estrategias |

### Paso pendiente (requiere cluster activo)

**13.2 — Instalar Kubecost:**
```bash
# Levantar dev cluster primero:
cd terraform/envs/dev && terraform apply -auto-approve
gcloud container clusters get-credentials circleguard-dev --region=us-central1 --project=tallerfinal-496702

# Instalar Kubecost:
helm repo add kubecost https://kubecost.github.io/cost-analyzer/ && helm repo update
helm install kubecost kubecost/cost-analyzer -n kubecost --create-namespace \
  -f k8s/monitoring/kubecost-values.yaml

# Verificar:
kubectl get pods -n kubecost
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090
```

---

## Jenkins

- Container: `circleguard-jenkins` — `docker start circleguard-jenkins && docker exec --user root circleguard-jenkins chmod 666 /var/run/docker.sock`
- URL: http://localhost:8080 | Password: `0de72cfcad744533ad0b8dca62e9b879`
