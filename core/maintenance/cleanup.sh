

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

# =========================
# Size helpers
# =========================

safe_dir_size_mb() {

    local path="$1"

    du -sm "$path" 2>/dev/null \
        | awk '{print $1+0}'
}

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

safe_find_count() {

    local path="$1"
    local days="$2"

    find "$path" \
        -type f \
        -mtime +"$days" 2>/dev/null \
        | wc -l \
        | tr -d ' '
}

# =========================
# Preview helpers
# =========================

preview_cleanup() {

    print_section "🧪 Vista previa del mantenimiento"

    local cache_count
    local logs_count
    local trash_count

    cache_count=$(safe_find_count ~/Library/Caches 7)
    logs_count=$(safe_find_count ~/Library/Logs 14)
    trash_count=$(safe_find_count ~/.Trash 7)

    local cache_size
    local logs_size
    local trash_size

    cache_size=$(safe_old_files_size_mb ~/Library/Caches 7)
    logs_size=$(safe_old_files_size_mb ~/Library/Logs 14)
    trash_size=$(safe_old_files_size_mb ~/.Trash 7)

    local total_size=$((cache_size + logs_size + trash_size))

    printf "• Cachés antiguas detectadas: %s archivos\n" "$cache_count"
    printf "• Logs antiguos detectados: %s archivos\n" "$logs_count"
    printf "• Papelera antigua detectada: %s elementos\n" "$trash_count"
    printf "• Espacio potencial a recuperar: ~%sMB\n" "$total_size"
}

# =========================
# Homebrew cleanup
# =========================

cleanup_homebrew() {

    command -v brew >/dev/null 2>&1 || return 0

    print_section "📦 Homebrew"

    local before_size
    local after_size

    before_size=$(safe_dir_size_mb ~/Library/Caches/Homebrew)

    log "🧹 Limpiando paquetes y cachés Homebrew..."

    brew cleanup -s >/dev/null 2>&1 || true

    after_size=$(safe_dir_size_mb ~/Library/Caches/Homebrew)

    local freed=$((before_size - after_size))

    [[ "$freed" -lt 0 ]] && freed=0

    TOTAL_FREED_MB=$((TOTAL_FREED_MB + freed))

    success "✔ Homebrew limpiado (${freed}MB liberados)"
}

# =========================
# Cache cleanup
# =========================

cleanup_caches() {

    print_section "🧹 Cachés de usuario"

    local before_size
    local after_size

    before_size=$(safe_old_files_size_mb ~/Library/Caches 7)

    log "🧹 Eliminando cachés antiguas (>7 días)..."

    CACHE_FILES_REMOVED=$(find ~/Library/Caches \
        -type f \
        -mtime +7 \
        -delete 2>/dev/null \
        | wc -l \
        | tr -d ' ')

    after_size=$(safe_old_files_size_mb ~/Library/Caches 7)

    CACHE_MB_FREED=$((before_size - after_size))

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

    local before_size
    local after_size

    before_size=$(safe_old_files_size_mb ~/Library/Logs 14)

    log "🧹 Eliminando logs antiguos (>14 días)..."

    LOG_FILES_REMOVED=$(find ~/Library/Logs \
        -type f \
        -mtime +14 \
        -delete 2>/dev/null \
        | wc -l \
        | tr -d ' ')

    after_size=$(safe_old_files_size_mb ~/Library/Logs 14)

    LOG_MB_FREED=$((before_size - after_size))

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

    local before_size
    local after_size

    before_size=$(safe_old_files_size_mb ~/.Trash 7)

    log "🧹 Eliminando elementos antiguos (>7 días)..."

    TRASH_FILES_REMOVED=$(find ~/.Trash \
        -mtime +7 \
        -exec rm -rf {} + 2>/dev/null \
        | wc -l \
        | tr -d ' ')

    after_size=$(safe_old_files_size_mb ~/.Trash 7)

    TRASH_MB_FREED=$((before_size - after_size))

    [[ "$TRASH_MB_FREED" -lt 0 ]] && TRASH_MB_FREED=0

    TOTAL_FREED_MB=$((TOTAL_FREED_MB + TRASH_MB_FREED))
    FILES_REMOVED=$((FILES_REMOVED + TRASH_FILES_REMOVED))

    if [[ "$TRASH_FILES_REMOVED" -eq 0 ]]; then
        info "✔ Papelera ya se encontraba limpia"
    else
        success "✔ ${TRASH_FILES_REMOVED} elementos eliminados"
        success "✔ ${TRASH_MB_FREED}MB recuperados"
    fi
}

# =========================
# Main cleanup flow
# =========================

run_cleanup_tasks() {

    preview_cleanup

    echo ""

    if ! ask_yes_no "¿Continuar con el mantenimiento?"; then
        warn "⚠️ Mantenimiento cancelado"
        return 1
    fi

    cleanup_homebrew
    cleanup_caches
    cleanup_logs
    cleanup_trash
}