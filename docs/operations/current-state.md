# CircleGuard — Estado Actual del Proyecto

> **IMPORTANTE para agentes:** Lee este archivo al inicio de cada sesión de trabajo.
> Actualízalo cada vez que se despliegue, destruya, o cambie algo relevante.
> Es la fuente de verdad del estado real del sistema.

---

## Última actualización
2026-06-11 — **Sesión final. Todas las brechas de evaluación cerradas. GCP dev cluster escalado a 0 (scale-to-zero completado). 2 discos PVC huérfanos eliminados. Jenkins/SonarQube no corrían. DO: state vacío, $0. Rama activa: `feat/istio-kiali-evidence` lista para PR → master. Pendiente: usuario sube `docs/diagrams/kiali-graph.png` manualmente y crea GitHub Releases v0.2.0 + v0.3.0.**

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

## Infraestructura GCP (estado actual: CLUSTER A 0 NODOS — ~$0)

**2026-06-11 — FIN DE SESIÓN FINAL. Costo GCP ≈ $0.**

| Cluster | Estado | Notas |
|---------|--------|-------|
| circleguard-dev | **RUNNING, 0 nodos** (scale-to-zero 2026-06-11) | Node pool existe en GCS state. 2 discos PVC huérfanos eliminados. Nodo boot disks se eliminan automáticamente. |
| circleguard-stage | destruido | State limpio |
| circleguard-prod | destruido | State limpio |

**1 cluster (0 VMs) · 0 discos PVC · LB del ingressgateway pendiente de liberar · ~$0 costo**

Para recrear dev:
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

`feat/istio-kiali-evidence` — ZAP scan + parches de documentación finales. Lista para PR → `master`.

### Contenido de la rama
- `tests/security/zap-report-dev.html` — OWASP ZAP baseline: 66 PASS, 0 FAIL
- `docs/operations/test-results.md` — actualizado con ZAP findings reales
- `RELEASE_NOTES_v0.2.0.md` — Multi-Cloud + FinOps
- `RELEASE_NOTES_v0.3.0.md` — Chaos Engineering
- `docs/releases/README.md` — índice actualizado con v0.2.0 y v0.3.0
- `docs/operations/alerts.md` — nuevo archivo con 6 reglas de alerta documentadas
- `docs/operations/observability.md` — justificación EFK vs ELK
- `docs/operations/security.md` — limpiado, sin checkboxes vacías, TLS honestamente documentado
- `docs/presentation/video-script-12min.md` — script de 12 min con 14 segmentos

### Pendiente (acción manual del usuario)
- Subir `docs/diagrams/kiali-graph.png` con screenshot real de Kiali (mTLS padlocks visibles)
- Crear GitHub Releases v0.2.0 y v0.3.0 en el repo fork

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
