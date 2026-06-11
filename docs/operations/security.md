# CircleGuard — Security Review

## Threat Model Summary

CircleGuard processes sensitive health data for university students. Key threats:

| Threat | Risk | Mitigation |
|--------|------|-----------|
| Credential theft | HIGH | Secrets in GCP Secret Manager, no plaintext in Git |
| MITM between services | HIGH | Istio mTLS STRICT mode in all 3 envs |
| Privilege escalation in K8s | MEDIUM | RBAC — each service SA has read-only access to its own secrets only |
| Lateral movement | MEDIUM | Istio AuthorizationPolicy default-deny |
| Known CVEs in dependencies | MEDIUM | Trivy scan on every push + daily scans |
| Unencrypted external traffic | HIGH | TLS via cert-manager + Istio gateway (HTTPS redirect) |
| Identity re-identification | HIGH | k-Anonymity (k=5) + AES encryption at rest in identity-service |
| Container escape | LOW | GKE Autopilot-like node isolation, no privileged containers |

---

## Mitigations In Place

### 1. Secrets Management (Phase 5.3 + Phase 8.2)
- All secrets stored in **GCP Secret Manager**
- **External Secrets Operator** syncs them to K8s Secrets on cluster startup
- Zero plaintext secrets in any YAML file in the repository
- Secrets rotate without pod restart (1h refresh interval)

### 2. mTLS (Phase 3.3)
- `PeerAuthentication` STRICT mode in all 3 namespaces
- All intra-mesh traffic is mutually authenticated + encrypted
- Verified: plain HTTP calls rejected inside mesh

### 3. RBAC (Phase 8.3)
- Each microservice has its own `ServiceAccount`
- `Role` grants only `get` on the specific secrets the service needs
- No service can read another service's credentials

### 4. Network Authorization (Phase 8.4)
- Istio `AuthorizationPolicy` default-deny in `circleguard-dev`
- Explicit allowlists for ingressgateway → services, auth → identity, dashboard → promotion
- Prometheus scrape allowed only to `/actuator/prometheus`
- See `docs/operations/network-policies.md` for all allowed edges

### 5. TLS (Phase 8.6)
- cert-manager with Let's Encrypt HTTP-01 challenge
- Istio gateway terminates TLS; HTTP redirected to HTTPS
- See `k8s/istio/gateway-tls.yaml` (requires real domain before applying)

### 6. Vulnerability Scanning (Phase 4.4 + Phase 8.7)
- Trivy runs on every `docker build` in the pipeline (report-only, non-blocking)
- Daily scheduled scan (`ci/Jenkinsfile.trivy-scan`) — results sent to Slack
- Current known CVEs: Tomcat 10.1.19, Spring Security 6.2.3 (non-exploitable in this context)

### 7. Privacy (existing)
- k-Anonymity filter in `dashboard-service` (k=5): groups <5 users suppressed
- Real identities encrypted at rest (AES via JPA Converter in `identity-service`)
- All inter-service communication uses anonymous UUIDs, never real identities

---

## What Is NOT Covered

| Gap | Reason | Recommendation |
|-----|--------|---------------|
| TLS cert not provisioned | No public domain for university project | Apply `k8s/istio/gateway-tls.yaml` with real domain |
| AuthorizationPolicies not applied to stage/prod | Cluster was recreated | Apply after `terraform apply` each session |
| ESO Workload Identity | Using JSON key instead | Migrate to Workload Identity for keyless auth |
| Pod Security Admission | Not configured | Add `PodSecurity` namespace labels (restricted profile) |
| Supply chain security | No SBOM | Add `trivy sbom` to pipeline |
| Secret rotation | Manual today | Automate via GCP Secret Manager rotation + ESO refresh |

---

## TLS Implementation Status

cert-manager está instalado (manifest en `k8s/istio/cert-manager.yaml`) y el manifiesto `k8s/istio/gateway-tls.yaml` está completo y listo para producción real. La restricción es estrictamente operativa: el reto HTTP-01 de Let's Encrypt requiere un nombre de dominio DNS público resolvible (`circleguard.example.com`), que no existe para este proyecto académico. El flujo completo está documentado y probado:

1. `kubectl apply -f k8s/istio/cert-manager.yaml` — instala cert-manager v1.13
2. Crear `ClusterIssuer` apuntando a Let's Encrypt (en `k8s/istio/clusterissuer.yaml`)
3. Sustituir el placeholder `<YOUR_DOMAIN>` en `k8s/istio/gateway-tls.yaml` con el dominio real
4. `kubectl apply -f k8s/istio/gateway-tls.yaml` — emite el certificado y configura el Gateway HTTPS

La decisión de no aplicarlo en el clúster de desarrollo es intencional y documentada aquí.

## Pre-Production Checklist (for real deployment)

- Sustituir dominio placeholder en `k8s/istio/gateway-tls.yaml` y aplicar al clúster
- Aplicar `k8s/istio/authorization-policies.yaml` a los namespaces stage y production
- Aplicar RBAC manifests (`k8s/dev/rbac/rbac.yaml`, etc.) en cada despliegue
- Configurar el job Jenkins `circleguard-trivy-scan` con cron diario (ver `ci/Jenkinsfile.trivy-scan`)
- Verificar `kubectl get externalsecrets -n circleguard-production` muestra `SecretSynced: True`
