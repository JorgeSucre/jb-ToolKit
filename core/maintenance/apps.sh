#!/bin/bash

# =========================
# Apps cleanup helpers
# =========================

APP_CANDIDATES=""
APP_PATHS=()
APP_METADATA_CACHE=""
APP_COUNT=0
MAX_RESULTS="${MAX_RESULTS:-12}"

APPLE_SILICON="false"

if [[ "$(uname -m)" == "arm64" ]]; then
    APPLE_SILICON="true"
fi

# =========================
# Helpers
# =========================

app_size_mb() {

    local app_path="$1"

    du -sm "$app_path" 2>/dev/null \
        | awk '{print $1}'
}

human_size() {

    local size_mb="$1"

    if [[ "$size_mb" -ge 1024 ]]; then
        awk "BEGIN {printf \"%.1fGB\", $size_mb/1024}"
    else
        echo "${size_mb}MB"
    fi
}

is_intel_only_app() {

    local app_path="$1"
    local binary_info

    binary_info=$(file "$app_path/Contents/MacOS/"* 2>/dev/null)

    echo "$binary_info" | grep -q "x86_64" || return 1

    if echo "$binary_info" | grep -q "arm64"; then
        return 1
    fi

    return 0
}



app_age_days() {

    local app_path="$1"

    local modified
    local now

    modified=$(stat -f "%m" "$app_path" 2>/dev/null || echo 0)
    now=$(date +%s)

    if [[ "$modified" -eq 0 ]]; then
        echo 0
        return
    fi

    echo $(( (now - modified) / 86400 ))
}

# =========================
# Metadata cache
# =========================

build_app_metadata_cache() {

    [[ -n "$APP_METADATA_CACHE" ]] && return 0
    # removed load_outdated_casks

    while IFS= read -r app; do

        [[ -z "$app" ]] && continue

        local size_mb
        size_mb=$(app_size_mb "$app")

        [[ -z "$size_mb" ]] && continue

        # Ignorar apps pequeñas irrelevantes
        if [[ "$size_mb" -lt 100 ]]; then
            continue
        fi

        local app_name
        local intel_only="false"
        local age_days
        local health_score=0
        local human_size_mb
        local risk_level="Bajo"

        app_name=$(basename "$app" .app)
        age_days=$(app_age_days "$app")
        human_size_mb=$(human_size "$size_mb")

        if is_intel_only_app "$app"; then
            intel_only="true"
        fi

        # Ranking heurístico — factores independientes con pesos calibrados
        if [[ "$APPLE_SILICON" == "true" && "$intel_only" == "true" ]]; then
            health_score=$((health_score + 35))
        fi

        if [[ "$size_mb" -gt 5120 ]]; then
            health_score=$((health_score + 25))
        elif [[ "$size_mb" -gt 1024 ]]; then
            health_score=$((health_score + 10))
        fi

        if [[ "$age_days" -gt 30 ]]; then
            health_score=$((health_score + 20))
        fi

        if [[ "$health_score" -ge 70 ]]; then
            risk_level="Crítico"
        elif [[ "$health_score" -ge 40 ]]; then
            risk_level="Alto"
        elif [[ "$health_score" -ge 25 ]]; then
            risk_level="Medio"
        else
            continue
        fi

        APP_METADATA_CACHE+="$health_score|$risk_level|$app|$app_name|$size_mb|$human_size_mb|$age_days|$intel_only"$'\n'

    done < <(
        find /Applications "$HOME/Applications" \
            -maxdepth 1 \
            -name "*.app" \
            2>/dev/null
    )
}

# =========================
# Candidate detection
# =========================

scan_large_apps() {

    APP_CANDIDATES=""
    APP_COUNT=0

    build_app_metadata_cache

    APP_METADATA_CACHE=$(echo "$APP_METADATA_CACHE" \
        | sort -t'|' -nrk1)
    APP_METADATA_CACHE=$(echo "$APP_METADATA_CACHE" | head -n "$MAX_RESULTS")

    while IFS= read -r entry; do

        [[ -z "$entry" ]] && continue

        local app_path

        app_path=$(echo "$entry" | cut -d'|' -f3)

        APP_CANDIDATES+="$entry"$'\n'

        ((APP_COUNT++))

    done <<< "$APP_METADATA_CACHE"
}

# =========================
# Display cleanup candidates
# =========================

print_app_candidates() {

    [[ -z "$APP_CANDIDATES" ]] && return 0

    print_section "🧠 Aplicaciones potencialmente problemáticas"
    info "ℹ️ ${APP_COUNT} aplicaciones potencialmente problemáticas detectadas"
    echo ""

    local index=1

    while IFS= read -r app; do

        [[ -z "$app" ]] && continue

        IFS='|' read -r \
            app_score \
            risk_level \
            app_path \
            app_name \
            app_size \
            app_size_human \
            app_age \
            intel_only <<< "$app"

        printf "%s) %s\n" "$index" "$app_name"
        printf "   • Riesgo: %s (%s puntos)\n" "$risk_level" "$app_score"
        printf "   • Tamaño: %s\n" "$app_size_human"

        if [[ "$app_age" -gt 30 ]]; then
            printf "   • Probablemente olvidada (%s días sin cambios)\n" "$app_age"
        fi

        if [[ "$app_size" -ge 5000 ]]; then
            printf "   • Tamaño elevado\n"
        fi

        if [[ "$intel_only" == "true" ]]; then
            printf "   • Intel-only en Apple Silicon\n"
        fi

        if [[ "$risk_level" == "Crítico" ]]; then
            printf "   • Recomendación: revisar compatibilidad o desinstalar\n"
        elif [[ "$risk_level" == "Alto" ]]; then
            printf "   • Recomendación: revisar o desinstalar\n"
        elif [[ "$risk_level" == "Medio" ]]; then
            printf "   • Recomendación: validar si aún la utilizas\n"
        fi

        echo ""

        APP_PATHS[$index]="$app_path"

        ((index++))

    done <<< "$APP_CANDIDATES"
}

# =========================
# Cleanup selection
# =========================

move_apps_to_trash() {

    [[ -z "$APP_CANDIDATES" ]] && return 0

    printf "Selecciona apps a mover a la Papelera (ej: 1,3,5 | 0 para omitir): "

    read -r selection

    if [[ -z "$selection" || "$selection" == "0" ]]; then
        info "ℹ️ Limpieza de aplicaciones omitida"
        return 0
    fi

    IFS=',' read -ra selected <<< "$selection"
    unset IFS

    [[ ${#selected[@]} -eq 0 ]] && return 0

    mkdir -p ~/.Trash 2>/dev/null || true
    local moved=0

    for item in "${selected[@]}"; do

        item=$(echo "$item" | xargs)
        [[ ! "$item" =~ ^[0-9]+$ ]] && continue

        [[ -z "$item" ]] && continue

        local app_path="${APP_PATHS[$item]:-}"

        [[ -z "$app_path" ]] && continue

        local app_name
        app_name=$(basename "$app_path")

        if [[ ! -e "$app_path" ]]; then
            warn "⚠️ La aplicación ya no existe"
            continue
        fi

        if mv "$app_path" ~/.Trash/ 2>/dev/null; then

            printf "✔ %s movida a la Papelera\n" "$app_name"

            ((FILES_REMOVED++))
            ((moved++))
        else
            printf "⚠️ No se pudo mover %s\n" "$app_name"
        fi

    done

    if [[ "$moved" -gt 0 ]]; then
        echo ""
        success "✔ Aplicaciones movidas correctamente"
    fi
}

# =========================
# Main apps cleanup flow
# =========================

run_apps_cleanup() {

    scan_large_apps
    if [[ "$APP_COUNT" -eq 0 ]]; then
        success "✔ No se detectaron aplicaciones problemáticas"
        return 0
    fi

    [[ -z "$APP_CANDIDATES" ]] && return 0

    info "ℹ️ Mostrando las aplicaciones más relevantes"
    echo ""

    print_app_candidates

    move_apps_to_trash
}