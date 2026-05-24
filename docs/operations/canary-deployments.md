# Canary Deployments con Istio

## Estrategia

CircleGuard usa `gateway-service` (el API Gateway) como el servicio canary de referencia.
El canary se gestiona ajustando los pesos en el `VirtualService` de Istio — sin necesidad de
reiniciar pods ni cambiar el número de réplicas.

## Estructura de recursos

### DestinationRule (`k8s/istio/destination-rules.yaml`)

`gateway-service` tiene dos subsets definidos:

```yaml
subsets:
  - name: v1
    labels:
      version: "latest"   # Pods actuales en producción
  - name: v2
    labels:
      version: "v2"       # Pods del canary (nueva versión)
```

### VirtualService (`k8s/istio/gateway.yaml`)

El split inicial es 100% → v1, 0% → v2 (canary inactivo):

```yaml
http:
  - route:
      - destination:
          host: gateway-service
          subset: v1
        weight: 100
      - destination:
          host: gateway-service
          subset: v2
        weight: 0
```

## Workflow de un despliegue canary

### 1. Desplegar la nueva versión como v2

```bash
# Crear un deployment separado con label version: v2
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gateway-service-v2
  namespace: circleguard-<env>
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gateway-service
      version: v2
  template:
    metadata:
      labels:
        app: gateway-service
        version: v2
    spec:
      containers:
        - name: gateway-service
          image: davidartunduaga/circleguard-gateway:v2
          # ... resto de la config igual que v1
EOF
```

### 2. Activar canary al 10%

```bash
kubectl patch virtualservice gateway-service -n circleguard-<env> \
  --type=json \
  -p='[
    {"op":"replace","path":"/spec/http/0/route/0/weight","value":90},
    {"op":"replace","path":"/spec/http/0/route/1/weight","value":10}
  ]'
```

### 3. Monitorear en Kiali

```bash
istioctl dashboard kiali
```

Observar el traffic graph: el servicio `gateway-service` mostrará dos destinos (v1/v2) con el split 90/10.

### 4a. Promover a 100% (éxito)

```bash
kubectl patch virtualservice gateway-service -n circleguard-<env> \
  --type=json \
  -p='[
    {"op":"replace","path":"/spec/http/0/route/0/weight","value":0},
    {"op":"replace","path":"/spec/http/0/route/1/weight","value":100}
  ]'
# Luego eliminar el deployment v1 o actualizar su imagen
```

### 4b. Rollback (fallo detectado)

```bash
# Volver a 100% v1
kubectl patch virtualservice gateway-service -n circleguard-<env> \
  --type=json \
  -p='[
    {"op":"replace","path":"/spec/http/0/route/0/weight","value":100},
    {"op":"replace","path":"/spec/http/0/route/1/weight","value":0}
  ]'
# Eliminar el deployment v2
kubectl delete deployment gateway-service-v2 -n circleguard-<env>
```

## Integración con CI/CD (Phase 4)

En el Jenkinsfile.master, el canary se automatiza:

1. Pipeline despliega v2 (1 réplica)
2. Ajusta VirtualService a 10% → espera 30 min con `input` manual
3. Si se aprueba → 100% v2
4. Si se cancela o falla → rollback automático a 100% v1

Ver `docs/operations/rollback.md` para el procedimiento de rollback detallado.
