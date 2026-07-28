#!/bin/bash

# =========================
# State helpers
# =========================
# STATE_FILE is owned by core/utils.sh; not redefined here.

# =========================
# State initialization
# =========================

initialize_state() {

    TOTAL_FREED_MB=0
    FILES_REMOVED=0
    PERFORMANCE_PROFILE="none"

    SCORE_BEFORE="N/A"
    SCORE_AFTER="N/A"

    local previous_score
    previous_score="$(state_value SCORE_AFTER)"
    [[ "$previous_score" != "N/A" ]] && SCORE_BEFORE="$previous_score"
}

# =========================
# Score calculation
# =========================

calculate_post_maintenance_score() {

    local score

    score=$(calculate_health_score 2>/dev/null \
        | tr -dc '0-9')

    if [[ -z "$score" ]]; then
        warn "⚠️ No se pudo calcular el score posterior"
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
    [[ -z "$SCORE_BEFORE" ]] && SCORE_BEFORE="N/A"
    [[ -z "$SCORE_AFTER" ]] && SCORE_AFTER="N/A"

    local timestamp
    timestamp=$(date +%Y-%m-%d_%H:%M:%S)

    write_state_values \
        "SCORE_BEFORE=$SCORE_BEFORE" \
        "SCORE_AFTER=$SCORE_AFTER" \
        "TIMESTAMP=$timestamp" \
        "LAST_MAINTENANCE=$timestamp" \
        "TOTAL_FREED_MB=$TOTAL_FREED_MB" \
        "FILES_REMOVED=$FILES_REMOVED" \
        "PERFORMANCE_PROFILE=$PERFORMANCE_PROFILE" \
        "LAST_MODULE=maintenance" \
        "LAST_DURATION=${ELAPSED:-0}" \
        "ARCH=$(uname -m)" \
        "JB_VERSION=$JB_VERSION"

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

    if [[ "$TOTAL_FREED_MB" -ge 1024 ]]; then
        printf "💾 Espacio recuperado: %.1fGB\n" \
            "$(awk "BEGIN {print $TOTAL_FREED_MB/1024}")"
    else
        printf "💾 Espacio recuperado: %sMB\n" "$TOTAL_FREED_MB"
    fi
    printf "🧹 Elementos eliminados: %s\n" "$FILES_REMOVED"

    if [[ "$PERFORMANCE_PROFILE" != "none" ]]; then
        printf "⚡ Perfil aplicado: %s\n" "$PERFORMANCE_PROFILE"
    fi

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
