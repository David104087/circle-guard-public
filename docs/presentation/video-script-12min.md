# CircleGuard — Script de Video 12 Minutos

Script optimizado para demostración del Proyecto Final IngeSoft V.
Cada segmento dura 30–40 segundos. Total: ~12 minutos.

---

## Segmento 1 — Introducción (0:00–0:35)

**Mostrar:** Página principal del repositorio en GitHub (`github.com/David104087/circle-guard-public`)

**Decir:**
> "CircleGuard es una plataforma universitaria de monitoreo de salud construida con 8 microservicios Spring Boot. Para el Proyecto Final de IngeSoft V implementamos infraestructura como código con Terraform en GCP, un pipeline CI/CD avanzado con Jenkins, service mesh con Istio, observabilidad completa, seguridad, y tres bonificaciones: Multi-Cloud en DigitalOcean, Chaos Engineering con Chaos Mesh, y FinOps con Kubecost."

---

## Segmento 2 — Arquitectura (0:35–1:15)

**Mostrar:** Abrir [`docs/diagrams/architecture.md`](../diagrams/architecture.md) en el editor — diagrama Mermaid del sistema

**Decir:**
> "Los 8 servicios se comunican por Kafka para eventos asíncronos y REST para llamadas síncronas. El gateway-service recibe todo el tráfico externo. Hay 3 ambientes — dev, stage y production — cada uno en su propio GKE cluster con namespaces independientes."

**Mostrar (mientras habla):** Hacer scroll para mostrar el diagrama de deployment view con los 3 namespaces

---

## Segmento 3 — Terraform IaC (1:15–1:55)

**Mostrar:** Estructura de carpetas en VS Code — `terraform/` expandido mostrando `modules/` y `envs/`

**Decir:**
> "Toda la infraestructura está en Terraform. Módulos reutilizables para VPC, GKE, Artifact Registry, Secret Manager e IAM. Tres ambientes con un solo `terraform apply`. El estado remoto está en GCS."

**Mostrar:** Abrir `terraform/envs/dev/main.tf` — señalar los módulos llamados y la variable `use_spot = true`

**Decir (continuando):**
> "Dev y stage usan nodos Spot para reducir costos — parte de nuestra estrategia FinOps."

---

## Segmento 4 — CI/CD Pipeline (1:55–3:10)

**Mostrar:** Jenkins en http://localhost:8080 — lista de jobs

**Decir:**
> "El pipeline DEV tiene 10 stages. Voy a mostrar el último build exitoso."

**Mostrar:** Abrir el último build del job `circleguard-dev` — vista de stages (azul/verde)

**Decir (señalando stages):**
> "Checkout → Build con Gradle → SonarQube → Tests unitarios paralelos → Reporte JaCoCo → Docker build con Trivy → Push a Docker Hub → Deploy en GKE. Cada push a una rama feature dispara este pipeline automáticamente."

**Mostrar:** `ci/Jenkinsfile.dev` — señalar la sección `parallel` de Unit Tests y el stage de Chaos Smoke Test

**Decir:**
> "Los tests corren en paralelo para los 6 servicios. El stage final es el Chaos Smoke Test — parte de la fase de Chaos Engineering."

---

## Segmento 5 — SonarQube + Cobertura (3:10–3:50)

**Mostrar:** SonarQube en http://localhost:9000 — dashboard general con los 8 proyectos

**Decir:**
> "SonarQube analiza los 8 servicios. El quality gate debe pasar para que el pipeline continúe. Tenemos 67% de cobertura de línea con JaCoCo — por encima del umbral mínimo del 60% configurado en el pipeline."

**Mostrar:** Click en un servicio (auth-service) — mostrar cobertura, code smells y vulnerabilidades

---

## Segmento 6 — Istio Service Mesh (3:50–4:50)

**Mostrar:** `docs/diagrams/kiali-graph.png` — screenshot del graph de Kiali

**Decir:**
> "Istio está instalado en los 3 ambientes con mTLS STRICT. Esta es la gráfica de Kiali mostrando los 8 servicios con los candados de mTLS en cada edge — todo el tráfico interno está mutuamente autenticado y encriptado."

**Mostrar:** `k8s/istio/destination-rules.yaml` — señalar la sección `outlierDetection` (circuit breaker)

**Decir:**
> "El circuit breaker está configurado en cada DestinationRule. Si un servicio devuelve más del 10% de errores 5xx, Istio lo expulsa del pool durante 30 segundos. Los retries están configurados en los VirtualServices para endpoints idempotentes."

**Mostrar:** `docs/operations/canary-deployments.md` — primeras líneas del proceso canary

**Decir:**
> "Para el canary: el pipeline master despliega la nueva versión como v2, Istio dirige el 10% del tráfico, esperamos aprobación manual en Jenkins, y promovemos al 100%."

---

## Segmento 7 — Observabilidad (4:50–6:00)

**Mostrar:** Grafana en localhost:3000 — abrir dashboard de uno de los servicios (si cluster activo) o mostrar `k8s/monitoring/dashboards/` con los 9 JSON files

**Decir:**
> "El stack de observabilidad completo: Prometheus recolecta métricas de todos los servicios vía ServiceMonitor, Grafana tiene 9 dashboards — uno por servicio más los de Istio y FinOps."

**Mostrar:** `docs/operations/alerts.md` — tabla de las 6 alertas

**Decir:**
> "Seis reglas de alerta en PrometheusRule: pod crash-looping, pod not ready, latencia p95 mayor a 1 segundo, error rate mayor a 5%, heap JVM mayor al 90%, y PVC más del 85% lleno. Alertmanager las enruta a Slack."

**Mostrar:** `k8s/logging/` — archivos de Elasticsearch y Fluent Bit

**Decir:**
> "Para logs, usamos EFK: Elasticsearch + Fluent Bit como DaemonSet + Kibana. Fluent Bit se eligió sobre Logstash por su huella de memoria 10 veces menor — crítico en nodos con 4GB de RAM."

---

## Segmento 8 — Seguridad (6:00–6:45)

**Mostrar:** `k8s/dev/rbac/rbac.yaml` — primer ServiceAccount + Role + RoleBinding

**Decir:**
> "Cada microservicio tiene su propio ServiceAccount con permisos mínimos — solo lectura a su propio Secret. External Secrets Operator sincroniza los secretos desde GCP Secret Manager; no hay ningún valor en texto plano en el repositorio."

**Mostrar:** Ejecutar en terminal: `grep -rE "password:|secret:" k8s/dev/*.yaml | grep -v ExternalSecret | head -5` — mostrar que no hay resultados

**Decir:**
> "Este grep confirma que no hay credenciales en texto plano en los manifiestos. Trivy escanea cada imagen en el pipeline y reporta vulnerabilidades."

---

## Segmento 9 — Multi-Cloud DigitalOcean (6:45–7:35)

**Mostrar:** `terraform/envs/do-dev/main.tf` — módulo DOKS, variable `node_size`, `min_nodes = 0`

**Decir:**
> "Phase 11: el mismo stack desplegado en DigitalOcean. Tres clusters DOKS en nyc1 — do-dev, do-stage, do-prod — con los mismos manifiestos de Kubernetes, solo cambia el StorageClass."

**Mostrar:** `docs/operations/multi-cloud.md` — tabla de comparación de rendimiento

**Decir:**
> "La comparativa de rendimiento: GCP prod tiene p95 de 142ms, DigitalOcean p95 de 189ms al mismo perfil de carga. La estrategia de failover es DNS activo-pasivo: GCP primario, DO como hot standby con TTL de 60 segundos."

---

## Segmento 10 — Chaos Engineering (7:35–8:45)

**Mostrar:** `docs/chaos/results.md` — tabla de los 5 experimentos

**Decir:**
> "Phase 12: Chaos Mesh v2.7.0 instalado en namespace chaos-testing. Diseñamos y ejecutamos 5 experimentos de caos."

**Mostrar:** `docs/chaos/manifests/02-network-delay.yaml` — señalar los campos `latency`, `jitter`, `selector`

**Decir:**
> "Experimento 2: inyectamos 200ms de delay en la comunicación entre form-service y notification-service. AllInjected=True confirmado. Ambos pods se mantuvieron Running y recuperaron al instante."

**Mostrar:** `k8s/dev/dashboard-service.yaml` — señalar la anotación `holdApplicationUntilProxyStarts`

**Decir:**
> "El experimento 3 — partición de red — nos mostró que el circuit breaker de Istio es esencial en producción. El experimento 1 — pod kill — generó una mejora: añadimos esta anotación en 4 servicios para evitar el race condition entre el sidecar de Istio y la app al reiniciar."

---

## Segmento 11 — FinOps (8:45–9:40)

**Mostrar:** `docs/operations/finops.md` — tabla de estrategias de ahorro

**Decir:**
> "Phase 13: implementamos 5 estrategias de FinOps. Kubecost 2.8.6 muestra el costo por namespace y por pod. Spot VMs en dev y stage reducen el costo de los nodos un 60-80%. Scale-to-zero automático elimina costos en noches y fines de semana."

**Mostrar:** `ci/session-stop.sh` — las primeras líneas que hacen resize a 0

**Decir:**
> "Este script escala todos los clusters a 0 nodos en paralelo al finalizar cada sesión. Combinado con preemptibles y requests correctos en Kubecost, el ahorro estimado es de 442 dólares mensuales frente al baseline sin optimización."

---

## Segmento 12 — Change Management + Releases (9:40–10:30)

**Mostrar:** GitHub Releases en `github.com/David104087/circle-guard-public/releases` — los 3 releases

**Decir:**
> "Cada fase de producción tiene su release en GitHub con release notes generadas automáticamente desde los commits convencionales. v0.1.0 cubre las fases base, v0.2.0 añade Multi-Cloud y FinOps, v0.3.0 cierra con Chaos Engineering."

**Mostrar:** `RELEASE_NOTES_v0.3.0.md` — primeras secciones

**Decir:**
> "Las release notes se generan con el script ci/release-notes.sh que agrupa por tipo de commit: features, fixes, docs, CI/CD. El proceso de Change Management está documentado incluyendo quién aprueba, qué gates existen, y cómo hacer rollback con un kubectl rollout undo."

---

## Segmento 13 — Cierre y Lecciones Aprendidas (10:30–11:30)

**Mostrar:** `docs/lessons-learned.md` — primeros puntos

**Decir:**
> "Tres lecciones clave del proyecto. Primero: las cuotas de GCP requieren planificación — CPUS_ALL_REGIONS de 12 vCPUs limita a 2 clusters simultáneos con e2-standard-2. Segundo: los nodos DO de 4GB son insuficientes para 8 JVMs — necesitamos 8GB para dev. Tercero: Istio cambia fundamentalmente la red del cluster; hay que instalarlo antes que cualquier otra cosa para no tener que redesplegar todo."

**Mostrar:** `docs/operations/README.md` — índice de toda la documentación operacional

**Decir:**
> "Toda la documentación operacional está indexada aquí: runbooks de alertas, rollback, canary, chaos, seguridad, multi-cloud, FinOps. Un nuevo desarrollador puede clonar el repo, leer el README y aprovisionar un ambiente completo sin preguntar."

---

## Segmento 14 — Demo Final (11:30–12:00)

**Mostrar:** `docs/releases/README.md` — tabla con los 3 releases

**Decir:**
> "Para cerrar: CircleGuard en producción tiene 14 fases completas, 3 ambientes en 2 clouds, 115 tests, pipeline con 10 stages, 9 dashboards de Grafana, 5 experimentos de caos documentados, y todos los bonuses implementados. Gracias."

---

## Notas de grabación

- **Resolución recomendada:** 1920×1080, fuente del editor a 16px mínimo
- **Orden de ventanas:** VS Code izquierda, terminal/browser derecha
- **Para los dashboards:** si el cluster no está activo, mostrar los JSON en `k8s/monitoring/dashboards/` y explicar que se visualizan en Grafana
- **Para Kiali:** mostrar `docs/diagrams/kiali-graph.png` directamente
- **Terminal:** usar iTerm2 con fondo oscuro para mayor legibilidad
- **Link del video:** agregar aquí una vez grabado y subido
