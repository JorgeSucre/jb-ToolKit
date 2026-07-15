#!/bin/bash

# =========================
# Cleanup helpers
# =========================

CACHE_FILES_REMOVED=0
LOG_FILES_REMOVED=0
TRASH_FILES_REMOVED=0

CACHE_MB_FREED=0
LOG_MB_FREED=0
TRASH_MB_FREED=0

CACHE_FILE_COUNT=0
LOG_FILE_COUNT=0
TRASH_FILE_COUNT=0

# Homebrew freed MB accumulator
HOMEBREW_MB_FREED=0
MAINTENANCE_SKIPPED="false"
# =========================
# Homebrew cleanup
# =========================

has_homebrew_cleanup_candidates() {

    brew_available || return 1

    brew cleanup -n 2>/dev/null \
        | grep -q .
}

# =========================
# Size helpers
# =========================

safe_old_files_size_mb() {

    local path="$1"
    local days="$2"

    find "$path" \
        -type f \
        -mtime +"$days" \
        -print0 2>/dev/null \
        | xargs -0 du -sm 2>/dev/null \
        | awk '{sum += $1} END {print sum+0}'
}

# =========================
# Cleanup scanners
# =========================

scan_cleanup_targets() {

    CACHE_FILE_COUNT=$(find ~/Library/Caches \
        -type f \
        -mtime +7 2>/dev/null \
        | wc -l \
        | tr -d ' ')

    LOG_FILE_COUNT=$(find ~/Library/Logs \
        -type f \
        -mtime +14 2>/dev/null \
        | wc -l \
        | tr -d ' ')

    TRASH_FILE_COUNT=$(find ~/.Trash \
        -mindepth 1 \
        -mtime +7 2>/dev/null \
        | wc -l \
        | tr -d ' ')

    CACHE_MB_FREED=$(safe_old_files_size_mb ~/Library/Caches 7)
    LOG_MB_FREED=$(safe_old_files_size_mb ~/Library/Logs 14)
    TRASH_MB_FREED=$(safe_old_files_size_mb ~/.Trash 7)
}

# =========================
# Preview helpers
# =========================

preview_cleanup() {

    print_section "🧪 Vista previa del mantenimiento"

    scan_cleanup_targets

    local total_size=$((CACHE_MB_FREED + LOG_MB_FREED + TRASH_MB_FREED))

    printf "• Cachés antiguas detectadas: %s archivos\n" "$CACHE_FILE_COUNT"
    printf "• Logs antiguos detectados: %s archivos\n" "$LOG_FILE_COUNT"
    printf "• Papelera antigua detectada: %s elementos\n" "$TRASH_FILE_COUNT"
    if [[ "$total_size" -ge 1024 ]]; then
        printf "• Espacio potencial a recuperar: ~%.1fGB\n" \
            "$(awk "BEGIN {print $total_size/1024}")"
    else
        printf "• Espacio potencial a recuperar: ~%sMB\n" "$total_size"
    fi
}

# =========================
# Homebrew cleanup
# =========================

cleanup_homebrew() {

    brew_available || return 0
    [[ ! -d ~/Library/Caches/Homebrew ]] && return 0

    print_section "📦 Homebrew"

    if ! has_homebrew_cleanup_candidates; then
        info "✔ Homebrew ya se encuentra limpio"
        return 0
    fi

    local before_size
    local after_size

    before_size=$(dir_size_mb ~/Library/Caches/Homebrew)

    log "🧹 Limpiando paquetes y cachés Homebrew..."

    run_cmd brew cleanup -s || warn "⚠️ Homebrew cleanup no pudo completarse"

    after_size=$(dir_size_mb ~/Library/Caches/Homebrew)

    HOMEBREW_MB_FREED=$((before_size - after_size))

    [[ "$HOMEBREW_MB_FREED" -lt 0 ]] && HOMEBREW_MB_FREED=0

    TOTAL_FREED_MB=$((TOTAL_FREED_MB + HOMEBREW_MB_FREED))

    if [[ "$HOMEBREW_MB_FREED" -eq 0 ]]; then
        info "✔ Homebrew ya se encontraba optimizado"
    else
        success "✔ Homebrew limpiado (${HOMEBREW_MB_FREED}MB liberados)"
    fi
}

# =========================
# Cache cleanup
# =========================

cleanup_caches() {

    print_section "🧹 Cachés de usuario"

    log "🧹 Eliminando cachés antiguas (>7 días)..."
    if [[ "$CACHE_FILE_COUNT" -eq 0 ]]; then
        info "✔ No se detectaron cachés antiguas"
        return 0
    fi

    find ~/Library/Caches \
        -type f \
        -mtime +7 \
        -delete 2>/dev/null || true

    local remaining
    remaining=$(find ~/Library/Caches -type f -mtime +7 2>/dev/null | wc -l | tr -d ' ')
    CACHE_FILES_REMOVED=$(( CACHE_FILE_COUNT - remaining ))
    [[ "$CACHE_FILES_REMOVED" -lt 0 ]] && CACHE_FILES_REMOVED=0

    [[ "$CACHE_MB_FREED" -lt 0 ]] && CACHE_MB_FREED=0

    TOTAL_FREED_MB=$((TOTAL_FREED_MB + CACHE_MB_FREED))
    FILES_REMOVED=$((FILES_REMOVED + CACHE_FILES_REMOVED))

    success "✔ ${CACHE_FILES_REMOVED} archivos eliminados"
    success "✔ ${CACHE_MB_FREED}MB recuperados"
}

# =========================
# Logs cleanup
# =========================

cleanup_logs() {

    print_section "📜 Logs del sistema"

    log "🧹 Eliminando logs antiguos (>14 días)..."
    if [[ "$LOG_FILE_COUNT" -eq 0 ]]; then
        info "✔ No se detectaron logs antiguos"
        return 0
    fi

    find ~/Library/Logs \
        -type f \
        -mtime +14 \
        -delete 2>/dev/null || true

    local remaining
    remaining=$(find ~/Library/Logs -type f -mtime +14 2>/dev/null | wc -l | tr -d ' ')
    LOG_FILES_REMOVED=$(( LOG_FILE_COUNT - remaining ))
    [[ "$LOG_FILES_REMOVED" -lt 0 ]] && LOG_FILES_REMOVED=0

    [[ "$LOG_MB_FREED" -lt 0 ]] && LOG_MB_FREED=0

    TOTAL_FREED_MB=$((TOTAL_FREED_MB + LOG_MB_FREED))
    FILES_REMOVED=$((FILES_REMOVED + LOG_FILES_REMOVED))

    success "✔ ${LOG_FILES_REMOVED} logs eliminados"
    success "✔ ${LOG_MB_FREED}MB recuperados"
}

# =========================
# Trash cleanup
# =========================

cleanup_trash() {

    print_section "🗑️ Papelera"

    log "🧹 Eliminando elementos antiguos (>7 días)..."
    if [[ "$TRASH_FILE_COUNT" -eq 0 ]]; then
        info "✔ Papelera ya se encontraba limpia"
        return 0
    fi

    find ~/.Trash \
        -mindepth 1 \
        -mtime +7 \
        -exec rm -rf {} + 2>/dev/null || true

    local remaining
    remaining=$(find ~/.Trash -mindepth 1 -mtime +7 2>/dev/null | wc -l | tr -d ' ')
    TRASH_FILES_REMOVED=$(( TRASH_FILE_COUNT - remaining ))
    [[ "$TRASH_FILES_REMOVED" -lt 0 ]] && TRASH_FILES_REMOVED=0

    [[ "$TRASH_MB_FREED" -lt 0 ]] && TRASH_MB_FREED=0

    TOTAL_FREED_MB=$((TOTAL_FREED_MB + TRASH_MB_FREED))
    FILES_REMOVED=$((FILES_REMOVED + TRASH_FILES_REMOVED))

    success "✔ ${TRASH_FILES_REMOVED} elementos eliminados"
    success "✔ ${TRASH_MB_FREED}MB recuperados"
}

# =========================
# Main cleanup flow
# =========================

run_cleanup_tasks() {

    preview_cleanup

    echo ""

    if ! ask_yes_no "¿Continuar con el mantenimiento?"; then
        MAINTENANCE_SKIPPED="true"
        info "ℹ️ Mantenimiento omitido por el usuario"
        return 0
    fi

    cleanup_homebrew
    cleanup_caches
    cleanup_logs
    cleanup_trash
    echo ""
    success "✔ Limpieza completada"
}
