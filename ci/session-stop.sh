#!/usr/bin/env bash
# ci/session-stop.sh — Detiene recursos GCP entre sesiones de trabajo
# Uso: ./ci/session-stop.sh
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

# ── Helpers ────────────────────────────────────────────────────────────────────
log()  { echo -e "${CYAN}[stop]${RESET} $*"; }
ok()   { echo -e "${GREEN}  ✔${RESET}  $*"; }
warn() { echo -e "${YELLOW}  ⚠${RESET}  $*"; }
die()  { echo -e "${RED}[error]${RESET} $*" >&2; exit 1; }
hr()   { echo -e "${CYAN}──────────────────────────────────────────────${RESET}"; }

# ── 1. Prereqs ─────────────────────────────────────────────────────────────────
gcloud config set project "$PROJECT" --quiet 2>/dev/null
ACCOUNT=$(gcloud auth list --filter="status=ACTIVE" --format="value(account)" 2>/dev/null | head -1)
[[ -z "$ACCOUNT" ]] && die "No hay cuenta gcloud activa. Corre: gcloud auth login"

hr
echo -e "${BOLD}  CircleGuard — Fin de sesión${RESET}"
echo -e "  Cuenta: ${CYAN}$ACCOUNT${RESET}  |  Proyecto: ${CYAN}$PROJECT${RESET}"
hr

# ── 2. Detectar clusters activos ───────────────────────────────────────────────
declare -A ACTIVE_NODES   # env → número de nodos actuales
declare -a ACTIVE_ENVS    # envs que tienen cluster creado

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
    ACTIVE_NODES[$ENV]="${NODES:-0}"
    ACTIVE_ENVS+=("$ENV")
  fi
done

if [[ ${#ACTIVE_ENVS[@]} -eq 0 ]]; then
  warn "No se encontraron clusters GKE en el proyecto."
  warn "Cuando completes la Phase 1 (Terraform) y crees los clusters,"
  warn "este script los gestionará automáticamente."
  exit 0
fi

# ── 3. Mostrar estado actual ───────────────────────────────────────────────────
echo ""
log "Clusters encontrados:"
TOTAL_NODES=0
for ENV in "${ACTIVE_ENVS[@]}"; do
  N="${ACTIVE_NODES[$ENV]}"
  TOTAL_NODES=$(( TOTAL_NODES + N ))
  if [[ "$N" -eq 0 ]]; then
    echo -e "    ${YELLOW}●${RESET} circleguard-${ENV}  →  0 nodos (ya pausado)"
  else
    echo -e "    ${GREEN}●${RESET} circleguard-${ENV}  →  ${N} nodo(s) activo(s)"
  fi
done

# Costo estimado si todo sigue corriendo
CP_COST=$(echo "${#ACTIVE_ENVS[@]} * 0.10" | bc)
NODE_COST=$(echo "$TOTAL_NODES * 0.067" | bc)
TOTAL_HOURLY=$(echo "$CP_COST + $NODE_COST" | bc)

echo ""
echo -e "  Costo estimado actual: ${RED}${BOLD}\$${TOTAL_HOURLY}/hora${RESET}"
echo -e "  (control planes: \$${CP_COST}/h  |  nodos: \$${NODE_COST}/h)"

# Si ya todos tienen 0 nodos, no hay nada que hacer
ALL_ZERO=true
for ENV in "${ACTIVE_ENVS[@]}"; do
  [[ "${ACTIVE_NODES[$ENV]}" -gt 0 ]] && ALL_ZERO=false
done

if $ALL_ZERO; then
  echo ""
  ok "Todos los nodos ya están en 0. Control planes activos: \$${CP_COST}/h"
  echo ""
  echo -e "  ¿Quieres destruir los clusters completamente (terraform destroy)?"
  echo -e "  Ahorra \$${CP_COST}/h pero tarda ~5 min en recrear."
  read -rp "  Destruir clusters? [s/N]: " DESTROY_CHOICE
  if [[ "${DESTROY_CHOICE,,}" == "s" ]]; then
    _do_destroy=true
  else
    ok "OK, nodos en 0 y clusters en pie. Hasta luego."
    exit 0
  fi
fi

# ── 4. Preguntar tiempo de ausencia ───────────────────────────────────────────
if [[ -z "${_do_destroy:-}" ]]; then
  echo ""
  echo -e "  ${BOLD}¿Cuántas horas estarás fuera?${RESET}"
  read -rp "  Horas (ej: 1.5 / 4 / 8 / 16): " HOURS

  # Validar que sea un número
  [[ "$HOURS" =~ ^[0-9]+(\.[0-9]+)?$ ]] || die "Ingresa un número válido."

  COST_SCALE_ONLY=$(echo "scale=2; $CP_COST * $HOURS" | bc)
  COST_SCALE_NODES=$(echo "scale=2; $TOTAL_HOURLY * $HOURS" | bc)

  echo ""
  if (( $(echo "$HOURS < 4" | bc -l) )); then
    # Pausa corta — escalar nodos a 0 es suficiente
    echo -e "  ${GREEN}Pausa corta (<4h)${RESET} — te recomiendo escalar nodos a 0."
    echo -e "  Ahorro: ${GREEN}\$$(echo "scale=2; $NODE_COST * $HOURS" | bc)${RESET}"
    echo -e "  Costo control planes mientras estás fuera: ${YELLOW}\$${COST_SCALE_ONLY}${RESET}"
    STRATEGY="scale"
  elif (( $(echo "$HOURS < 8" | bc -l) )); then
    # Rango medio — escalar es razonable, destroy es opcional
    echo -e "  ${YELLOW}Ausencia media (4-8h)${RESET} — opciones:"
    echo -e "    A) Escalar a 0  → costo control planes: ${YELLOW}\$${COST_SCALE_ONLY}${RESET}"
    echo -e "    B) Terraform destroy → costo: ${GREEN}\$0.00${RESET} (recrear tarda ~5 min)"
    read -rp "  Elige [A/b]: " MID_CHOICE
    [[ "${MID_CHOICE,,}" == "b" ]] && STRATEGY="destroy" || STRATEGY="scale"
  else
    # Ausencia larga — destroy es lo recomendado
    echo -e "  ${RED}Ausencia larga (>8h)${RESET} — te recomiendo terraform destroy."
    echo -e "  Si solo escalas, pagarías: ${RED}\$${COST_SCALE_ONLY}${RESET} en control planes."
    echo -e "  Con destroy: ${GREEN}\$0.00${RESET} (recrear tarda ~5 min al volver)."
    read -rp "  ¿Terraform destroy? [S/n]: " LONG_CHOICE
    [[ "${LONG_CHOICE,,}" == "n" ]] && STRATEGY="scale" || STRATEGY="destroy"
  fi
fi

# Aplicar _do_destroy si viene del bloque de "ya en 0"
[[ "${_do_destroy:-}" == "true" ]] && STRATEGY="destroy"

# ── 5. Ejecutar estrategia ─────────────────────────────────────────────────────
hr
echo ""

_scale_to_zero() {
  local ENV="$1"
  local CLUSTER="circleguard-${ENV}"
  local NODES="${ACTIVE_NODES[$ENV]}"

  if [[ "$NODES" -eq 0 ]]; then
    ok "${CLUSTER}: ya tiene 0 nodos, sin cambios."
    return
  fi

  log "Escalando ${CLUSTER} a 0 nodos..."
  gcloud container clusters resize "$CLUSTER" \
    --node-pool="$NODE_POOL" \
    --num-nodes=0 \
    --region="$REGION" \
    --project="$PROJECT" \
    --quiet 2>&1 | grep -v "^$" || true
  ok "${CLUSTER}: nodos → 0  (cluster conservado)"
}

_terraform_destroy() {
  local ENV="$1"
  local TF_DIR="${REPO_ROOT}/terraform/envs/${ENV}"

  if [[ ! -d "$TF_DIR" ]]; then
    warn "No existe ${TF_DIR}. Saltando destroy para ${ENV}."
    return
  fi

  log "Destruyendo infra ${ENV} con Terraform..."
  (cd "$TF_DIR" && terraform destroy -auto-approve 2>&1 | tail -5)
  ok "circleguard-${ENV}: destruido completamente."
}

if [[ "$STRATEGY" == "scale" ]]; then
  log "Estrategia: escalar nodos a 0"
  echo ""
  for ENV in "${ACTIVE_ENVS[@]}"; do
    _scale_to_zero "$ENV"
  done
else
  log "Estrategia: terraform destroy"
  echo ""
  for ENV in "${ACTIVE_ENVS[@]}"; do
    _terraform_destroy "$ENV"
  done
fi

# ── 6. Guardar timestamp ───────────────────────────────────────────────────────
STOP_FILE="${REPO_ROOT}/.session-state"
cat > "$STOP_FILE" <<EOF
STOPPED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
STRATEGY=${STRATEGY}
ACTIVE_ENVS=${ACTIVE_ENVS[*]:-}
HOURS_AWAY=${HOURS:-?}
EOF

# ── 7. Resumen final ───────────────────────────────────────────────────────────
hr
echo ""
if [[ "$STRATEGY" == "scale" ]]; then
  SAVED=$(echo "scale=2; $NODE_COST * ${HOURS:-1}" | bc)
  ok "Nodos a 0. Ahorro estimado: \$${SAVED} en VMs."
  warn "Control planes activos: \$${CP_COST}/h mientras el cluster exista."
  echo ""
  echo -e "  Para reanudar: ${CYAN}./ci/session-start.sh${RESET}"
else
  ok "Clusters destruidos. Costo: \$0.00/h hasta que vuelvas."
  echo ""
  echo -e "  Para reanudar: ${CYAN}./ci/session-start.sh${RESET}  (~5 min de recreación)"
fi
echo ""
