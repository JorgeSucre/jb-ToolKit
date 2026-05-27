

#!/bin/bash

# =========================
# Apps cleanup helpers
# =========================

APP_CANDIDATES=""
APP_PATHS=()

# =========================
# Helpers
# =========================

app_size_mb() {

    local app_path="$1"

    du -sm "$app_path" 2>/dev/null \
        | awk '{print $1}'
}

app_last_used() {

    local app_path="$1"

    mdls -name kMDItemLastUsedDate \
        -raw "$app_path" 2>/dev/null
}

human_last_used() {

    local raw_date="$1"

    if [[ -z "$raw_date" || "$raw_date" == "(null)" ]]; then
        echo "Desconocido"
        return
    fi

    local epoch_now
    local epoch_used
    local diff_days

    epoch_now=$(date +%s)
    epoch_used=$(date -j -f "%Y-%m-%d %H:%M:%S %z" \
        "$raw_date" +%s 2>/dev/null || echo 0)

    if [[ "$epoch_used" -eq 0 ]]; then
        echo "Desconocido"
        return
    fi

    diff_days=$(( (epoch_now - epoch_used) / 86400 ))

    if [[ "$diff_days" -le 0 ]]; then
        echo "hoy"
    elif [[ "$diff_days" -eq 1 ]]; then
        echo "hace 1 día"
    else
        echo "hace ${diff_days} días"
    fi
}

is_intel_only_app() {

    local app_path="$1"

    file "$app_path/Contents/MacOS/"* 2>/dev/null \
        | grep -q "x86_64"
}

# =========================
# Candidate detection
# =========================

scan_large_apps() {

    APP_CANDIDATES=""

    while IFS= read -r app; do

        [[ -z "$app" ]] && continue

        local size_mb
        size_mb=$(app_size_mb "$app")

        [[ -z "$size_mb" ]] && continue

        if [[ "$size_mb" -lt 500 ]]; then
            continue
        fi

        APP_CANDIDATES+="$app"$'\n'

    done < <(find /Applications \
        -maxdepth 1 \
        -name "*.app" \
        2>/dev/null)
}

# =========================
# Display cleanup candidates
# =========================

print_app_candidates() {

    [[ -z "$APP_CANDIDATES" ]] && return 0

    print_section "📦 Aplicaciones candidatas a limpieza"

    local index=1

    while IFS= read -r app; do

        [[ -z "$app" ]] && continue

        local app_name
        local app_size
        local last_used
        local human_used

        app_name=$(basename "$app" .app)
        app_size=$(app_size_mb "$app")
        last_used=$(app_last_used "$app")
        human_used=$(human_last_used "$last_used")

        printf "%s) %s\n" "$index" "$app_name"
        printf "   • Tamaño: %sMB\n" "$app_size"
        printf "   • Último uso: %s\n" "$human_used"

        if [[ "$app_size" -ge 5000 ]]; then
            printf "   • Candidata por: Tamaño crítico\n"
        fi

        if is_intel_only_app "$app"; then
            printf "   • Aplicación Intel-only detectada\n"
        fi

        echo ""

        APP_PATHS[$index]="$app"

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

    [[ ${#selected[@]} -eq 0 ]] && return 0

    local moved=0

    for item in "${selected[@]}"; do

        item=$(echo "$item" | xargs)

        [[ -z "$item" ]] && continue

        local app_path="${APP_PATHS[$item]:-}"

        [[ -z "$app_path" ]] && continue

        local app_name
        app_name=$(basename "$app_path")

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

    [[ -z "$APP_CANDIDATES" ]] && return 0

    print_app_candidates

    move_apps_to_trash
}