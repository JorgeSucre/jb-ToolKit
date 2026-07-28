#!/bin/bash

set -Euo pipefail
START_TIME=$(date +%s)


BASE_DIR="${BASE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$BASE_DIR/core/utils.sh"
# Session is owned by the jb launcher.
# Only initialize a fallback session when run standalone (outside jb).


init_session


source "$BASE_DIR/core/bootstrap/ui.sh"
set_ui_context "Maintenance"

source "$BASE_DIR/core/maintenance/cleanup.sh"
source "$BASE_DIR/core/maintenance/apps.sh"
source "$BASE_DIR/core/maintenance/performance.sh"
source "$BASE_DIR/core/maintenance/state.sh"
source "$BASE_DIR/core/maintenance/storage.sh"

# Storage Platform service (shared library — see docs/Storage-Architecture.md
# and docs/architecture/0002-storage-platform.md). Only api.sh's storage::*
# functions and run_storage_management are meant to be called from here on;
# everything else is the service's own internals.
source "$BASE_DIR/core/platform/storage/volume.sh"
source "$BASE_DIR/core/platform/storage/plan.sh"
source "$BASE_DIR/core/platform/storage/transaction.sh"
source "$BASE_DIR/core/platform/storage/engine.sh"
source "$BASE_DIR/core/platform/storage/api.sh"
load_storage_profiles


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


SWAP_USAGE=$(sysctl vm.swapusage 2>/dev/null || true)

if echo "$SWAP_USAGE" | grep -qi "used = [1-9]"; then
    warn "⚠️ Uso de memoria virtual detectado"
else
    success "✔ Sin presión importante de memoria virtual"
fi


session_write INFO "Running cleanup.sh"
if ! run_cleanup_tasks; then
    warn "⚠️ Algunas tareas de limpieza fallaron"
fi

if [[ "${MAINTENANCE_SKIPPED:-false}" == "true" ]]; then

    echo ""
    info "ℹ️ No se realizaron cambios en el sistema"

    print_elapsed_time "$(( $(date +%s) - START_TIME ))"

    print_completion "true"

    exit 0
fi

session_write INFO "Running storage.sh"
run_storage_analysis

session_write INFO "Running storage::run_profile"
storage::run_profile

session_write INFO "Running apps.sh"
run_apps_cleanup

session_write INFO "Running performance.sh"
run_performance_optimization

session_write INFO "Updating maintenance state"
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
