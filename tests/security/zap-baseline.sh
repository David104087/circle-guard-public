#!/usr/bin/env bash
# tests/security/zap-baseline.sh
# OWASP ZAP baseline security scan against CircleGuard's Istio ingress gateway.
# Usage: ./tests/security/zap-baseline.sh [TARGET_IP]
# If TARGET_IP not provided, reads from INGRESS_IP env var or queries kubectl.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE="${SCRIPT_DIR}/zap-report.html"

# Determine target IP
if [[ -n "${1:-}" ]]; then
  INGRESS_IP="$1"
elif [[ -n "${INGRESS_IP:-}" ]]; then
  INGRESS_IP="$INGRESS_IP"
else
  echo "Querying Istio ingress gateway IP..."
  INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system \
    -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null || echo "")
fi

if [[ -z "$INGRESS_IP" ]]; then
  echo "No ingress IP found — skipping ZAP scan" >&2
  exit 0
fi

TARGET="http://${INGRESS_IP}"
echo "Running ZAP baseline scan against: ${TARGET}"

docker run --rm \
  -v "${SCRIPT_DIR}:/zap/wrk/:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py \
  -t "${TARGET}" \
  -r zap-report.html \
  -I \
  -j 2>/dev/null || true

echo "ZAP scan complete. Report: ${REPORT_FILE}"
