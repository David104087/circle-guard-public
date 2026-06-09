# Acciones manuales pendientes

Este archivo lista pushes, PRs, y acciones en consolas externas que deben hacerse manualmente.
Actualizar cuando se completen.

---

## Git — PRs pendientes

### PR: feat/finops-bonus → master

**Título:** `feat(finops): FinOps bonus — cost dashboard, Kubecost setup, session scripts, resource requests`

**Cuerpo sugerido:**
```
## Summary

- ci/session-start.sh + ci/session-stop.sh: automatizan escala a 0 de clusters GKE y ciclo Jenkins/SonarQube
- k8s/monitoring/dashboards/finops.json: dashboard Grafana con utilización CPU/memoria, detección de desperdicio, costo estimado por servicio
- k8s/monitoring/kubecost-values.yaml: values de Helm para Kubecost usando kube-prometheus-stack existente
- k8s/{dev,stage,production}: memory requests corregidos 64Mi → 256Mi en los 8 servicios × 3 entornos
- docs/operations/finops.md: 5 estrategias de ahorro documentadas (~$442/mes vs baseline sin optimización)
- docs/operations/costs.md: extendido con tabla de ahorros FinOps y atribución de costos por servicio

## Pending (manual/cluster)

- 13.1 — GCP billing export a BigQuery: paso manual en GCP Console (documentado en finops.md)
- 13.2 — helm install kubecost: ejecutar cuando el cluster dev esté activo

## Test plan

- [ ] ci/session-stop.sh escala clusters a 0
- [ ] ci/session-start.sh escala dev a 1 nodo
- [ ] kubectl apply -k k8s/monitoring/dashboards/ → Grafana muestra "CircleGuard — FinOps Cost Dashboard"
- [ ] helm install kubecost → UI en localhost:9090
```

**Comando para crear el PR:**
```bash
gh pr create \
  --title "feat(finops): FinOps bonus — cost dashboard, Kubecost setup, session scripts, resource requests" \
  --base master \
  --head feat/finops-bonus
```

---

## GCP Console — acciones manuales

### Billing Export a BigQuery (Phase 13 — task 13.1)

1. Ir a GCP Console → Billing → [Billing Account `019044-EE5C1C-F61E8F`] → Billing Export
2. Click "Standard Usage Cost" → Edit Settings
3. Project: `tallerfinal-496702`, Dataset: `billing_export`
4. Click Save
5. Esperar ~24h para que aparezcan los primeros datos
6. Marcar task 13.1 como `[x]` en CLAUDE.md

### Kubecost Install (Phase 13 — task 13.2)

Ejecutar cuando el cluster dev esté activo (`ci/session-start.sh`):

```bash
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm repo update
helm install kubecost kubecost/cost-analyzer \
  -n kubecost --create-namespace \
  -f k8s/monitoring/kubecost-values.yaml

# Verificar
kubectl get pods -n kubecost
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090
# Abrir: http://localhost:9090
```

Una vez verificado, marcar task 13.2 como `[x]` en CLAUDE.md.

---

## Kiali Screenshot (Phase 3 — task 3.11)

Con el cluster dev activo e Istio instalado:

```bash
istioctl dashboard kiali
# Esperar que abra el browser
# Ir a Graph → Namespace: circleguard-dev
# Asegurarse de que hay tráfico (correr ci/smoke-test.sh primero)
# Tomar screenshot
# Guardar en: docs/diagrams/kiali-graph.png
```

Luego marcar task 3.11 como `[x]` en CLAUDE.md.
