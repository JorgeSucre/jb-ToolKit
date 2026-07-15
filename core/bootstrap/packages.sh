#!/bin/bash

# =========================
# Package helpers
# =========================

EXTRA_PACKAGES=""
TOOLKIT_OUTDATED=""
SELECTED_PACKAGES=""

OPTIONAL_PACKAGE_IDS=(
    "microsoft-word" "microsoft-excel" "onedrive" "visual-studio-code"
    "codex" "antigravity" "chatgpt" "discord" "kdenlive" "gimp"
    "floorp" "logi-options+" "tailscale-app" "android-platform-tools" "openjdk"
)
OPTIONAL_PACKAGE_LABELS=(
    "Microsoft Word" "Microsoft Excel" "OneDrive" "VS Code"
    "Codex" "Antigravity" "ChatGPT" "Discord" "Kdenlive" "GIMP"
    "Floorp" "Logi Options+" "Tailscale" "Android Platform Tools" "OpenJDK"
)

package_selected() {
    local package="$1"
    grep -qx "$package" <<< "$SELECTED_PACKAGES"
}

add_selected_package() {
    local package="$1"
    if ! package_selected "$package"; then
        SELECTED_PACKAGES+="$package"$'\n'
        session_write INFO "Selected package: $package"
    fi
}

parse_package_selection() {
    local selection="$1"
    local max="$2"
    local item

    selection="${selection// /}"
    [[ -z "$selection" || "$selection" == "0" || "$selection" == "none" ]] && return 0

    if [[ "$selection" == "a" || "$selection" == "all" ]]; then
        for ((item=0; item<max; item++)); do
            add_selected_package "${OPTIONAL_PACKAGE_IDS[$item]}"
        done
        return 0
    fi

    while IFS= read -r item; do
        add_selected_package "${OPTIONAL_PACKAGE_IDS[$((item - 1))]}"
    done < <(parse_selection "$selection" "$max")
}

select_optional_packages() {
    local index selection

    print_section "🧩 Aplicaciones opcionales"
    if ! ask_yes_no "¿Deseas revisar aplicaciones opcionales adicionales?"; then
        info "ℹ️ Aplicaciones opcionales omitidas"
        return 0
    fi

    echo ""
    for ((index=0; index<${#OPTIONAL_PACKAGE_IDS[@]}; index++)); do
        printf "[%s] %s\n" "$((index + 1))" "${OPTIONAL_PACKAGE_LABELS[$index]}"
    done
    echo ""
    echo "[a] Instalar todas"
    echo "[0] No instalar ninguna"
    printf "Selecciona una o varias opciones (ej: 1,4,7): "
    read -r selection

    parse_package_selection "$selection" "${#OPTIONAL_PACKAGE_IDS[@]}"
}

package_install_state() {
    local package="$1"

    if brew_formula_installed "$package"; then
        if brew_outdated_formula | grep -Fxq "$package"; then
            printf "update\n"
        else
            printf "installed\n"
        fi
        return 0
    fi

    if brew_cask_installed "$package"; then
        if brew_outdated_cask | grep -Fxq "$package"; then
            printf "update\n"
        else
            printf "installed\n"
        fi
        return 0
    fi

    printf "not_installed\n"
}

offer_hardware_recommendations() {
    local recommended_ids=()
    local recommended_labels=()
    local selectable_ids=()
    local selectable_labels=()
    local index selection package state label

    detect_machine_family

    case "$MACHINE_FAMILY" in
        macbook_air)
            recommended_ids=("aldente")
            recommended_labels=("AlDente")
            if has_external_display; then
                recommended_ids+=("betterdisplay")
                recommended_labels+=("BetterDisplay")
            fi
            ;;
        macbook_pro)
            recommended_ids=("aldente" "macs-fan-control")
            recommended_labels=("AlDente" "Macs Fan Control")
            if has_external_display; then
                recommended_ids+=("betterdisplay")
                recommended_labels+=("BetterDisplay")
            fi
            ;;
        mac_mini|mac_studio)
            recommended_ids=("macs-fan-control" "betterdisplay")
            recommended_labels=("Macs Fan Control" "BetterDisplay")
            ;;
        imac)
            recommended_ids=("macs-fan-control")
            recommended_labels=("Macs Fan Control")
            if has_external_display; then
                recommended_ids+=("betterdisplay")
                recommended_labels+=("BetterDisplay")
            fi
            ;;
        *) return 0 ;;
    esac

    print_section "🧠 Recomendaciones para este Mac"
    for ((index=0; index<${#recommended_ids[@]}; index++)); do
        package="${recommended_ids[$index]}"
        label="${recommended_labels[$index]}"
        state=$(package_install_state "$package" 2>/dev/null || true)
        case "$state" in
            installed)
                success "✔ $label ya instalado y actualizado"
                ;;
            update)
                selectable_ids+=("$package")
                selectable_labels+=("Actualizar $label")
                ;;
            not_installed)
                selectable_ids+=("$package")
                selectable_labels+=("Instalar $label")
                ;;
            *)
                warn "⚠️ No se pudo determinar el estado de $label"
                ;;
        esac
    done

    if [[ "${#selectable_ids[@]}" -eq 0 ]]; then
        info "ℹ️ No hay recomendaciones pendientes"
        return 0
    fi

    echo ""
    for ((index=0; index<${#selectable_ids[@]}; index++)); do
        printf "[%s] %s\n" "$((index + 1))" "${selectable_labels[$index]}"
    done
    echo "[a] Aplicar todas las recomendaciones"
    echo "[0] Omitir"
    printf "Selecciona recomendaciones (ej: 1,2): "
    read -r selection

    selection="${selection// /}"
    if [[ "$selection" == "a" || "$selection" == "all" ]]; then
        for package in "${selectable_ids[@]}"; do
            add_selected_package "$package"
            success "✔ $package seleccionado"
        done
    elif [[ -n "$selection" && "$selection" != "0" ]]; then
        while IFS= read -r index; do
            package="${selectable_ids[$((index - 1))]}"
            add_selected_package "$package"
            success "✔ $package seleccionado"
        done < <(parse_selection "$selection" "${#selectable_ids[@]}")
    fi
}

filter_brewfile_to_selection() {
    local output="${TEMP_BREWFILE}.selected"
    local line package

    [[ -f "$TEMP_BREWFILE" ]] || {
        error_msg "❌ No existe el Brewfile temporal"
        return 1
    }

    : > "$output"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^(brew|cask)[[:space:]]+\"([^\"]+)\" ]]; then
            package="${BASH_REMATCH[2]}"
            if [[ "$package" == "fastfetch" ]] || package_selected "$package"; then
                printf "%s\n" "$line" >> "$output"
            fi
        else
            printf "%s\n" "$line" >> "$output"
        fi
    done < "$TEMP_BREWFILE"

    mv "$output" "$TEMP_BREWFILE"

    if ! awk -F'"' '$2 == "fastfetch" && $1 ~ /^brew / {found=1} END {exit !found}' \
        "$TEMP_BREWFILE"; then
        error_msg "❌ El Brewfile temporal perdió fastfetch"
        return 1
    fi

    while IFS= read -r package; do
        [[ -z "$package" ]] && continue
        if ! awk -F'"' -v package="$package" \
            '$2 == package && ($1 ~ /^brew / || $1 ~ /^cask /) {found=1} END {exit !found}' \
            "$TEMP_BREWFILE"; then
            error_msg "❌ El paquete seleccionado no existe en el Brewfile: $package"
            return 1
        fi
    done <<< "$SELECTED_PACKAGES"
}

# =========================
# External packages
# =========================

append_external_packages() {

    local installed="$1"
    local expected="$2"
    local prefix="$3"

    while IFS= read -r item; do

        [[ -z "$item" ]] && continue

        if ! grep -qx "$item" <<< "$expected"; then
            EXTRA_PACKAGES+="${prefix}:${item}"$'\n'
        fi

    done <<< "$installed"
}

build_external_package_list() {

    EXTRA_PACKAGES=""

    append_external_packages \
        "$INSTALLED_BREW" \
        "$EXPECTED_PACKAGES" \
        "brew"

    append_external_packages \
        "$INSTALLED_CASKS" \
        "$EXPECTED_CASKS" \
        "cask"
}

print_external_package_summary() {

    EXTRA_COUNT=$(printf "%s" "$EXTRA_PACKAGES" \
        | sed '/^$/d' \
        | wc -l \
        | tr -d ' ')

    [[ "$EXTRA_COUNT" -eq 0 ]] && return 0

    print_section "📦 Paquetes detectados fuera del Brewfile"

    warn "Se detectaron herramientas instaladas fuera del toolkit"
    info "ℹ️ Esto es normal en sistemas ya configurados"

    echo ""
    echo "Principales detectados:"
    echo ""

    KNOWN_PACKAGES=$( \
        printf "%s" "$EXTRA_PACKAGES" \
            | sed '/^$/d' \
            | sed 's/^brew://g' \
            | sed 's/^cask://g' \
            | head -5 \
            | sed 's/^/   • /'
    ) || true

    if [[ -n "$KNOWN_PACKAGES" ]]; then
        printf "%s\n" "$KNOWN_PACKAGES"
    else
        echo "   • Herramientas de desarrollo y dependencias detectadas"
    fi
}

ask_external_package_updates() {

    UPDATE_EXTRA_PACKAGES="false"

    [[ "$EXTRA_COUNT" -eq 0 ]] && return 0

    echo ""

    if ask_yes_no "¿Actualizar también los paquetes externos al Brewfile?"; then
        UPDATE_EXTRA_PACKAGES="true"
    fi
}

update_external_packages() {

    [[ "$UPDATE_EXTRA_PACKAGES" != "true" ]] && return 0

    print_section "📦 Paquetes externos al Brewfile"

    log "⬆️ Actualizando paquetes externos..."

    OUTDATED_EXTERNAL=$(brew_outdated_formula)
    OUTDATED_EXTERNAL+=$'\n'
    OUTDATED_EXTERNAL+=$(brew_outdated_cask)

    if [[ -z "$OUTDATED_EXTERNAL" ]]; then
        success "✔ No había paquetes externos pendientes"
        return 0
    fi

    while IFS= read -r pkg; do

        [[ -z "$pkg" ]] && continue

        pkg_name=$(awk '{print $1}' <<< "$pkg")

        if ! grep -Fqx "brew:${pkg_name}" <<< "$EXTRA_PACKAGES" \
            && ! grep -Fqx "cask:${pkg_name}" <<< "$EXTRA_PACKAGES"; then
            continue
        fi

        echo "   • $pkg_name"

        if ! brew_upgrade_package "$pkg_name"; then
            warn "⚠️ No se pudo actualizar $pkg_name"
        fi

    done <<< "$OUTDATED_EXTERNAL"

    success "✔ Paquetes externos actualizados"
}

# =========================
# Outdated toolkit packages
# =========================

append_outdated() {

    local installed="$1"
    local outdated="$2"

    while IFS= read -r item; do

        [[ -z "$item" ]] && continue

        if grep -qx "$item" <<< "$outdated"; then
            TOOLKIT_OUTDATED+="$item"$'\n'
        fi

    done <<< "$installed"
}

build_outdated_package_list() {

    TOOLKIT_OUTDATED=""

    OUTDATED_FORMULAS=$(brew_outdated_formula)
    OUTDATED_CASKS=$(brew_outdated_cask)

    append_outdated \
        "$EXPECTED_PACKAGES" \
        "$OUTDATED_FORMULAS"

    append_outdated \
        "$EXPECTED_CASKS" \
        "$OUTDATED_CASKS"
}

print_outdated_summary() {

    TOOLKIT_OUTDATED_COUNT=$(printf "%s" "$TOOLKIT_OUTDATED" \
        | sed '/^$/d' \
        | wc -l \
        | tr -d ' ')

    print_section "📚 Configuración de paquetes"

    if [[ "$TOOLKIT_OUTDATED_COUNT" -eq 0 ]]; then
        success "✔ No se detectaron actualizaciones pendientes del toolkit"
        return 0
    fi

    warn "📋 ${TOOLKIT_OUTDATED_COUNT} paquetes del toolkit requieren actualización"

    echo ""

    while IFS= read -r pkg; do

        [[ -z "$pkg" ]] && continue

        echo "   • $pkg"

    done <<< "$TOOLKIT_OUTDATED"
}

update_toolkit_packages() {

    [[ "$TOOLKIT_OUTDATED_COUNT" -eq 0 ]] && return 0

    echo ""

    log "⬆️ Actualizando paquetes del toolkit..."

    while IFS= read -r pkg; do

        [[ -z "$pkg" ]] && continue

        pkg_name=$(awk '{print $1}' <<< "$pkg")

        echo "   • $pkg_name"

        if ! brew_upgrade_package "$pkg_name"; then
            warn "⚠️ No se pudo actualizar $pkg_name"
        fi

    done <<< "$TOOLKIT_OUTDATED"

    run_cmd brew cleanup -s || warn "⚠️ Homebrew cleanup no pudo completarse"
    brew_cache_reset

    echo ""

    success "✔ Paquetes del toolkit actualizados correctamente"
}

# =========================
# Installed package summary
# =========================

print_installed_summary() {

    INSTALLED_SUMMARY=$(grep -E '^(brew|cask)' "$TEMP_BREWFILE" \
        | awk -F'"' '{print $2}' \
        | head -10)

    [[ -z "$INSTALLED_SUMMARY" ]] && return 0

    print_section "📦 Herramientas principales disponibles"

    while IFS= read -r item; do

        [[ -z "$item" ]] && continue

        printf "• %s\n" "$item"

    done <<< "$INSTALLED_SUMMARY"
}
