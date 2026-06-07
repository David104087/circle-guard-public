#!/bin/bash
# CircleGuard session start — run this at the beginning of each work session.
# Starts Jenkins, SonarQube, and scales up the dev GKE cluster.
set -e

PROJECT="tallerfinal-496702"
REGION="us-central1"
DEV_CLUSTER="circleguard-dev"

echo "==> Starting Jenkins..."
docker start circleguard-jenkins
docker exec --user root circleguard-jenkins chmod 666 /var/run/docker.sock
echo "    Jenkins ready at http://localhost:8080"

echo "==> Starting SonarQube..."
docker start sonarqube
echo "    SonarQube ready at http://localhost:9000 (may take ~60s to initialize)"

echo "==> Scaling up dev cluster (1 node/zone)..."
gcloud container clusters resize "$DEV_CLUSTER" \
  --node-pool=default-pool \
  --num-nodes=1 \
  --region="$REGION" \
  --project="$PROJECT" \
  --quiet
echo "    Cluster $DEV_CLUSTER scaled to 1 node/zone"

echo ""
echo "==> Session ready. Quota note: CPUS_ALL_REGIONS=12."
echo "    Only scale stage/prod if dev is at 0 nodes first."
echo "    Run: ci/session-stop.sh when done."
