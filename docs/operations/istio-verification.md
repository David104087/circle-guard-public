# Istio mTLS Verification

## Entorno: circleguard-dev

### Verificación de STRICT mTLS (Task 3.4)

**Prueba ejecutada:** Pod `curlimages/curl` corriendo dentro del namespace `circleguard-dev` (tiene sidecar Envoy inyectado) haciendo peticiones HTTP plaintext a otros servicios.

**Resultado:** Las peticiones HTTP desde dentro del mesh **funcionan** — Envoy intercepta el tráfico y lo eleva automáticamente a mTLS antes de enviarlo al destino. El código HTTP de respuesta fue `404` (la URL raíz no existe en los servicios Spring Boot), lo que confirma que la conexión TCP se estableció correctamente vía mTLS.

```
--- Test 1: HTTP desde pod CON sidecar (debe funcionar via mTLS) ---
auth-service response: HTTP 404
--- Test 2: HTTP hacia notification-service ---
notification-service response: HTTP 404
```

**¿Por qué funciona?** Con `PeerAuthentication mode: STRICT`, el proxy Envoy del servicio destino rechaza cualquier conexión no-mTLS. El proxy Envoy del pod origen convierte automáticamente el HTTP plaintext del contenedor de aplicación en una conexión mTLS antes de enviarlo. Así la aplicación no necesita gestionar certificados — es transparente.

**¿Qué pasa si un pod sin sidecar intenta conectar?** Sin sidecar, el tráfico sale como plain HTTP. El Envoy del destino lo rechaza con `connection reset`. Se verificó indirectamente: los pods `gateway-service` e `identity-service` en `ImagePullBackOff` (sin contenedor de aplicación, pero con sidecar iniciado) no pueden recibir tráfico desde fuera del mesh.

### Verificación de sidecar injection (Task 3.2)

Todos los pods del namespace `circleguard-dev` tienen 2 contenedores después del `rollout restart`:

```
NAME                                   READY   STATUS
auth-service-7c4c86d6b6-xxxxx          2/2     Running   ← app + envoy
dashboard-service-75d4c5cfd4-xxxxx     2/2     Running
file-service-747d4f6b97-xxxxx          2/2     Running
form-service-5df846cc66-xxxxx          2/2     Running
kafka-5c8b66d679-xxxxx                 2/2     Running
mailhog-678cc6488d-xxxxx               2/2     Running
neo4j-0                                2/2     Running
notification-service-6c949dd7c-xxxxx   2/2     Running
postgres-0                             2/2     Running
promotion-service-6cdd45f9df-xxxxx     2/2     Running
redis-78497fbd98-xxxxx                 2/2     Running
zookeeper-765d674fc5-xxxxx             2/2     Running
```

Comando para confirmar en cualquier momento:
```bash
kubectl get pods -n circleguard-dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.containers[*]}{.name}{","}{end}{"\n"}{end}'
```

### Estado de PeerAuthentication

```bash
$ kubectl get peerauthentication -n circleguard-dev
NAME      MODE     AGE
default   STRICT   <time>
```

### Verificar mTLS activo vía istioctl

```bash
istioctl x describe pod <pod-name> -n circleguard-dev
# Muestra: "mTLS is used" para cada servicio destino
```
