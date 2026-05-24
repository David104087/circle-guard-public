# CircleGuard — Estado Actual del Proyecto

> **IMPORTANTE para agentes:** Lee este archivo al inicio de cada sesión de trabajo.
> Actualízalo cada vez que se despliegue, destruya, o cambie algo relevante.
> Es la fuente de verdad del estado real del sistema.

---

## Última actualización
2026-05-24 — Dev cluster RUNNING con e2-standard-2/pd-standard; stage+prod en apply

---

## Identidad GCP

| Campo | Valor |
|-------|-------|
| Project ID | `tallerfinal-496702` |
| Project name | TallerFinal |
| Region principal | `us-central1` |
| Cuenta activa | `dartunduagapenagos@gmail.com` |
| Terraform SA | `terraform-sa@tallerfinal-496702.iam.gserviceaccount.com` |
| Terraform key | `~/.gcp/terraform-key.json` (local, nunca en el repo) |
| Terraform state | `gs://circle-guard-tfstate-496702/` |

---

## Fases del plan

| Fase | Estado | Notas |
|------|--------|-------|
| Phase 0 — Foundation | 🟡 9/10 | Pendiente: billing alert manual (requiere billing.admin) |
| Phase 1 — Terraform | 🟡 En progreso | Dev aplicado; stage/prod pendiente |
| Phase 2 — K8s Migration | 🔴 | Depende de Phase 1 completa |
| Phase 3 — Istio | 🔴 | Depende de Phase 2 |
| Phase 4 — CI/CD | 🔴 | Depende de Phase 2 + 3 |
| Phase 5 — Patterns | 🔴 | Depende de Phase 3 |
| Phase 6 — Testing | 🔴 | Depende de Phase 4 |
| Phase 7 — Observability | 🔴 | Depende de Phase 2 + 3 |
| Phase 8 — Security | 🔴 | Depende de Phase 3 + 4 |
| Phase 9 — Change Mgmt | 🔴 | Depende de Phase 4 |
| Phase 10 — Docs/Demo | 🔴 | Depende de todo |

---

## Infraestructura GCP (Terraform)

### Entorno dev — ✅ APLICADO (3 nodos RUNNING)

| Recurso | Nombre / Valor |
|---------|---------------|
| GKE Cluster | `circleguard-dev` (regional, us-central1) — RUNNING |
| Node pool | `default-pool` — e2-standard-2 Spot — 0-3 nodos/zona — pd-standard 50 GB |
| VPC | `circleguard-dev` |
| Subnet | `circleguard-dev-subnet` — 10.10.0.0/24 |
| Pods CIDR | 10.10.4.0/22 |
| Services CIDR | 10.10.8.0/24 |
| Artifact Registry | `us-central1-docker.pkg.dev/tallerfinal-496702/circleguard` |
| Secrets creados | `cg-db-password-dev`, `cg-jwt-secret-dev`, `cg-dockerhub-user-dev`, `cg-dockerhub-password-dev`, `cg-mail-password-dev` |
| SA microservices | `cg-auth-dev`, `cg-dashboard-dev`, `cg-file-dev`, `cg-form-dev`, `cg-notification-dev`, `cg-promotion-dev` |
| SA infra | `cg-eso-dev`, `cg-jenkins-dev`, `cg-gke-ev` |
| Kubernetes namespace | `circleguard-dev` (aún vacío — Phase 2 lo llena) |

### Entorno stage — ⏳ APLICANDO (terraform apply en curso)

| Recurso planificado | Valor |
|--------------------|-------|
| GKE Cluster | `circleguard-stage` (regional, us-central1) |
| Node pool | e2-standard-2 Spot — 0-3 nodos/zona |
| Subnet | 10.20.0.0/24 |

### Entorno prod — ⏳ APLICANDO (terraform apply en curso)

| Recurso planificado | Valor |
|--------------------|-------|
| GKE Cluster | `circleguard-prod` (regional, us-central1) |
| Node pool | e2-standard-4 regular — 1-5 nodos/zona |
| Subnet | 10.30.0.0/24 |

---

## Kubeconfigs locales

| Entorno | Archivo | Generado |
|---------|---------|---------|
| dev | `~/.kube/circleguard-dev` | ✅ Generado |
| stage | `~/.kube/circleguard-stage` | Pendiente |
| prod | `~/.kube/circleguard-prod` | Pendiente |

Comando para generar/actualizar:
```bash
gcloud container clusters get-credentials circleguard-<env> \
  --region us-central1 --project tallerfinal-496702
```

---

## Servicios desplegados en Kubernetes

> Todos vacíos — se llenan en Phase 2.

| Namespace | Estado |
|-----------|--------|
| circleguard-dev | ⏳ Vacío |
| circleguard-stage | ⏳ No existe aún |
| circleguard-production | ⏳ No existe aún |

---

## Repositorio de imágenes Docker

Hub: `davidartunduaga/circleguard-{auth,dashboard,file,form,notification,promotion}`
Artifact Registry (nuevo): `us-central1-docker.pkg.dev/tallerfinal-496702/circleguard`

Las imágenes actuales están en Docker Hub (Taller 2). La migración a AR se hace en Phase 4 (CI/CD).

---

## Jenkins (local)

| Campo | Valor |
|-------|-------|
| Container | `circleguard-jenkins` (parado entre sesiones) |
| URL | http://localhost:8080 |
| Admin password | `0de72cfcad744533ad0b8dca62e9b879` |
| Estado | ⏳ No activo (se usa en Phase 4) |

---

## GitHub

| Campo | Valor |
|-------|-------|
| Fork repo | https://github.com/David104087/circle-guard-public |
| Rama de trabajo | `master` |
| Projects board | https://github.com/users/David104087/projects/1 |
| Issues | #1–#10 (user stories, en Backlog) |

---

## Scripts de sesión

```bash
./ci/session-start.sh   # Al iniciar — levanta clusters y actualiza kubeconfig
./ci/session-stop.sh    # Al terminar — escala a 0 o destruye según tiempo fuera
```

---

## Notas para el próximo agente

1. **Verifica siempre el estado real** con `gcloud container clusters list --project=tallerfinal-496702` antes de asumir que algo está corriendo.
2. **Lee `Known Issues & Lessons Learned`** en CLAUDE.md antes de escribir scripts bash o Terraform.
3. **El plan de implementación** está en CLAUDE.md — sigue las fases en orden, no saltes dependencias.
4. **Stage y prod** no tienen clusters aún — aplica `terraform/envs/stage` y `terraform/envs/prod` cuando los necesites.
5. **Los secrets en Secret Manager están vacíos** (solo contenedores). Se llenarán con valores reales en Phase 5 (ESO).
