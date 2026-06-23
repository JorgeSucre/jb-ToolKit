#!/bin/bash

# =========================
# State helpers
# =========================

STATE_FILE="$BASE_DIR/logs/state.env"

# Lightweight maintenance history — flat, append-only text file, no
# database. One line per *completed* run: timestamp|profile|score_after.
# Report (core/report.sh, core/report_pdf.py) reads this file directly,
# the same way it already reads state.env/system_snapshot — there's no
# bash-function dependency between modules, just a shared file format.
MAINTENANCE_HISTORY_FILE="$BASE_DIR/logs/maintenance_history.log"

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
# Maintenance history (Objective 2 — lightweight, no database)
# =========================

append_maintenance_history() {

    local timestamp="$1" profile="$2" score="$3"

    mkdir -p "$(dirname "$MAINTENANCE_HISTORY_FILE")" 2>/dev/null || true

    printf "%s|%s|%s\n" "$timestamp" "$profile" "$score" >> "$MAINTENANCE_HISTORY_FILE"
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

    # Only completed runs get a history entry — MAINTENANCE_SKIPPED exits
    # core/maintenance.sh before this function is ever called, so a
    # declined run is correctly never recorded.
    append_maintenance_history "$timestamp" "$PERFORMANCE_PROFILE" "$SCORE_AFTER"

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
