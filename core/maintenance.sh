#!/bin/bash

set -Euo pipefail
START_TIME=$(date +%s)


BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/core/utils.sh"

source "$BASE_DIR/core/bootstrap/ui.sh"

source "$BASE_DIR/core/maintenance/cleanup.sh"
source "$BASE_DIR/core/maintenance/apps.sh"
source "$BASE_DIR/core/maintenance/performance.sh"
source "$BASE_DIR/core/maintenance/state.sh"
source "$BASE_DIR/core/maintenance/storage.sh"


print_banner




# =========================
# System State
# =========================
initialize_state

print_section "🧠 Estado del sistema"

SPOTLIGHT_STATUS=$(mdutil -s / 2>/dev/null || true)

if echo "$SPOTLIGHT_STATUS" | grep -qi "Indexing enabled"; then
    success "✔ Spotlight operativo"
fi

if echo "$SPOTLIGHT_STATUS" | grep -qi "Scanning"; then
    warn "🔎 Spotlight está reindexando el disco"
fi

SWAP_USAGE=$(sysctl vm.swapusage 2>/dev/null || true)

if echo "$SWAP_USAGE" | grep -qi "used = [1-9]"; then
    warn "⚠️ Uso de memoria virtual detectado"
else
    success "✔ Sin presión importante de memoria virtual"
fi


run_cleanup_tasks || exit 0

run_storage_analysis

run_apps_cleanup

run_performance_optimization

calculate_post_maintenance_score

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

save_maintenance_state

print_maintenance_summary

print_section "🛡️ Seguridad del mantenimiento"

success "• No se eliminaron aplicaciones automáticamente"
success "• No se alteraron archivos sincronizados en la nube"
success "• No se modificaron archivos del sistema"

print_elapsed_time "$ELAPSED"

print_completion "true"
