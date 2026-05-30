# CircleGuard — Network Policies (Istio AuthorizationPolicies)

## Approach

Istio `AuthorizationPolicy` resources provide default-deny with explicit allowlists, enforcing that only expected service-to-service paths are permitted. All policies are in `k8s/istio/authorization-policies.yaml`.

## Allowed edges

| Source | Destination | Purpose |
|--------|-------------|---------|
| `istio-ingressgateway` | all services | External traffic entry |
| `gateway-service` | `auth-service` | Token validation |
| `auth-service` | `identity-service` | Anonymous ID lookup |
| `dashboard-service` | `promotion-service` | Analytics data reads |
| `monitoring` namespace | all services | Prometheus `/actuator/prometheus` scrape |
| Any (kubelet) | all services | `/actuator/health/*` probes |

## What is blocked

- Direct calls between services not in the allowed edges above
- External clients calling services directly (bypassing gateway)
- Any non-HTTPS ingress (redirected to HTTPS via gateway-tls.yaml)

## Applying the policies

```bash
export KUBECONFIG=~/.kube/circleguard-dev
kubectl apply -f k8s/istio/authorization-policies.yaml
# Verify
kubectl get authorizationpolicies -n circleguard-dev
```

## Testing the deny

```bash
# From inside a pod that is NOT gateway-service, try calling auth-service
kubectl run test --rm -it --image=curlimages/curl -n circleguard-dev -- \
  curl -s http://auth-service:8180/actuator/health
# Expected: connection refused / RBAC denied (403)
```
