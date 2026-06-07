#!/bin/bash
# CircleGuard session stop — run this at the end of each work session.
# Scales all GKE clusters to 0 nodes to avoid charges, then stops Jenkins and SonarQube.
#
# Usage:
#   ci/session-stop.sh          # scale to 0 (clusters survive, control plane billed at ~$0.10/h each)
#   ci/session-stop.sh destroy  # terraform destroy all envs (no control plane cost, ~5min to recreate)

set -e

PROJECT="tallerfinal-496702"
REGION="us-central1"
MODE="${1:-scale}"

CLUSTERS="circleguard-dev circleguard-stage circleguard-prod"

echo "==> Scaling all GKE clusters to 0 nodes (parallel)..."
PIDS=""
for CLUSTER in $CLUSTERS; do
  (gcloud container clusters resize "$CLUSTER" \
    --node-pool=default-pool \
    --num-nodes=0 \
    --region="$REGION" \
    --project="$PROJECT" \
    --quiet 2>&1 | sed "s/^/[$CLUSTER] /" || echo "[$CLUSTER] skipped (cluster may not exist)") &
  PIDS="$PIDS $!"
done
for PID in $PIDS; do wait "$PID" || true; done
echo "    All clusters at 0 nodes."

if [ "$MODE" = "destroy" ]; then
  echo "==> Destroying Terraform envs (overnight mode)..."
  for ENV in dev stage prod; do
    DIR="terraform/envs/$ENV"
    if [ -d "$DIR" ]; then
      echo "  Destroying $ENV..."
      (cd "$DIR" && terraform destroy -auto-approve -compact-warnings 2>&1 | tail -5)
    fi
  done
  echo "    All envs destroyed. No control plane charges while sleeping."
fi

echo "==> Stopping Jenkins and SonarQube..."
docker stop circleguard-jenkins sonarqube 2>/dev/null || true
echo "    Done."

echo ""
echo "==> Session stopped."
if [ "$MODE" = "destroy" ]; then
  echo "    Recreate tomorrow with: terraform apply -auto-approve in each env, then ci/session-start.sh"
else
  echo "    Resume tomorrow with: ci/session-start.sh"
fi
