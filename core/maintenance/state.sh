#!/bin/bash

# =========================
# State helpers
# =========================

STATE_FILE="$BASE_DIR/logs/state.env"

# =========================
# State initialization
# =========================

initialize_state() {

    TOTAL_FREED_MB=0
    FILES_REMOVED=0
    PERFORMANCE_PROFILE="none"

    SCORE_BEFORE="N/A"
    SCORE_AFTER="N/A"

    if [[ -f "$STATE_FILE" ]]; then

        local previous_score

        previous_score=$(grep '^SCORE_BEFORE=' "$STATE_FILE" 2>/dev/null \
            | cut -d'=' -f2-)

        if [[ -n "$previous_score" ]]; then
            SCORE_BEFORE="$previous_score"
        fi
    fi
}

# =========================
# Score calculation
# =========================

calculate_post_maintenance_score() {

    local health_script="$BASE_DIR/core/health_score.sh"

    if [[ ! -f "$health_script" ]]; then
        SCORE_AFTER="$SCORE_BEFORE"
        return
    fi

    local score

    score=$(bash "$health_script" 2>/dev/null \
        | tail -1 \
        | tr -dc '0-9')

    if [[ -z "$score" ]]; then
        SCORE_AFTER="$SCORE_BEFORE"
    else
        SCORE_AFTER="$score"
    fi
}

# =========================
# State persistence
# =========================

save_maintenance_state() {

    mkdir -p "$BASE_DIR/logs" 2>/dev/null || true

    cat > "$STATE_FILE" <<EOF
SCORE_BEFORE=$SCORE_BEFORE
SCORE_AFTER=$SCORE_AFTER
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)
TOTAL_FREED_MB=$TOTAL_FREED_MB
FILES_REMOVED=$FILES_REMOVED
PERFORMANCE_PROFILE=$PERFORMANCE_PROFILE
LAST_MODULE=maintenance
LAST_DURATION=${ELAPSED:-0}
ARCH=$(uname -m)
JB_VERSION=0.9
EOF

    log "📁 Estado guardado correctamente"
}

# =========================
# Summary helpers
# =========================

print_maintenance_summary() {

    print_section "🧠 Resumen ejecutivo"

    if [[ "$TOTAL_FREED_MB" -ge 1000 ]]; then

        success "🟢 Optimización significativa completada"

        echo ""
        echo "• Se liberó una cantidad importante de almacenamiento"
        echo "• El sistema eliminó archivos temporales y residuos antiguos"

    elif [[ "$TOTAL_FREED_MB" -ge 200 ]]; then

        success "🟢 Estado saludable"

        echo ""
        echo "• Se optimizó el sistema eliminando archivos innecesarios"

    else

        info "ℹ️ El sistema ya se encontraba limpio y optimizado"
    fi

    echo ""

    printf "💾 Espacio recuperado: %sMB\n" "$TOTAL_FREED_MB"
    printf "🧹 Elementos eliminados: %s\n" "$FILES_REMOVED"

    if [[ "$SCORE_BEFORE" != "N/A" && "$SCORE_AFTER" != "N/A" ]]; then

        local diff=$((SCORE_AFTER - SCORE_BEFORE))

        echo ""

        if [[ "$diff" -gt 0 ]]; then
            success "🚀 Mejora detectada: +${diff} puntos"
        elif [[ "$diff" -lt 0 ]]; then
            warn "⚠️ Variación detectada: ${diff} puntos"
        else
            info "➖ Score estable"
        fi
    fi
}
