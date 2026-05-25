

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
}

warn() {
    printf "${YELLOW}%s${NC}\n" "$1"
}

error_msg() {
    printf "${RED}%s${NC}\n" "$1"
}

info() {
    printf "${BLUE}%s${NC}\n" "$1"
}

# =========================
# Headers
# =========================

print_banner() {

    echo ""
    echo "========================================"
    echo "   🍺 JB Toolkit Setup v0.9"
    echo "========================================"
}

print_completion() {

    local success_state="${1:-true}"

    echo ""
    echo "========================================"

    if [[ "$success_state" == "true" ]]; then
        success "✔ Setup completado correctamente"
    else
        warn "⚠️ Setup completado parcialmente"
    fi

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