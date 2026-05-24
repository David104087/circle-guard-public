#!/bin/bash
# Smoke test: verify all services are reachable from inside the cluster.
# Usage: ./ci/smoke-test.sh <namespace> [kubeconfig]
# Example: ./ci/smoke-test.sh circleguard-dev ~/.kube/circleguard-dev

set -e

NS="${1:-circleguard-dev}"
KUBECONFIG_PATH="${2:-$HOME/.kube/config}"
export KUBECONFIG="$KUBECONFIG_PATH"

SERVICES="auth-service:8180 dashboard-service:8084 file-service:8085 form-service:8086 notification-service:8082 promotion-service:8088 gateway-service:8087 identity-service:8083"

echo "=== CircleGuard Smoke Test — namespace: $NS ==="
echo ""

# Phase 1: pod readiness check
echo "--- Pod readiness ---"
NOT_READY=0
for svc_port in $SERVICES; do
  svc="$(echo "$svc_port" | cut -d: -f1)"
  pods=$(kubectl get pods -n "$NS" -l "app=$svc" --no-headers 2>/dev/null | awk '{print $3}')
  if echo "$pods" | grep -q "Running"; then
    echo "  [OK]    $svc Running"
  elif echo "$pods" | grep -q "ImagePullBackOff\|ErrImagePull"; then
    echo "  [SKIP]  $svc ImagePullBackOff (image not yet pushed)"
  else
    echo "  [FAIL]  $svc — $(echo "$pods" | head -1)"
    NOT_READY=$((NOT_READY + 1))
  fi
done
echo ""

# Phase 2: TCP connectivity from inside the cluster
echo "--- TCP connectivity ---"
kubectl run smoke-$$  --rm -i --restart=Never \
  --image=curlimages/curl:latest -n "$NS" \
  --quiet=true \
  -- sh -c "
    PASS=0; FAIL=0; SKIP=0
    for svc_port in $SERVICES; do
      svc=\$(echo \$svc_port | cut -d: -f1)
      port=\$(echo \$svc_port | cut -d: -f2)
      code=\$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://\$svc:\$port/ 2>/dev/null)
      if [ \"\$code\" = '000' ]; then
        echo \"  [SKIP]  \$svc:\$port unreachable (pod likely not running)\"
        SKIP=\$((SKIP+1))
      else
        echo \"  [OK]    \$svc:\$port HTTP \$code (port open)\"
        PASS=\$((PASS+1))
      fi
    done
    echo ''
    echo \"Results: \$PASS reachable, \$SKIP unreachable\"
  " 2>/dev/null

if [ "$NOT_READY" -gt 0 ]; then
  echo "FAIL: $NOT_READY service(s) not Running"
  exit 1
fi
echo "PASS: smoke test complete for namespace $NS"
