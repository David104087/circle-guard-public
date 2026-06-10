#!/bin/bash
# CircleGuard session stop — run this at the end of each work session.
# Scales all GKE clusters to 0 nodes (and DO clusters if active) to avoid charges,
# then stops Jenkins and SonarQube.
#
# Usage:
#   ci/session-stop.sh          # scale to 0 (clusters survive, control plane billed at ~$0.10/h each)
#   ci/session-stop.sh destroy  # terraform destroy all envs (no control plane cost, ~5min to recreate)

set -e

PROJECT="tallerfinal-496702"
REGION="us-central1"
MODE="${1:-scale}"

# ---------------------------------------------------------------------------
# GCP GKE clusters — scale to 0 nodes (parallel)
# ---------------------------------------------------------------------------
GCP_CLUSTERS="circleguard-dev circleguard-stage circleguard-prod"

echo "==> Scaling all GKE clusters to 0 nodes (parallel)..."
PIDS=""
for CLUSTER in $GCP_CLUSTERS; do
  (gcloud container clusters resize "$CLUSTER" \
    --node-pool=default-pool \
    --num-nodes=0 \
    --region="$REGION" \
    --project="$PROJECT" \
    --quiet 2>&1 | sed "s/^/[$CLUSTER] /" || echo "[$CLUSTER] skipped (cluster may not exist)") &
  PIDS="$PIDS $!"
done
for PID in $PIDS; do wait "$PID" || true; done
echo "    GCP clusters at 0 nodes."

# ---------------------------------------------------------------------------
# DigitalOcean DOKS clusters — scale to 0 nodes if clusters exist
# Requires: doctl authenticated (doctl auth init) and DO clusters provisioned.
# Skipped silently when clusters are destroyed (normal state between sessions).
# ---------------------------------------------------------------------------
if command -v doctl &>/dev/null; then
  echo "==> Checking DigitalOcean clusters..."
  DO_ENVS="do-dev do-stage do-prod"
  for DO_ENV in $DO_ENVS; do
    CLUSTER_NAME="circleguard-$DO_ENV"
    # Get cluster ID — empty if not found
    CLUSTER_ID=$(doctl kubernetes cluster list --no-header --format ID,Name 2>/dev/null \
      | grep "$CLUSTER_NAME" | awk '{print $1}' || true)
    if [ -n "$CLUSTER_ID" ]; then
      POOL_ID=$(doctl kubernetes cluster node-pool list "$CLUSTER_ID" \
        --no-header --format ID 2>/dev/null | head -1 || true)
      if [ -n "$POOL_ID" ]; then
        echo "  Scaling $CLUSTER_NAME to 0 nodes..."
        doctl kubernetes cluster node-pool update "$CLUSTER_ID" "$POOL_ID" \
          --count 0 2>&1 | sed "s/^/  [$CLUSTER_NAME] /" || true
      fi
    else
      echo "  [$CLUSTER_NAME] not found — skipped (already destroyed)"
    fi
  done
else
  echo "==> doctl not found — skipping DigitalOcean cluster scale-down"
fi

if [ "$MODE" = "destroy" ]; then
  echo "==> Destroying Terraform envs (overnight mode)..."
  for ENV in dev stage prod; do
    DIR="terraform/envs/$ENV"
    if [ -d "$DIR" ]; then
      echo "  Destroying $ENV..."
      (cd "$DIR" && terraform destroy -auto-approve -compact-warnings 2>&1 | tail -5)
    fi
  done
  echo "    All GCP envs destroyed. No control plane charges while sleeping."
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
