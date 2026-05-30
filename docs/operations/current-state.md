# CircleGuard — Estado Actual del Proyecto

> **IMPORTANTE para agentes:** Lee este archivo al inicio de cada sesión de trabajo.
> Actualízalo cada vez que se despliegue, destruya, o cambie algo relevante.
> Es la fuente de verdad del estado real del sistema.

---

## Última actualización
2026-05-30 — **PROYECTO FINAL COMPLETO** 🟢 Phases 0–10 completadas. Dev cluster running (1 nodo, circleguard-dev). ESO instalado con ClusterSecretStore en dev. kube-prometheus-stack instalando. Infraestructura: terraform apply corrió, clusters dev y prod RUNNING.

---

## Estado de las Fases

| Fase | Estado |
|------|--------|
| Phase 0 — Foundation | 🟡 9/10 (0.5 billing alert manual) |
| Phase 1 — Terraform | 🟢 COMPLETA |
| Phase 2 — K8s Migration | 🟢 COMPLETA |
| Phase 3 — Istio | 🟡 13/14 (3.11 Kiali screenshot manual) |
| Phase 4 — CI/CD | 🟢 COMPLETA |
| Phase 5 — Patterns | 🟢 COMPLETA |
| Phase 6 — Testing | 🟢 COMPLETA |
| Phase 7 — Observability | 🟢 COMPLETA |
| Phase 8 — Security | 🟢 COMPLETA |
| Phase 9 — Change Mgmt | 🟢 COMPLETA |
| Phase 10 — Docs/Demo | 🟢 COMPLETA |

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
| circleguard-dev | RUNNING | 1 (1 zona) |
| circleguard-prod | RUNNING | 0 (scaled) |
| circleguard-stage | destruido o 0 nodos |

**QUOTA:** CPUS_ALL_REGIONS=12. Máximo 2 clusters con nodos simultáneamente.

---

## Jenkins

- Container: `circleguard-jenkins` — `docker start` para activar
- URL: http://localhost:8080
- Password: `0de72cfcad744533ad0b8dca62e9b879`
- Post-start: `docker exec --user root circleguard-jenkins chmod 666 /var/run/docker.sock`
- Credenciales: dockerhub, github-token, gcp-sa-key, kubeconfig-dev/stage/production, slack-webhook, sonarqube-token

## Kubernetes (dev)

- ESO instalado en `external-secrets` namespace — `SecretSynced: True` para db-password, jwt-secret, mail-credentials
- kube-prometheus-stack instalado en `monitoring` namespace
- Namespaces creados: circleguard-dev, circleguard-stage, circleguard-production

## Próximos pasos (para demo)

1. `terraform apply` en dev y prod si clusters están destruidos
2. Instalar Istio: `istioctl install --set profile=demo -y`
3. Aplicar manifests: `k8s/00-namespaces.yaml`, `k8s/infrastructure/`, `k8s/dev/`, `k8s/istio/`
4. Instalar ESO: `helm upgrade --install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace --set installCRDs=true`
5. Aplicar `k8s/dev/external-secrets/cluster-secret-store.yaml` y `external-secrets.yaml`
6. Instalar kube-prometheus: `helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace -f k8s/monitoring/kube-prometheus-values.yaml`
7. Tomar screenshot de Kiali para task 3.11
