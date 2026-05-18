#!/usr/bin/env bash
# ci/session-start.sh — Arranca recursos GCP al inicio de una sesión de trabajo
# Uso: ./ci/session-start.sh [--env dev] [--env stage] [--env prod]
#      Sin flags: modo interactivo (recomendado)
set -euo pipefail

# ── Colores ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Config ─────────────────────────────────────────────────────────────────────
PROJECT="tallerfinal-496702"
REGION="us-central1"
NODE_POOL="default-pool"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALL_ENVS=("dev" "stage" "prod")

# Nodos por env (ajusta según la Phase 1 de Terraform)
declare -A TARGET_NODES=( [dev]=2 [stage]=2 [prod]=3 )

# ── Helpers ────────────────────────────────────────────────────────────────────
log()  { echo -e "${CYAN}[start]${RESET} $*"; }
ok()   { echo -e "${GREEN}  ✔${RESET}  $*"; }
warn() { echo -e "${YELLOW}  ⚠${RESET}  $*"; }
step() { echo -e "\n${BOLD}▶ $*${RESET}"; }
die()  { echo -e "${RED}[error]${RESET} $*" >&2; exit 1; }
hr()   { echo -e "${CYAN}──────────────────────────────────────────────${RESET}"; }

# ── 1. Autenticación ───────────────────────────────────────────────────────────
gcloud config set project "$PROJECT" --quiet 2>/dev/null
ACCOUNT=$(gcloud auth list --filter="status=ACTIVE" --format="value(account)" 2>/dev/null | head -1)
[[ -z "$ACCOUNT" ]] && die "No hay cuenta gcloud activa. Corre: gcloud auth login"

hr
echo -e "${BOLD}  CircleGuard — Inicio de sesión${RESET}"
echo -e "  Cuenta: ${CYAN}$ACCOUNT${RESET}  |  Proyecto: ${CYAN}$PROJECT${RESET}"
hr

# ── 2. Leer estado de la sesión anterior ──────────────────────────────────────
STOP_FILE="${REPO_ROOT}/.session-state"
if [[ -f "$STOP_FILE" ]]; then
  source "$STOP_FILE"
  echo ""
  log "Última parada: ${STOPPED_AT:-desconocida} | Estrategia usada: ${STRATEGY:-?}"
fi

# ── 3. Seleccionar entornos a levantar ─────────────────────────────────────────
REQUESTED_ENVS=()

# Parsear flags --env
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) REQUESTED_ENVS+=("$2"); shift 2 ;;
    *) die "Flag desconocido: $1. Uso: $0 [--env dev] [--env stage] [--env prod]" ;;
  esac
done

if [[ ${#REQUESTED_ENVS[@]} -eq 0 ]]; then
  # Modo interactivo
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
      echo -e "  Escribe los entornos separados por espacio (dev stage prod):"
      read -ra REQUESTED_ENVS
      ;;
    *) die "Opción inválida." ;;
  esac
fi

echo ""
log "Entornos a levantar: ${REQUESTED_ENVS[*]}"

# ── 4. Procesar cada entorno ───────────────────────────────────────────────────
KUBECONFIGS=()

for ENV in "${REQUESTED_ENVS[@]}"; do
  CLUSTER="circleguard-${ENV}"
  TF_DIR="${REPO_ROOT}/terraform/envs/${ENV}"
  step "Procesando entorno: ${ENV}"

  # ── 4a. ¿Existe el cluster? ──────────────────────────────────────────────────
  EXISTS=$(gcloud container clusters list \
    --project="$PROJECT" \
    --filter="name=${CLUSTER}" \
    --format="value(name)" 2>/dev/null || echo "")

  if [[ -n "$EXISTS" ]]; then
    # Cluster existe — verificar nodos actuales
    CURRENT_NODES=$(gcloud container clusters describe "$CLUSTER" \
      --region="$REGION" --project="$PROJECT" \
      --format="value(currentNodeCount)" 2>/dev/null || echo "0")
    TARGET="${TARGET_NODES[$ENV]}"

    if [[ "${CURRENT_NODES}" -eq 0 ]]; then
      log "${CLUSTER}: escalando de 0 → ${TARGET} nodo(s)..."
      gcloud container clusters resize "$CLUSTER" \
        --node-pool="$NODE_POOL" \
        --num-nodes="$TARGET" \
        --region="$REGION" \
        --project="$PROJECT" \
        --quiet 2>&1 | grep -v "^$" || true
      ok "${CLUSTER}: ${TARGET} nodo(s) activos"
    else
      ok "${CLUSTER}: ya tiene ${CURRENT_NODES} nodo(s) corriendo"
    fi

  else
    # Cluster no existe — necesitamos terraform apply
    if [[ -d "$TF_DIR" ]]; then
      log "${CLUSTER}: no existe. Aplicando Terraform en ${TF_DIR}..."
      (cd "$TF_DIR" && terraform init -input=false -reconfigure 2>&1 | tail -3)
      (cd "$TF_DIR" && terraform apply -auto-approve 2>&1 | tail -10)
      ok "${CLUSTER}: creado via Terraform"
    else
      warn "${CLUSTER}: cluster no existe y tampoco ${TF_DIR}."
      warn "Completa la Phase 1 (Terraform) primero."
      continue
    fi
  fi

  # ── 4b. Actualizar kubeconfig ─────────────────────────────────────────────────
  log "Actualizando kubeconfig para ${CLUSTER}..."
  KUBECONFIG_PATH="${HOME}/.kube/circleguard-${ENV}"
  KUBECONFIG="$KUBECONFIG_PATH" gcloud container clusters get-credentials "$CLUSTER" \
    --region="$REGION" --project="$PROJECT" --quiet 2>/dev/null
  ok "kubeconfig guardado en ${KUBECONFIG_PATH}"
  KUBECONFIGS+=("$KUBECONFIG_PATH")

  # ── 4c. Verificar nodos Ready ────────────────────────────────────────────────
  log "Esperando que los nodos estén Ready..."
  KUBECONFIG="$KUBECONFIG_PATH" kubectl wait node \
    --for=condition=Ready \
    --all \
    --timeout=180s 2>/dev/null && ok "Todos los nodos Ready" \
    || warn "Timeout esperando nodos — puede que aún estén iniciando"

  # ── 4d. Verificar pods de infraestructura ────────────────────────────────────
  NS="circleguard-${ENV}"
  POD_STATUS=$(KUBECONFIG="$KUBECONFIG_PATH" kubectl get pods -n "$NS" \
    --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l || echo "0")

  if [[ "$POD_STATUS" -gt 0 ]]; then
    warn "Hay pods en estado no-Running en ${NS}. Revisa con:"
    warn "  KUBECONFIG=${KUBECONFIG_PATH} kubectl get pods -n ${NS}"
  else
    ok "Pods en ${NS}: todos Running (o namespace aún vacío)"
  fi

done

# ── 5. Configurar KUBECONFIG combinado ────────────────────────────────────────
if [[ ${#KUBECONFIGS[@]} -gt 0 ]]; then
  step "Configurando KUBECONFIG"
  export KUBECONFIG="${KUBECONFIGS[0]}"
  for KC in "${KUBECONFIGS[@]:1}"; do
    export KUBECONFIG="${KUBECONFIG}:${KC}"
  done

  # Escribir variable a un archivo sourceable
  EXPORT_FILE="${REPO_ROOT}/.kubeconfig-session"
  echo "export KUBECONFIG=${KUBECONFIG}" > "$EXPORT_FILE"

  ok "KUBECONFIG listo. Para usarlo en tu terminal actual corre:"
  echo -e "    ${CYAN}source .kubeconfig-session${RESET}"
fi

# ── 6. Limpiar archivo de estado ──────────────────────────────────────────────
[[ -f "$STOP_FILE" ]] && rm -f "$STOP_FILE"

# ── 7. Resumen ────────────────────────────────────────────────────────────────
hr
echo ""
ok "Sesión lista. Entornos activos: ${REQUESTED_ENVS[*]}"
echo ""

# Estimar costo por hora
TOTAL_CP=$(echo "${#REQUESTED_ENVS[@]} * 0.10" | bc)
TOTAL_NODES=0
for ENV in "${REQUESTED_ENVS[@]}"; do
  TOTAL_NODES=$(( TOTAL_NODES + TARGET_NODES[$ENV] ))
done
TOTAL_NODE_COST=$(echo "scale=3; $TOTAL_NODES * 0.067" | bc)
TOTAL_HOURLY=$(echo "scale=3; $TOTAL_CP + $TOTAL_NODE_COST" | bc)

echo -e "  Costo estimado por hora: ${YELLOW}\$${TOTAL_HOURLY}${RESET}"
echo -e "  Al terminar la sesión corre: ${CYAN}./ci/session-stop.sh${RESET}"
echo ""
