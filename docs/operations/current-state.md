# CircleGuard — Estado Actual del Proyecto

> **IMPORTANTE para agentes:** Lee este archivo al inicio de cada sesión de trabajo.
> Actualízalo cada vez que se despliegue, destruya, o cambie algo relevante.
> Es la fuente de verdad del estado real del sistema.

---

## Última actualización
2026-06-08 — **Phase 11 Multi-Cloud en progreso.** DO dev cluster recreado con s-4vcpu-8gb (8GB RAM). Manifests DO actualizados con JAVA_TOOL_OPTIONS y Recreate strategy. Liveness probes pendientes de fix (crash a los 300s exactos por probe HTTP fallando). GCP clusters: todos a 0 nodos. DO clusters: destruidos al final de sesión.

### Métricas de negocio por servicio (8/8)
`auth_tokens_issued_total` · `analytics_queries_total` · `files_uploaded_total` · `surveys_submitted_total` · `qr_validations_total` · `identities_registered_total` · `notifications_sent_total` · `health_status_changes_total`

---

## Estado de las Fases

| Fase | Estado |
|------|--------|
| Phase 0 — Foundation | 🟡 9/10 (0.5 billing alert manual) |
| Phase 1 — Terraform | 🟢 COMPLETA |
| Phase 2 — K8s Migration | 🟢 COMPLETA |
| Phase 3 — Istio (Bonus) | 🟡 13/14 (3.11 Kiali screenshot manual) |
| Phase 4 — CI/CD | 🟢 COMPLETA |
| Phase 5 — Patterns | 🟢 COMPLETA |
| Phase 6 — Testing | 🟢 COMPLETA |
| Phase 7 — Observability | 🟢 COMPLETA |
| Phase 8 — Security | 🟢 COMPLETA |
| Phase 9 — Change Mgmt | 🟢 COMPLETA |
| Phase 10 — Docs/Demo | 🟢 COMPLETA |
| Phase 11 — Multi-Cloud (Bonus) | 🟡 En progreso — tasks 11.1–11.5 ✅, 11.6–11.13 pendientes |
| Phase 12 — Chaos Engineering (Bonus) | 🔴 No iniciada |
| Phase 13 — FinOps (Bonus) | 🟡 Parcial (cost doc exists, tooling needed) |

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

## Infraestructura GCP

| Cluster | Estado | Nodos |
|---------|--------|-------|
| circleguard-dev | 0 nodos (scaled down) | 0 |
| circleguard-prod | 0 nodos (scaled down) | 0 |
| circleguard-stage | destruido | — |

**QUOTA:** CPUS_ALL_REGIONS=12. Máximo 2 clusters con nodos simultáneamente.

---

## Jenkins

- Container: `circleguard-jenkins` — `docker start` para activar
- URL: http://localhost:8080
- Password: `0de72cfcad744533ad0b8dca62e9b879`
- Post-start: `docker exec --user root circleguard-jenkins chmod 666 /var/run/docker.sock`
- Credenciales: dockerhub, github-token, gcp-sa-key, kubeconfig-dev/stage/production, slack-webhook, sonarqube-token

## Kubernetes (GCP dev)

- ESO instalado en `external-secrets` namespace — `SecretSynced: True` para db-password, jwt-secret, mail-credentials
- kube-prometheus-stack instalado en `monitoring` namespace
- Namespaces creados: circleguard-dev, circleguard-stage, circleguard-production

## DigitalOcean (Multi-Cloud — Phase 11)

**Estado al cierre de sesión 2026-06-08:** Clusters destruidos para evitar costos.

| Cluster DO | Estado | Terraform env | Nodo size |
|------------|--------|---------------|-----------|
| circleguard-do-dev | DESTRUIDO (recrear próxima sesión) | `terraform/envs/do-dev/` | s-4vcpu-8gb |
| circleguard-do-stage | DESTRUIDO | `terraform/envs/do-stage/` | s-2vcpu-4gb |
| circleguard-do-prod | DESTRUIDO | `terraform/envs/do-prod/` | s-2vcpu-4gb |

### Configuración DO actual (post esta sesión)
- **do-dev:** `node_size = "s-4vcpu-8gb"`, `node_count=1`, `max_nodes=1` — necesita 8GB para correr 8 JVM services + infra
- **do-stage/prod:** `node_size = "s-2vcpu-4gb"`, `node_count=1`, `max_nodes=1`
- **Límite de cuenta:** 3 droplets totales → max_nodes=1 por cluster
- **Kubeconfigs:** `~/.kube/circleguard-do-dev/stage/prod` — expiran ~1h, refrescar con `terraform output -raw kube_config`

### Manifests DO actualizados (k8s/do-dev/)
- Todos los servicios tienen `JAVA_TOOL_OPTIONS: "-Xms64m -Xmx256m -XX:MaxMetaspaceSize=128m"`
- Todos los servicios tienen `strategy: type: Recreate`
- JWT secrets corregidos: ≥43 chars (344 bits) en auth/gateway/identity/promotion
- **PENDIENTE FIX:** liveness probes deben cambiar a `tcpSocket` (HTTP probe falla por actuator config)

---

## Próximos pasos — Phase 11 (próxima sesión)

### PRIMERO — Fix liveness probes en k8s/do-dev/ (desbloqueador)
Cambiar en todos los 8 services el liveness probe de `httpGet /actuator/health/liveness` a:
```yaml
livenessProbe:
  tcpSocket:
    port: <PORT>
  initialDelaySeconds: 60
  periodSeconds: 30
  failureThreshold: 5
readinessProbe:
  httpGet:
    path: /actuator/health
    port: <PORT>
  initialDelaySeconds: 90
  periodSeconds: 15
  failureThreshold: 5
```

### Secuencia de deploy (do-dev)
```bash
export TF_VAR_do_token="dop_v1_..."
cd terraform/envs/do-dev && terraform apply -auto-approve
terraform output -raw kube_config > ~/.kube/circleguard-do-dev
export KUBECONFIG=~/.kube/circleguard-do-dev
kubectl apply -f k8s/do-dev/00-namespace.yaml
kubectl apply -f k8s/do-dev/infrastructure/
# Esperar postgres-0 Running (~2min)
kubectl exec postgres-0 -n circleguard-do-dev -- psql -U admin -l  # verificar DBs
kubectl apply -f k8s/do-dev/
# Esperar todos 1/1 Running (~5min)
```

### Istio en do-dev
```bash
istioctl install --set profile=demo -y --kubeconfig ~/.kube/circleguard-do-dev
kubectl label namespace circleguard-do-dev istio-injection=enabled --kubeconfig ~/.kube/circleguard-do-dev
kubectl apply -f k8s/istio/peer-authentication.yaml --kubeconfig ~/.kube/circleguard-do-dev
kubectl rollout restart deployment -n circleguard-do-dev --kubeconfig ~/.kube/circleguard-do-dev
```

### Para demo de GCP (si se necesita)
1. `terraform apply` en dev y prod si clusters están destruidos
2. Instalar Istio: `istioctl install --set profile=demo -y`
3. Aplicar manifests: `k8s/00-namespaces.yaml`, `k8s/infrastructure/`, `k8s/dev/`, `k8s/istio/`
4. Instalar ESO, kube-prometheus-stack
5. Tomar screenshot de Kiali para task 3.11
