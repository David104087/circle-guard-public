#!/usr/bin/env bash
# ci/session-stop.sh — Detiene recursos GCP entre sesiones de trabajo
# Uso: ./ci/session-stop.sh
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

PROJECT="tallerfinal-496702"
REGION="us-central1"
NODE_POOL="default-pool"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALL_ENVS=("dev" "stage" "prod")

log()  { echo -e "${CYAN}[stop]${RESET} $*"; }
ok()   { echo -e "${GREEN}  ✔${RESET}  $*"; }
warn() { echo -e "${YELLOW}  ⚠${RESET}  $*"; }
die()  { echo -e "${RED}[error]${RESET} $*" >&2; exit 1; }
hr()   { echo -e "${CYAN}──────────────────────────────────────────────${RESET}"; }

gcloud config set project "$PROJECT" --quiet 2>/dev/null
ACCOUNT=$(gcloud auth list --filter="status=ACTIVE" --format="value(account)" 2>/dev/null | head -1)
[[ -z "$ACCOUNT" ]] && die "No hay cuenta gcloud activa. Corre: gcloud auth login"

hr
echo -e "${BOLD}  CircleGuard — Fin de sesión${RESET}"
echo -e "  Cuenta: ${CYAN}$ACCOUNT${RESET}  |  Proyecto: ${CYAN}$PROJECT${RESET}"
hr

# Detectar clusters activos usando arrays paralelos (compatible bash 3.x)
ACTIVE_ENVS=()
ACTIVE_NODE_COUNTS=()

for ENV in "${ALL_ENVS[@]}"; do
  CLUSTER="circleguard-${ENV}"
  EXISTS=$(gcloud container clusters list \
    --project="$PROJECT" \
    --filter="name=${CLUSTER}" \
    --format="value(name)" 2>/dev/null)

  if [[ -n "$EXISTS" ]]; then
    NODES=$(gcloud container clusters describe "$CLUSTER" \
      --region="$REGION" --project="$PROJECT" \
      --format="value(currentNodeCount)" 2>/dev/null || echo "0")
    ACTIVE_ENVS+=("$ENV")
    ACTIVE_NODE_COUNTS+=("${NODES:-0}")
  fi
done

if [[ ${#ACTIVE_ENVS[@]} -eq 0 ]]; then
  warn "No se encontraron clusters GKE. Nada que apagar."
  warn "Los clusters se crean en Phase 1 (Terraform)."
  exit 0
fi

echo ""
log "Clusters encontrados:"
TOTAL_NODES=0
for i in "${!ACTIVE_ENVS[@]}"; do
  ENV="${ACTIVE_ENVS[$i]}"
  N="${ACTIVE_NODE_COUNTS[$i]}"
  TOTAL_NODES=$(( TOTAL_NODES + N ))
  if [[ "$N" -eq 0 ]]; then
    echo -e "    ${YELLOW}●${RESET} circleguard-${ENV}  →  0 nodos (ya pausado)"
  else
    echo -e "    ${GREEN}●${RESET} circleguard-${ENV}  →  ${N} nodo(s) activo(s)"
  fi
done

CP_COUNT=${#ACTIVE_ENVS[@]}
CP_COST=$(echo "$CP_COUNT * 0.10" | bc)
NODE_COST=$(echo "scale=3; $TOTAL_NODES * 0.067" | bc)
TOTAL_HOURLY=$(echo "scale=3; $CP_COST + $NODE_COST" | bc)

echo ""
echo -e "  Costo estimado actual: ${RED}${BOLD}\$${TOTAL_HOURLY}/hora${RESET}"
echo -e "  (control planes: \$${CP_COST}/h  |  nodos: \$${NODE_COST}/h)"

# Si todos ya tienen 0 nodos
ALL_ZERO=true
for N in "${ACTIVE_NODE_COUNTS[@]}"; do
  [[ "$N" -gt 0 ]] && ALL_ZERO=false
done

STRATEGY=""
HOURS="0"

if $ALL_ZERO; then
  echo ""
  echo -e "  Todos los nodos ya están en 0."
  echo -e "  ¿Destruir los clusters completamente? Ahorra \$${CP_COST}/h, recrear tarda ~5 min."
  read -rp "  ¿Terraform destroy? [s/N]: " DC
  case "$DC" in s|S) STRATEGY="destroy" ;; *) ok "OK, hasta luego."; exit 0 ;; esac
else
  echo ""
  echo -e "  ${BOLD}¿Cuántas horas estarás fuera?${RESET}"
  read -rp "  Horas (ej: 1 / 4 / 8 / 16): " HOURS
  [[ "$HOURS" =~ ^[0-9]+(\.[0-9]+)?$ ]] || die "Ingresa un número válido."

  COST_CP_ONLY=$(echo "scale=2; $CP_COST * $HOURS" | bc)

  echo ""
  if (( $(echo "$HOURS < 4" | bc -l) )); then
    echo -e "  ${GREEN}Pausa corta (<4h)${RESET} — escalo nodos a 0."
    echo -e "  Ahorro en VMs: ${GREEN}\$$(echo "scale=2; $NODE_COST * $HOURS" | bc)${RESET}"
    echo -e "  Control planes mientras estás fuera: ${YELLOW}\$${COST_CP_ONLY}${RESET}"
    STRATEGY="scale"
  elif (( $(echo "$HOURS < 8" | bc -l) )); then
    echo -e "  ${YELLOW}Ausencia media (4-8h)${RESET} — ¿qué prefieres?"
    echo -e "    A) Escalar a 0  → control planes: ${YELLOW}\$${COST_CP_ONLY}${RESET}"
    echo -e "    B) Terraform destroy → ${GREEN}\$0.00${RESET} (recrear ~5 min)"
    read -rp "  [A/b]: " MC
    case "$MC" in b|B) STRATEGY="destroy" ;; *) STRATEGY="scale" ;; esac
  else
    echo -e "  ${RED}Ausencia larga (>8h)${RESET} — recomiendo terraform destroy."
    echo -e "  Si solo escalas pagarías: ${RED}\$${COST_CP_ONLY}${RESET} en control planes."
    read -rp "  ¿Terraform destroy? [S/n]: " LC
    case "$LC" in n|N) STRATEGY="scale" ;; *) STRATEGY="destroy" ;; esac
  fi
fi

hr
echo ""

_scale_to_zero() {
  local ENV="$1" NODES="$2"
  local CLUSTER="circleguard-${ENV}"
  if [[ "$NODES" -eq 0 ]]; then
    ok "${CLUSTER}: ya tiene 0 nodos."
    return
  fi
  log "Escalando ${CLUSTER} a 0 nodos..."
  gcloud container clusters resize "$CLUSTER" \
    --node-pool="$NODE_POOL" --num-nodes=0 \
    --region="$REGION" --project="$PROJECT" --quiet 2>&1 | grep -v "^$" || true
  ok "${CLUSTER}: nodos → 0"
}

_terraform_destroy() {
  local ENV="$1"
  local TF_DIR="${REPO_ROOT}/terraform/envs/${ENV}"
  if [[ ! -d "$TF_DIR" ]]; then
    warn "No existe ${TF_DIR}. Usando scale-to-0 en su lugar."
    return 1
  fi
  log "Destruyendo infra ${ENV} con Terraform..."
  (cd "$TF_DIR" && terraform destroy -auto-approve 2>&1 | tail -5)
  ok "circleguard-${ENV}: destruido."
}

for i in "${!ACTIVE_ENVS[@]}"; do
  ENV="${ACTIVE_ENVS[$i]}"
  N="${ACTIVE_NODE_COUNTS[$i]}"
  if [[ "$STRATEGY" == "destroy" ]]; then
    _terraform_destroy "$ENV" || _scale_to_zero "$ENV" "$N"
  else
    _scale_to_zero "$ENV" "$N"
  fi
done

# Guardar estado
cat > "${REPO_ROOT}/.session-state" <<EOF
STOPPED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
STRATEGY=${STRATEGY}
HOURS_AWAY=${HOURS}
EOF

hr
echo ""
if [[ "$STRATEGY" == "scale" ]]; then
  SAVED=$(echo "scale=2; $NODE_COST * $HOURS" | bc)
  ok "Nodos a 0. Ahorro estimado en VMs: \$${SAVED}"
  warn "Control planes siguen: \$${CP_COST}/h"
else
  ok "Clusters destruidos. Costo: \$0.00/h"
fi
echo ""
echo -e "  Para reanudar: ${CYAN}./ci/session-start.sh${RESET}"
echo ""
