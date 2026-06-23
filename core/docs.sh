#!/bin/bash

set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/core/utils.sh"
# Session is owned by the jb launcher.
# Only initialize a fallback session when run standalone (outside jb).


init_session
declare -f set_ui_context >/dev/null 2>&1 || source "$BASE_DIR/core/bootstrap/ui.sh"
declare -f detect_machine_family >/dev/null 2>&1 || source "$BASE_DIR/core/bootstrap/hardware.sh"
declare -f compute_hardware_recommendations >/dev/null 2>&1 || source "$BASE_DIR/core/bootstrap/packages.sh"

DOCS_DIR="$BASE_DIR/references/tools"

# =========================
# Category registry
# =========================
# Display order only. Adding a tool never requires touching this list —
# only adding a brand-new category does.
DOCS_CATEGORY_ORDER=(
    "Productivity"
    "Development"
    "AI"
    "Communication"
    "Android"
    "Networking"
    "Repair & Diagnostics"
    "Monitoring"
    "Utilities"
    "Multimedia"
)

# =========================
# Frontmatter helpers
# =========================

doc_field() {
    local file="$1" field="$2"

    awk -F': ' -v f="$field" '
        /^---$/ { fm++; next }
        fm == 1 && $1 == f { print substr($0, length($1) + 3); exit }
    ' "$file"
}

doc_body() {
    local file="$1"

    awk '
        /^---$/ { fm++; next }
        fm >= 2 { print }
    ' "$file"
}

docs_all_files() {
    local file base

    for file in "$DOCS_DIR"/*.md; do
        [[ -f "$file" ]] || continue
        base="$(basename "$file")"
        [[ "$base" == _* ]] && continue
        printf "%s\n" "$file"
    done
}

doc_searchable_text() {
    local file="$1"

    printf "%s %s %s\n" \
        "$(doc_field "$file" "title")" \
        "$(doc_field "$file" "package")" \
        "$(doc_field "$file" "keywords")"
}

docs_find_file_by_package() {
    local package="$1" file

    while IFS= read -r file; do
        [[ "$(doc_field "$file" "package")" == "$package" ]] && { printf "%s\n" "$file"; return 0; }
    done < <(docs_all_files)

    return 1
}

docs_list_category() {
    local category="$1" file

    while IFS= read -r file; do
        [[ "$(doc_field "$file" "category")" == "$category" ]] && printf "%s\n" "$file"
    done < <(docs_all_files)
}

docs_categories_with_content() {
    local category

    for category in "${DOCS_CATEGORY_ORDER[@]}"; do
        [[ -n "$(docs_list_category "$category")" ]] && printf "%s\n" "$category"
    done
}

# =========================
# Screens
# =========================

docs_show_tool() {
    local file="$1" title

    title="$(doc_field "$file" "title")"
    title="${title:-$(basename "$file" .md)}"

    clear
    print_section "📖 $title"
    doc_body "$file"
    echo ""
    read -r -p "Presiona Enter para volver..." _
}

docs_results_menu() {
    local header="$1"
    shift
    local files=("$@")
    local index selection show_category="${SHOW_CATEGORY:-false}"

    if [[ "${#files[@]}" -eq 0 ]]; then
        print_section "$header"
        info "ℹ️ Aún no hay documentación disponible"
        read -r -p "Presiona Enter para volver..." _
        return 0
    fi

    while true; do
        clear
        print_section "$header"

        for ((index=0; index<${#files[@]}; index++)); do
            if [[ "$show_category" == "true" ]]; then
                printf "[%s] %s (%s)\n" "$((index + 1))" \
                    "$(doc_field "${files[$index]}" "title")" \
                    "$(doc_field "${files[$index]}" "category")"
            else
                printf "[%s] %s\n" "$((index + 1))" "$(doc_field "${files[$index]}" "title")"
            fi
        done
        echo "[0] Volver"
        printf "Selecciona una herramienta: "
        read -r selection
        selection="$(echo "$selection" | xargs)"

        [[ -z "$selection" || "$selection" == "0" ]] && return 0

        if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#files[@]} )); then
            docs_show_tool "${files[$((selection - 1))]}"
        else
            warn "⚠️ Opción inválida"
        fi
    done
}

docs_browse_category() {
    local category="$1"
    local files=() file available

    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(docs_list_category "$category")

    if [[ "${#files[@]}" -eq 0 ]]; then
        clear
        print_section "📚 $category"
        info "ℹ️ No hay guías disponibles todavía para esta categoría."
        echo ""
        echo "Las guías disponibles actualmente se concentran en:"
        while IFS= read -r available; do
            printf -- "- %s\n" "$available"
        done < <(docs_categories_with_content)
        echo ""
        read -r -p "Presiona Enter para volver..." _
        return 0
    fi

    docs_results_menu "📚 $category" "${files[@]}"
}

# =========================
# Search
# =========================
# Fully offline: grep over each tool's title/package/keywords
# frontmatter (not the full body, not category), so structural template
# headings that repeat across every guide (e.g. "JB Repair Use Cases")
# and category-name substrings don't cause unrelated matches.

docs_search() {
    local query files=() file

    print_section "🔎 Buscar en la documentación"
    printf "Buscar (nombre, paquete o palabra clave): "
    read -r query
    query="$(echo "$query" | xargs)"

    [[ -z "$query" ]] && return 0

    while IFS= read -r file; do
        doc_searchable_text "$file" | grep -qi -- "$query" && files+=("$file")
    done < <(docs_all_files)

    if [[ "${#files[@]}" -eq 0 ]]; then
        print_section "🔎 Resultados para: $query"
        info "ℹ️ No se encontraron resultados para: $query"
        read -r -p "Presiona Enter para volver..." _
        return 0
    fi

    SHOW_CATEGORY="true" docs_results_menu "🔎 Resultados para: $query" "${files[@]}"
}

# =========================
# Recommended Tools For This Mac
# =========================
# Reuses the bootstrap hardware-recommendation engine (no duplicated
# family → package mapping) plus per-tool "recommended_profiles"
# frontmatter for general-purpose tools that aren't hardware-sensor
# driven. Read-only: no brew calls, no installation.

docs_recommended_for_mac() {
    local ids=() reasons=() files=()
    local index file package profiles reason selection

    compute_hardware_recommendations

    for ((index=0; index<${#HARDWARE_RECOMMENDED_IDS[@]}; index++)); do
        package="${HARDWARE_RECOMMENDED_IDS[$index]}"
        if file="$(docs_find_file_by_package "$package")"; then
            ids+=("$package")
            files+=("$file")
            reasons+=("Recomendado por el perfil de hardware detectado (${MACHINE_FAMILY})")
        fi
    done

    while IFS= read -r file; do
        profiles="$(doc_field "$file" "recommended_profiles")"
        [[ -z "$profiles" ]] && continue

        package="$(doc_field "$file" "package")"
        grep -qx "$package" <<< "$(printf '%s\n' "${ids[@]}")" && continue

        if grep -qx "all" <<< "${profiles//,/$'\n'}" \
            || grep -qx "$MACHINE_FAMILY" <<< "${profiles//,/$'\n'}"; then
            reason="$(doc_field "$file" "recommend_reason")"
            ids+=("$package")
            files+=("$file")
            reasons+=("${reason:-Recomendado para este equipo}")
        fi
    done < <(docs_all_files)

    print_section "🧠 Recomendados para este Mac"

    if [[ "${#files[@]}" -eq 0 ]]; then
        info "ℹ️ No hay recomendaciones documentadas para este equipo todavía"
        read -r -p "Presiona Enter para volver..." _
        return 0
    fi

    for ((index=0; index<${#files[@]}; index++)); do
        printf "[%s] %s\n" "$((index + 1))" "$(doc_field "${files[$index]}" "title")"
        printf "    %s\n" "${reasons[$index]}"
    done
    echo "[0] Volver"
    printf "Selecciona una herramienta para ver la guía completa: "
    read -r selection
    selection="$(echo "$selection" | xargs)"

    [[ -z "$selection" || "$selection" == "0" ]] && return 0

    if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#files[@]} )); then
        docs_show_tool "${files[$((selection - 1))]}"
    else
        warn "⚠️ Opción inválida"
    fi
}

docs_main() {
    local previous_context="${UI_CONTEXT:-Setup}"
    local index selection

    set_ui_context "Documentation"
    print_banner

    while true; do
        clear
        print_section "📚 Documentación de herramientas"
        info "ℹ️ Disponible sin conexión a internet"
        echo ""

        for ((index=0; index<${#DOCS_CATEGORY_ORDER[@]}; index++)); do
            printf "[%s] %s\n" "$((index + 1))" "${DOCS_CATEGORY_ORDER[$index]}"
        done
        echo "[r] Recomendados para este Mac"
        echo "[s] Buscar"
        echo "[0] Volver"
        printf "Selecciona una opción: "
        read -r selection
        selection="$(echo "$selection" | xargs)"

        case "$selection" in
            "" | "0")
                set_ui_context "$previous_context"
                return 0
                ;;
            r | R)
                docs_recommended_for_mac
                ;;
            s | S)
                docs_search
                ;;
            *)
                if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#DOCS_CATEGORY_ORDER[@]} )); then
                    docs_browse_category "${DOCS_CATEGORY_ORDER[$((selection - 1))]}"
                else
                    warn "⚠️ Opción inválida"
                fi
                ;;
        esac
    done
}

# Standalone execution support (outside jb / bootstrap)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    docs_main
fi
