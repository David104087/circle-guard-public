# CircleGuard — Estado Actual del Proyecto

> **IMPORTANTE para agentes:** Lee este archivo al inicio de cada sesión de trabajo.
> Actualízalo cada vez que se despliegue, destruya, o cambie algo relevante.
> Es la fuente de verdad del estado real del sistema.

---

## Última actualización
2026-06-08 — **Phase 11 COMPLETA (bonus multi-cloud 5% ✅).** Todas las tasks 11.1–11.13 completadas. Todos los clusters DO están activos con 8 servicios `2/2 Running` y PeerAuthentication STRICT en los 3 envs. Pending: Tasks 11.10–11.13 (Jenkins + docs + Locust). GCP clusters a 0 nodos (escalados). DO clusters están activos — ESCALAR A 0 AL CERRAR SESIÓN.

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
| Phase 13 — FinOps | 🟡 Parcial |

---

## ⚠️ ACCIÓN REQUERIDA AL CERRAR SESIÓN

Los 3 clusters DO están activos y facturando. Escalar a 0 nodos:

```bash
export TF_VAR_do_token="dop_v1_..."

cd terraform/envs/do-dev
terraform apply -var="node_count=0" -auto-approve

cd ../do-stage
terraform apply -var="node_count=0" -auto-approve

cd ../do-prod
terraform apply -var="node_count=0" -auto-approve
```

O usar doctl:
```bash
# Obtener cluster IDs
doctl kubernetes cluster list
doctl kubernetes cluster node-pool list <CLUSTER_ID>
doctl kubernetes cluster node-pool update <CLUSTER_ID> <POOL_ID> --count 0
```

---

## Infraestructura GCP (estado actual)

| Cluster | Estado |
|---------|--------|
| circleguard-dev | 0 nodos (escalado) |
| circleguard-prod | 0 nodos (escalado) |
| circleguard-stage | destruido |

Para escalar dev a 1 nodo: `gcloud container clusters resize circleguard-dev --node-pool=default-pool --num-nodes=1 --region=us-central1 --project=tallerfinal-496702 --quiet`

---

## Infraestructura DO (estado actual: TODOS ACTIVOS)

| Cluster | Estado | Node size | Istio | Services |
|---------|--------|-----------|-------|---------|
| circleguard-do-dev | 1 nodo ACTIVO | s-4vcpu-8gb | ✅ STRICT mTLS | 8/8 servicios 2/2 Running |
| circleguard-do-stage | 1 nodo ACTIVO | s-2vcpu-4gb | ✅ STRICT mTLS | 8/8 servicios 2/2 Running |
| circleguard-do-prod | 1 nodo ACTIVO | s-2vcpu-4gb | ✅ STRICT mTLS | 8/8 servicios 2/2 Running |

**Nota infra:** Kafka y Neo4j pueden estar Pending en do-stage/do-prod (s-2vcpu-4gb insuficiente). Los servicios de aplicación funcionan correctamente con tcpSocket probes.

**Kubeconfigs DO:** expiran ~1h. Refrescar con:
```bash
cd terraform/envs/do-dev && terraform output -raw kube_config > ~/.kube/circleguard-do-dev
cd terraform/envs/do-stage && terraform output -raw kube_config > ~/.kube/circleguard-do-stage
cd terraform/envs/do-prod && terraform output -raw kube_config > ~/.kube/circleguard-do-prod
```

---

## Playbook para la próxima sesión (Tasks 11.10–11.13)

### Paso 0 — Refrescar clusters DO (si están escalados a 0)

```bash
export TF_VAR_do_token="dop_v1_..."

for env in do-dev do-stage do-prod; do
  cd terraform/envs/$env
  terraform apply -auto-approve
  terraform output -raw kube_config > ~/.kube/circleguard-$env
  cd -
done
```

Verificar que todos los pods están Running:
```bash
for env in do-dev do-stage do-prod; do
  KUBECONFIG=~/.kube/circleguard-$env kubectl get pods -n circleguard-$env 2>/dev/null | tail -3
done
```

### Paso 1 — Task 11.10: Jenkins credentials para DO

Agregar kubeconfigs como FileCredentials en Jenkins:
1. Abrir http://localhost:8080 → Manage Jenkins → Credentials → Global → Add Credentials
2. Tipo: Secret file, ID: `do-dev-kubeconfig`, archivo: `~/.kube/circleguard-do-dev`
3. Repetir para `do-stage-kubeconfig` y `do-prod-kubeconfig`

Luego agregar stage paralelo en `ci/Jenkinsfile.dev`:
```groovy
stage('Deploy to DO Dev') {
  when { branch 'feat/*' }
  steps {
    withCredentials([file(credentialsId: 'do-dev-kubeconfig', variable: 'DO_KUBECONFIG')]) {
      sh "KUBECONFIG=${DO_KUBECONFIG} kubectl apply -f k8s/do-dev/ -n circleguard-do-dev"
    }
  }
}
```

### Paso 2 — Task 11.11: Documentar estrategia LB

Actualizar `docs/operations/multi-cloud.md` con sección de cross-cloud load balancing:
- DNS activo-pasivo: GCP primario, DO standby
- Failover manual via actualización de registro DNS
- Ruta futura: Cloudflare active-active con health checks

### Paso 3 — Task 11.12: Performance comparison

Levantar GCP prod a 1 nodo, correr Locust contra ambos endpoints:
```bash
gcloud container clusters resize circleguard-prod --node-pool=default-pool --num-nodes=1 --region=us-central1 --project=tallerfinal-496702 --quiet
# Obtener IPs externas via kubectl get svc -n circleguard-production
# Correr Locust contra GCP prod y DO prod con mismo perfil
```

### Paso 4 — Task 11.13: Diagrama infraestructura

Agregar los 3 clusters DO al diagrama Mermaid en `docs/diagrams/infrastructure.md`.

---

## Jenkins

- Container: `circleguard-jenkins` — `docker start circleguard-jenkins && docker exec --user root circleguard-jenkins chmod 666 /var/run/docker.sock`
- URL: http://localhost:8080 | Password: `0de72cfcad744533ad0b8dca62e9b879`

## Identidad GCP

- Project: `tallerfinal-496702` | Region: `us-central1`
- Terraform state: `gs://circle-guard-tfstate-496702/`
