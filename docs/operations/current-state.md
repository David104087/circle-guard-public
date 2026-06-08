# CircleGuard — Estado Actual del Proyecto

> **IMPORTANTE para agentes:** Lee este archivo al inicio de cada sesión de trabajo.
> Actualízalo cada vez que se despliegue, destruya, o cambie algo relevante.
> Es la fuente de verdad del estado real del sistema.

---

## Última actualización
2026-06-08 — **Phase 11 Multi-Cloud en progreso.** Tasks 11.1–11.5 completas (código listo). Tasks 11.6–11.13 pendientes. Todos los clusters DO destruidos al cierre. GCP a 0 nodos. El ÚNICO desbloqueador para la próxima sesión es el fix de liveness probes (ver sección "Problema crítico pendiente").

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
| Phase 11 — Multi-Cloud (Bonus) | 🟡 5/13 tareas ✅ |
| Phase 12 — Chaos Engineering | 🔴 No iniciada |
| Phase 13 — FinOps | 🟡 Parcial |

---

## ⚠️ PROBLEMA CRÍTICO PENDIENTE (leer antes de empezar)

**Síntoma:** Todos los pods de servicios Spring Boot en DO crashean a exactamente 300 segundos después de arrancar, aunque el servicio está funcionando.

**Causa raíz confirmada:** El liveness probe usa `httpGet /actuator/health/liveness`. Spring Boot solo expone ese endpoint separado cuando `MANAGEMENT_HEALTH_LIVENESSSTATE_ENABLED=true` está configurado. Sin esa config, el endpoint retorna 404 → K8s falla 3 veces (default failureThreshold=3) → envía SIGTERM → el servicio hace graceful shutdown. Parece un crash pero es K8s matando el pod.

**Fix en los manifests `k8s/do-dev/` (DEBE hacerse ANTES de cualquier deploy):**
Cambiar en los 8 archivos `k8s/do-dev/*.yaml` el liveness probe de:
```yaml
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: <PORT>
  initialDelaySeconds: 300
```
A:
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
**Nota:** `/actuator/health` (sin `/liveness`) sí existe siempre. La readiness probe puede usar ese endpoint. La liveness con tcpSocket solo verifica que el puerto esté abierto.

Servicios y puertos:
| Servicio | Puerto |
|---------|--------|
| auth-service | 8180 |
| dashboard-service | 8084 |
| file-service | 8085 |
| form-service | 8086 |
| gateway-service | 8087 |
| identity-service | 8083 |
| notification-service | 8082 |
| promotion-service | 8088 |

---

## Infraestructura GCP (estado actual)

| Cluster | Estado |
|---------|--------|
| circleguard-dev | 0 nodos (escalado) |
| circleguard-prod | 0 nodos (escalado) |
| circleguard-stage | destruido |

Para escalar dev a 1 nodo: `gcloud container clusters resize circleguard-dev --node-pool=default-pool --num-nodes=1 --region=us-central1 --project=tallerfinal-496702 --quiet`

---

## Infraestructura DO (estado actual: TODO DESTRUIDO)

| Cluster | Estado | Terraform env | Node size |
|---------|--------|---------------|-----------|
| circleguard-do-dev | DESTRUIDO | `terraform/envs/do-dev/` | **s-4vcpu-8gb** ← importante |
| circleguard-do-stage | DESTRUIDO | `terraform/envs/do-stage/` | s-2vcpu-4gb |
| circleguard-do-prod | DESTRUIDO | `terraform/envs/do-prod/` | s-2vcpu-4gb |

**Límite de cuenta DO:** 3 droplets totales → max_nodes=1 en los 3 envs (ya configurado).
**Kubeconfigs DO:** expiran ~1h. Siempre refrescar con `terraform output -raw kube_config > ~/.kube/circleguard-do-<env>`.

---

## Playbook completo para la próxima sesión (Phase 11)

### Paso 0 — Fix liveness probes (10 min, OBLIGATORIO PRIMERO)

Editar los 8 archivos en `k8s/do-dev/` reemplazando los liveness/readiness probes como se describe en la sección anterior. Luego hacer commit en la rama `feat/multi-cloud-bonus`.

### Paso 1 — Levantar do-dev (15 min)

```bash
export TF_VAR_do_token="dop_v1_..."
cd terraform/envs/do-dev
terraform apply -auto-approve
terraform output -raw kube_config > ~/.kube/circleguard-do-dev
export KUBECONFIG=~/.kube/circleguard-do-dev
kubectl get nodes  # verificar 1 nodo Ready
```

### Paso 2 — Deploy infraestructura do-dev (5 min)

```bash
kubectl apply -f k8s/do-dev/00-namespace.yaml
kubectl apply -f k8s/do-dev/infrastructure/
# Esperar ~3 min
kubectl get pods -n circleguard-do-dev
# postgres-0, kafka, zookeeper, redis, neo4j, mailhog deben estar 1/1 Running
```

### Paso 3 — Verificar bases de datos Postgres (2 min)

```bash
kubectl exec postgres-0 -n circleguard-do-dev -- psql -U admin -l
# Deben aparecer: circleguard_auth, circleguard_dashboard, circleguard_form,
# circleguard_promotion, circleguard_identity
# Si NO aparecen (cluster fresco con PVC nueva puede que sí corran los init scripts):
for db in circleguard_auth circleguard_dashboard circleguard_form circleguard_promotion circleguard_identity; do
  kubectl exec postgres-0 -n circleguard-do-dev -- psql -U admin -d circleguard -c "CREATE DATABASE $db;" 2>/dev/null || true
done
```

### Paso 4 — Deploy servicios do-dev (5 min + espera)

```bash
kubectl apply -f k8s/do-dev/
# Esperar ~5 min (Spring Boot arranca en ~45s con 8GB nodo + JAVA_TOOL_OPTIONS)
watch kubectl get pods -n circleguard-do-dev
# Todos deben llegar a 1/1 Running
```

### Paso 5 — Smoke test do-dev (2 min)

```bash
kubectl run --rm -it tester --image=curlimages/curl --restart=Never -n circleguard-do-dev -- \
  sh -c "for svc in auth-service:8180 gateway-service:8087 identity-service:8083 dashboard-service:8084; do echo -n \$svc:; curl -s http://\$svc/actuator/health | head -c 30; echo; done"
# ✅ Task 11.6 y 11.7 completas
```

### Paso 6 — Instalar Istio en do-dev (10 min)

```bash
istioctl install --set profile=demo -y
kubectl label namespace circleguard-do-dev istio-injection=enabled
kubectl apply -f k8s/istio/peer-authentication.yaml
# (peer-authentication.yaml usa namespace circleguard-dev — crear versión do-dev o parcharlo)
kubectl rollout restart deployment -n circleguard-do-dev
kubectl get pods -n circleguard-do-dev  # deben mostrar 2/2 (app + envoy sidecar)
kubectl get peerauthentication -n circleguard-do-dev  # debe mostrar STRICT
# ✅ Task 11.8 completa
```

**Nota sobre peer-authentication:** El archivo `k8s/istio/peer-authentication.yaml` puede referirse al namespace `circleguard-dev`. Crear `k8s/do-dev/peer-authentication.yaml` con el namespace correcto `circleguard-do-dev`.

### Paso 7 — Repetir para do-stage y do-prod (20 min)

```bash
# do-stage
cd terraform/envs/do-stage && terraform apply -auto-approve
terraform output -raw kube_config > ~/.kube/circleguard-do-stage
# Repetir pasos 2-6 con KUBECONFIG=~/.kube/circleguard-do-stage y namespace circleguard-do-stage

# do-prod
cd terraform/envs/do-prod && terraform apply -auto-approve
terraform output -raw kube_config > ~/.kube/circleguard-do-prod
# Repetir pasos 2-6 con KUBECONFIG=~/.kube/circleguard-do-prod y namespace circleguard-do-prod
# ✅ Task 11.9 completa
```

### Paso 8 — Jenkins + docs (30 min)

- Agregar credenciales `do-dev-kubeconfig`, `do-stage-kubeconfig`, `do-prod-kubeconfig` en Jenkins
- Agregar stage paralelo de deploy en `ci/Jenkinsfile.dev`
- Documentar LB activo-pasivo en `docs/operations/multi-cloud.md`
- Correr Locust contra GCP prod y DO prod, comparar métricas
- ✅ Tasks 11.10–11.12 completas

---

## Jenkins

- Container: `circleguard-jenkins` — `docker start circleguard-jenkins && docker exec --user root circleguard-jenkins chmod 666 /var/run/docker.sock`
- URL: http://localhost:8080 | Password: `0de72cfcad744533ad0b8dca62e9b879`

## Identidad GCP

- Project: `tallerfinal-496702` | Region: `us-central1`
- Terraform state: `gs://circle-guard-tfstate-496702/`
