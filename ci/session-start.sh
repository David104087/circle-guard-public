#!/usr/bin/env bash
# ci/session-start.sh — Arranca recursos GCP al inicio de una sesión de trabajo
# Uso: ./ci/session-start.sh [--env dev] [--env stage] [--env prod]
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

PROJECT="tallerfinal-496702"
REGION="us-central1"
NODE_POOL="default-pool"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log()  { echo -e "${CYAN}[start]${RESET} $*"; }
ok()   { echo -e "${GREEN}  ✔${RESET}  $*"; }
warn() { echo -e "${YELLOW}  ⚠${RESET}  $*"; }
step() { echo -e "\n${BOLD}▶ $*${RESET}"; }
die()  { echo -e "${RED}[error]${RESET} $*" >&2; exit 1; }
hr()   { echo -e "${CYAN}──────────────────────────────────────────────${RESET}"; }

# Nodos objetivo por entorno (sin arrays asociativos — compatible bash 3.x)
_target_nodes() {
  case "$1" in
    dev)   echo 2 ;;
    stage) echo 2 ;;
    prod)  echo 3 ;;
    *)     echo 2 ;;
  esac
}

gcloud config set project "$PROJECT" --quiet 2>/dev/null
ACCOUNT=$(gcloud auth list --filter="status=ACTIVE" --format="value(account)" 2>/dev/null | head -1)
[[ -z "$ACCOUNT" ]] && die "No hay cuenta gcloud activa. Corre: gcloud auth login"

hr
echo -e "${BOLD}  CircleGuard — Inicio de sesión${RESET}"
echo -e "  Cuenta: ${CYAN}$ACCOUNT${RESET}  |  Proyecto: ${CYAN}$PROJECT${RESET}"
hr

# Leer estado de sesión anterior
STOP_FILE="${REPO_ROOT}/.session-state"
if [[ -f "$STOP_FILE" ]]; then
  source "$STOP_FILE"
  echo ""
  log "Última parada: ${STOPPED_AT:-desconocida} | Estrategia: ${STRATEGY:-?} | Horas fuera: ${HOURS_AWAY:-?}"
fi

# Seleccionar entornos
REQUESTED_ENVS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) REQUESTED_ENVS+=("$2"); shift 2 ;;
    *) die "Flag desconocido: $1" ;;
  esac
done

if [[ ${#REQUESTED_ENVS[@]} -eq 0 ]]; then
  echo ""
  step "¿Qué entornos necesitas hoy?"
  echo ""
  echo -e "    ${BOLD}1)${RESET} Solo dev     ${YELLOW}← recomendado para desarrollo${RESET}"
  echo -e "    ${BOLD}2)${RESET} dev + stage  (para probar pipeline stage)"
  echo -e "    ${BOLD}3)${RESET} Todos        (dev + stage + prod — solo para demo final)"
  echo -e "    ${BOLD}4)${RESET} Personalizado"
  echo ""
  read -rp "  Elige [1/2/3/4]: " ENV_CHOICE
  case "$ENV_CHOICE" in
    1) REQUESTED_ENVS=("dev") ;;
    2) REQUESTED_ENVS=("dev" "stage") ;;
    3) REQUESTED_ENVS=("dev" "stage" "prod") ;;
    4)
      echo ""
      read -rp "  Entornos (ej: dev stage): " -a REQUESTED_ENVS
      ;;
    *) die "Opción inválida." ;;
  esac
fi

echo ""
log "Entornos a levantar: ${REQUESTED_ENVS[*]}"

KUBECONFIG_PARTS=()

for ENV in "${REQUESTED_ENVS[@]}"; do
  CLUSTER="circleguard-${ENV}"
  TF_DIR="${REPO_ROOT}/terraform/envs/${ENV}"
  TARGET=$(_target_nodes "$ENV")
  step "Procesando: ${ENV}"

  EXISTS=$(gcloud container clusters list \
    --project="$PROJECT" \
    --filter="name=${CLUSTER}" \
    --format="value(name)" 2>/dev/null || echo "")

  if [[ -n "$EXISTS" ]]; then
    CURRENT=$(gcloud container clusters describe "$CLUSTER" \
      --region="$REGION" --project="$PROJECT" \
      --format="value(currentNodeCount)" 2>/dev/null || echo "0")

    if [[ "$CURRENT" -eq 0 ]]; then
      log "${CLUSTER}: escalando 0 → ${TARGET} nodo(s)..."
      gcloud container clusters resize "$CLUSTER" \
        --node-pool="$NODE_POOL" --num-nodes="$TARGET" \
        --region="$REGION" --project="$PROJECT" --quiet 2>&1 | grep -v "^$" || true
      ok "${CLUSTER}: ${TARGET} nodo(s) activos"
    else
      ok "${CLUSTER}: ya tiene ${CURRENT} nodo(s) corriendo"
    fi
  else
    if [[ -d "$TF_DIR" ]]; then
      log "${CLUSTER}: no existe. Aplicando Terraform..."
      (cd "$TF_DIR" && terraform init -input=false -reconfigure 2>&1 | tail -3)
      (cd "$TF_DIR" && terraform apply -auto-approve 2>&1 | tail -10)
      ok "${CLUSTER}: creado via Terraform"
    else
      warn "${CLUSTER}: cluster no existe y tampoco ${TF_DIR}."
      warn "Completa Phase 1 (Terraform) primero."
      continue
    fi
  fi

  # Actualizar kubeconfig
  KUBECONFIG_PATH="${HOME}/.kube/circleguard-${ENV}"
  log "Actualizando kubeconfig → ${KUBECONFIG_PATH}"
  KUBECONFIG="$KUBECONFIG_PATH" gcloud container clusters get-credentials "$CLUSTER" \
    --region="$REGION" --project="$PROJECT" --quiet 2>/dev/null
  ok "kubeconfig listo"
  KUBECONFIG_PARTS+=("$KUBECONFIG_PATH")

  # Esperar nodos Ready
  log "Esperando nodos Ready..."
  KUBECONFIG="$KUBECONFIG_PATH" kubectl wait node \
    --for=condition=Ready --all --timeout=180s 2>/dev/null \
    && ok "Todos los nodos Ready" \
    || warn "Timeout — los nodos pueden seguir iniciando"

  # Estado de pods
  NS="circleguard-${ENV}"
  NOT_RUNNING=$(KUBECONFIG="$KUBECONFIG_PATH" kubectl get pods -n "$NS" \
    --no-headers 2>/dev/null | grep -v -E "Running|Completed" | wc -l | tr -d ' ' || echo "0")
  if [[ "$NOT_RUNNING" -gt 0 ]]; then
    warn "${NOT_RUNNING} pod(s) en estado no-Running en ${NS}"
    warn "  → KUBECONFIG=${KUBECONFIG_PATH} kubectl get pods -n ${NS}"
  else
    ok "Pods en ${NS}: OK"
  fi
done

# Exportar KUBECONFIG combinado
if [[ ${#KUBECONFIG_PARTS[@]} -gt 0 ]]; then
  COMBINED=$(IFS=:; echo "${KUBECONFIG_PARTS[*]}")
  echo "export KUBECONFIG=${COMBINED}" > "${REPO_ROOT}/.kubeconfig-session"
  echo ""
  ok "Para activar kubectl en tu terminal: ${CYAN}source .kubeconfig-session${RESET}"
fi

[[ -f "$STOP_FILE" ]] && rm -f "$STOP_FILE"

# Fix Docker socket permissions for Jenkins DooD
# The socket is mounted as root:root inside the container — jenkins user can't access it without this
if docker ps --filter name=circleguard-jenkins --filter status=running -q 2>/dev/null | grep -q .; then
  if docker exec --user root circleguard-jenkins chmod 666 /var/run/docker.sock 2>/dev/null; then
    ok "Jenkins Docker socket permissions fixed"
  fi
fi

# Resumen de costo
TOTAL_NODES=0
for ENV in "${REQUESTED_ENVS[@]}"; do
  TOTAL_NODES=$(( TOTAL_NODES + $(_target_nodes "$ENV") ))
done
CP=$(echo "${#REQUESTED_ENVS[@]} * 0.10" | bc)
VM=$(echo "scale=3; $TOTAL_NODES * 0.067" | bc)
TOTAL=$(echo "scale=3; $CP + $VM" | bc)

hr
echo ""
ok "Sesión lista. Entornos activos: ${REQUESTED_ENVS[*]}"
echo -e "  Costo estimado: ${YELLOW}\$${TOTAL}/hora${RESET}"
echo -e "  Al terminar: ${CYAN}./ci/session-stop.sh${RESET}"
echo ""
