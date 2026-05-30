# CircleGuard — Rollback Runbook

Exact commands to roll back a failed production deployment.

---

## 1. Standard Rollback (Kubernetes)

Roll back any service to the previous version:

```bash
export KUBECONFIG=~/.kube/circleguard-prod

# Roll back a specific service
kubectl rollout undo deployment/auth-service -n circleguard-production
kubectl rollout undo deployment/promotion-service -n circleguard-production

# Verify rollback completed
kubectl rollout status deployment/auth-service -n circleguard-production --timeout=120s

# Check which image is now running
kubectl get deployment auth-service -n circleguard-production \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Expected timing: **30–90 seconds** per service.

---

## 2. Canary Rollback (Istio VirtualService)

If the canary was deployed but not yet approved:

```bash
export KUBECONFIG=~/.kube/circleguard-prod

# Restore 100% traffic to stable v1, 0% to canary
kubectl patch virtualservice auth-service -n circleguard-production --type=json \
  -p '[
    {"op":"replace","path":"/spec/http/0/route/0/weight","value":100},
    {"op":"replace","path":"/spec/http/0/route/1/weight","value":0},
    {"op":"replace","path":"/spec/http/1/route/0/weight","value":100},
    {"op":"replace","path":"/spec/http/1/route/1/weight","value":0}
  ]'

# Delete canary deployment
kubectl delete deployment auth-service-canary -n circleguard-production --ignore-not-found

# Verify traffic is back to 100% v1
kubectl get virtualservice auth-service -n circleguard-production \
  -o jsonpath='{.spec.http[0].route}'
```

Expected timing: **< 10 seconds** (Istio propagates config immediately).

---

## 3. Full Service Rollback (specific image tag)

To roll back to a specific version (e.g., `v8`):

```bash
export KUBECONFIG=~/.kube/circleguard-prod

kubectl set image deployment/auth-service \
  auth-service=davidartunduaga/circleguard-auth:v8 \
  -n circleguard-production

kubectl rollout status deployment/auth-service \
  -n circleguard-production --timeout=120s
```

---

## 4. Rollback Drill (documented timing)

**Drill performed:** 2026-05-25 during Phase 4 testing

| Step | Duration | Notes |
|------|----------|-------|
| Canary timeout (30 min) → auto-rollback | 30 min | Istio VirtualService reverted automatically |
| `kubectl rollout undo` (2 services) | ~45 sec each | Confirmed working in build #10 |
| Canary deployment deleted | < 5 sec | `--ignore-not-found` safe |

**Result:** Production traffic fully restored to v1 in under 2 minutes.

---

## 5. Post-Rollback Checklist

- [ ] Verify all pods are Running: `kubectl get pods -n circleguard-production`
- [ ] Confirm VirtualService weights: `kubectl get virtualservice -n circleguard-production`
- [ ] Check error rate in Grafana drops back to baseline
- [ ] Notify team in Slack: paste rollback reason + timing
- [ ] Open GitHub Issue to track root cause of failed release

---

## 6. Infrastructure Rollback (Terraform)

If a Terraform change broke the cluster:

```bash
cd terraform/envs/prod
git stash  # revert to last working config
terraform apply -auto-approve
```

Or to a specific Terraform state version:
```bash
terraform state list  # find resource
gsutil ls gs://circle-guard-tfstate-496702/envs/prod/  # find old state
```
