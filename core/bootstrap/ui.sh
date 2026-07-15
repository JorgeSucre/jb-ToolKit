

#!/bin/bash

# =========================
# UI helpers
# =========================

# Colors are inherited from core/utils.sh

# =========================
# Sections
# =========================

print_section() {

    echo ""
    echo "$1"
    echo "----------------------------------------"
}

# =========================
# Status messages
# =========================

success() {
    printf "${GREEN}%s${NC}\n" "$1"
    session_write SUCCESS "$1"
}

warn() {
    printf "${YELLOW}%s${NC}\n" "$1"
    session_write WARNING "$1"
}

error_msg() {
    printf "${RED}%s${NC}\n" "$1"
    session_write ERROR "$1"
}

error() {
    error_msg "$1"
}

info() {
    printf "${BLUE}%s${NC}\n" "$1"
    session_write INFO "$1"
}

# =========================
# Headers
# =========================

UI_CONTEXT="${UI_CONTEXT:-Setup}"

set_ui_context() {

    local context="$1"

    [[ -z "$context" ]] && return 0

    UI_CONTEXT="$context"
    set_session_module "$context"
}

print_banner() {

    echo ""
    echo "========================================"
    printf "   🍺 JB Toolkit %s v%s\n" "$UI_CONTEXT" "$JB_VERSION"
    echo "========================================"
}

print_completion() {

    local success_state="${1:-true}"

    echo ""
    echo "========================================"

    if [[ "$success_state" == "true" ]]; then
        success "✔ ${UI_CONTEXT} completado correctamente"
    else
        warn "⚠️ ${UI_CONTEXT} finalizado con advertencias"
    fi

    echo "========================================"
}

print_cancelled() {

    echo ""
    echo "========================================"

    info "ℹ️ ${UI_CONTEXT} omitido por el usuario"

    echo "========================================"
}

# =========================
# Prompts
# =========================

ask_yes_no() {

    local prompt="$1"
    local response

    printf "%s (y/n): " "$prompt"

    read -r response

    [[ "$response" =~ ^[YySs]$ ]]
}

# =========================
# Elapsed time
# =========================

print_elapsed_time() {

    local elapsed="$1"

    if [[ "$elapsed" -ge 60 ]]; then

        printf "⏱️ Tiempo total: %sm %ss\n" \
            "$((elapsed / 60))" \
            "$((elapsed % 60))"

    else

        printf "⏱️ Tiempo total: %s segundos\n" "$elapsed"
    fi
}
