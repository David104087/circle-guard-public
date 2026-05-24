# CircleGuard — Estado Actual del Proyecto

> **IMPORTANTE para agentes:** Lee este archivo al inicio de cada sesión de trabajo.
> Actualízalo cada vez que se despliegue, destruya, o cambie algo relevante.
> Es la fuente de verdad del estado real del sistema.

---

## Última actualización
2026-05-24 — Phase 2 COMPLETA. Los 3 clusters tienen manifests desplegados, smoke tests pasan en dev, stage y prod.

---

## Identidad GCP

| Campo | Valor |
|-------|-------|
| Project ID | `tallerfinal-496702` |
| Project name | TallerFinal |
| Region principal | `us-central1` |
| Cuenta activa | `dartunduagapenagos@gmail.com` |
| Billing account | `019044-EE5C1C-F61E8F` (cuenta de la amiga) |
| Terraform SA | `terraform-sa@tallerfinal-496702.iam.gserviceaccount.com` |
| Terraform key | `~/.gcp/terraform-key.json` (local, nunca en el repo) |
| Terraform state | `gs://circle-guard-tfstate-496702/` |

---

## Fases del plan

| Fase | Estado | Notas |
|------|--------|-------|
| Phase 0 — Foundation | 🟡 9/10 | Pendiente: billing alert manual (requiere billing.admin) |
| Phase 1 — Terraform | 🟢 COMPLETA | Los 3 envs aplicados, terraform plan limpio |
| Phase 2 — K8s Migration | 🟢 COMPLETA | Smoke tests pasan en dev/stage/prod |
| Phase 3 — Istio | 🔴 | Depende de Phase 2 — **PRÓXIMO PASO** |
| Phase 4 — CI/CD | 🔴 | Depende de Phase 2 + 3 |
| Phase 5 — Patterns | 🔴 | Depende de Phase 3 |
| Phase 6 — Testing | 🔴 | Depende de Phase 4 |
| Phase 7 — Observability | 🔴 | Depende de Phase 2 + 3 |
| Phase 8 — Security | 🔴 | Depende de Phase 3 + 4 |
| Phase 9 — Change Mgmt | 🔴 | Depende de Phase 4 |
| Phase 10 — Docs/Demo | 🔴 | Depende de todo |

---

## Infraestructura GCP (Terraform)

> **QUOTA CONSTRAINT:** CPUS_ALL_REGIONS = 12 vCPUs y IN_USE_ADDRESSES = 8.
> Los 3 clusters NO pueden correr simultáneamente con todos sus pods (necesitan ~3 nodos/cluster = 18 vCPUs).
> session-stop.sh escala todo a 0. Desplegar de forma secuencial: escalar otro cluster a 0 antes de subir un tercero.

### Entorno dev — ✅ APLICADO (autoscale 0-3 nodos/zona)

| Recurso | Nombre / Valor |
|---------|---------------|
| GKE Cluster | `circleguard-dev` (regional, us-central1) — RUNNING |
| Node pool | `default-pool` — e2-standard-2 Spot — 0-3 nodos/zona — pd-standard 50 GB |
| VPC | `circleguard-dev` |
| Subnet | `circleguard-dev-subnet` — 10.10.0.0/24 |
| Pods CIDR | 10.10.4.0/22 |
| Services CIDR | 10.10.8.0/24 |
| Artifact Registry | `us-central1-docker.pkg.dev/tallerfinal-496702/circleguard` |

### Entorno stage — ✅ APLICADO (autoscale 0-3 nodos/zona)

| Recurso | Nombre / Valor |
|---------|---------------|
| GKE Cluster | `circleguard-stage` (regional, us-central1) — RUNNING |
| Node pool | `default-pool` — e2-standard-2 Spot — 0-3 nodos/zona — pd-standard 50 GB |
| VPC | `circleguard-stage` |
| Subnet | `circleguard-stage-subnet` — 10.20.0.0/24 |

### Entorno prod — ✅ APLICADO (autoscale 0-5 nodos/zona)

| Recurso | Nombre / Valor |
|---------|---------------|
| GKE Cluster | `circleguard-prod` (regional, us-central1) — RUNNING |
| Node pool | `default-pool` — e2-standard-2 regular — 0-5 nodos/zona — pd-standard 50 GB |
| VPC | `circleguard-prod` |
| Subnet | `circleguard-prod-subnet` — 10.30.0.0/24 |

---

## Kubeconfigs locales

| Entorno | Archivo | Generado |
|---------|---------|---------|
| dev | `~/.kube/circleguard-dev` | ✅ Generado |
| stage | `~/.kube/circleguard-stage` | ✅ Generado |
| prod | `~/.kube/circleguard-prod` | ✅ Generado |

Comando para regenerar:
```bash
gcloud container clusters get-credentials circleguard-<env> --region us-central1 --project tallerfinal-496702
cp ~/.kube/config ~/.kube/circleguard-<env>
```

---

## Servicios desplegados en Kubernetes (Phase 2 completa)

> **6/8 servicios Running en todos los entornos.**
> `gateway-service` y `identity-service` tienen ImagePullBackOff — imágenes no existen en Docker Hub todavía.
> Los Dockerfiles y manifests ya están creados. Phase 4 (CI/CD) construirá y subirá las imágenes.

| Namespace | Estado | Infraestructura | Servicios |
|-----------|--------|----------------|-----------|
| circleguard-dev | ✅ Desplegado | Running | 6/8 Running, 2 ImagePullBackOff |
| circleguard-stage | ✅ Desplegado | Running | 6/8 Running, 2 ImagePullBackOff |
| circleguard-production | ✅ Desplegado | Running | 6/8 Running, 2 ImagePullBackOff |

### Smoke test results

```
dev:   PASS — 6 reachable (TCP port open), 2 SKIP (no image)
stage: PASS — 6 reachable (TCP port open), 2 SKIP (no image)
prod:  PASS — 6 reachable (TCP port open), 2 SKIP (no image)
```

### Databases (Postgres)

Todas las DBs creadas manualmente en todos los entornos (init script no corre en restart):
- `circleguard_auth`, `circleguard_dashboard`, `circleguard_form`, `circleguard_promotion`, `circleguard_identity`
- Default DB: `circleguard` (user: admin)

---

## Repositorio de imágenes Docker

Hub: `davidartunduaga/circleguard-{auth,dashboard,file,form,notification,promotion}` — ✅ Existen en Docker Hub
Imágenes pendientes: `davidartunduaga/circleguard-gateway:latest`, `davidartunduaga/circleguard-identity:latest` — ❌ NO existen (Phase 4)
Artifact Registry (nuevo): `us-central1-docker.pkg.dev/tallerfinal-496702/circleguard` — no usado aún

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
| Rama de trabajo | `master` (rama actual de trabajo) |
| Rama Phase 2 | `feat/k8s-gke-migration` (sin push todavía — pendiente merge a master) |
| Projects board | https://github.com/users/David104087/projects/1 |

---

## Scripts de sesión

```bash
./ci/session-start.sh   # Al iniciar — levanta clusters y actualiza kubeconfig
./ci/session-stop.sh    # Al terminar — escala a 0
```

---

## Notas para el próximo agente

1. **Phase 2 está COMPLETA.** El próximo trabajo es Phase 3: instalar Istio en dev, habilitar sidecar injection, STRICT mTLS, Circuit Breaker, Kiali/Jaeger.
2. **Branch `feat/k8s-gke-migration`** tiene los cambios de Phase 2 commiteados pero no pusheados al fork. Hacer push y abrir PR para merge a master antes de continuar.
3. **QUOTA:** dev(2 nodos) + stage(~3 nodos) + prod(0 nodos) después de session-stop. Verificar con `gcloud container clusters list`.
4. **gateway-service e identity-service** no tienen imágenes Docker Hub. No intentar correr estos pods — se construyen en Phase 4.
5. **Al deployar a producción**, siempre escalar dev o stage a 0 primero para liberar quota vCPU (límite 12).
6. **Para recrear namespaces después de escala a 0**, aplicar: `k8s/00-namespaces.yaml` + `k8s/infrastructure/` + `k8s/<env>/`.
