#!/bin/bash

# =========================
# Storage analysis
# =========================

LARGE_FILES_FOUND=0
LARGE_FILES_COUNT=0

# =========================
# Helpers
# =========================

is_excluded_path() {

    local path="$1"

    case "$path" in

        *"/Library/Containers/"*) return 0 ;;
        *"/Library/CloudStorage/"*) return 0 ;;
        *"/iCloud Drive/"*) return 0 ;;
        *"/Dropbox/"*) return 0 ;;
        *"/OneDrive/"*) return 0 ;;
        *"/Google Drive/"*) return 0 ;;
        *"/Parallels/"*) return 0 ;;
        *"/Docker/"*) return 0 ;;

    esac

    return 1
}



# =========================
# Cached storage scan
# =========================

LARGE_FILES_CACHE=""

build_large_files_cache() {

    [[ -n "$LARGE_FILES_CACHE" ]] && return 0

    LARGE_FILES_CACHE=$(find \
        ~/Downloads \
        ~/Movies \
        ~/Desktop \
        ~/Documents \
        /Applications \
        -type f \
        \( \
            -iname "*.iso" -o \
            -iname "*.dmg" -o \
            -iname "*.zip" -o \
            -iname "*.tar" -o \
            -iname "*.gz" -o \
            -iname "*.pkg" -o \
            -iname "*.ipsw" -o \
            -iname "*.mp4" -o \
            -iname "*.mov" -o \
            -iname "*.mkv" -o \
            -iname "*.utm" -o \
            -iname "*.pvm" -o \
            -iname "*.vmdk" -o \
            -iname "*.qcow2" \
        \) \
        -size +1024M \
        2>/dev/null)
}

# =========================
# Cloud sync detection
# =========================

print_cloud_storage_status() {

    print_section "☁️ Sincronización en la nube"

    local found=0

    for service in \
        "~/Library/Mobile Documents" \
        "~/Library/CloudStorage/Dropbox" \
        "~/Library/CloudStorage/GoogleDrive" \
        "~/Library/CloudStorage/OneDrive"; do

        local expanded
        expanded=$(eval echo "$service")

        if [[ -d "$expanded" ]]; then

            found=1

            case "$service" in
                *Mobile*) echo "• iCloud Drive detectado" ;;
                *Dropbox*) echo "• Dropbox detectado" ;;
                *GoogleDrive*) echo "• Google Drive detectado" ;;
                *OneDrive*) echo "• OneDrive detectado" ;;
            esac
        fi

    done

    if [[ "$found" -eq 0 ]]; then
        info "ℹ️ No se detectaron servicios de sincronización relevantes"
    fi
}

# =========================
# Large files detection
# =========================

scan_large_files() {

    print_section "📦 Revisión de almacenamiento"

    local found=0
    build_large_files_cache

    while IFS= read -r file; do

        [[ -z "$file" ]] && continue

        if is_excluded_path "$file"; then
            continue
        fi

        local size_mb
        size_mb=$(dir_size_mb "$file")

        [[ -z "$size_mb" ]] && continue

        if [[ "$size_mb" -lt 1024 ]]; then
            continue
        fi

        if [[ "$found" -eq 0 ]]; then
            echo "Archivos grandes detectados:"
            echo ""
        fi

        found=1
        LARGE_FILES_FOUND=1
        LARGE_FILES_COUNT=$((LARGE_FILES_COUNT + 1))

        local filename

        filename=$(basename "$file")

        printf "• %s (%s)\n" \
            "$filename" \
            "$(human_size "$size_mb")"

    done <<< "$LARGE_FILES_CACHE"

    if [[ "$found" -eq 1 ]]; then
        echo ""
        info "ℹ️ ${LARGE_FILES_COUNT} archivos grandes relevantes detectados"
    fi

    if [[ "$found" -eq 0 ]]; then
        success "✔ No se detectaron archivos grandes relevantes"
    fi
}

# =========================
# LaunchAgents detection
# =========================

scan_launch_agents() {

    print_section "🚀 LaunchAgents personalizados"

    local launch_dir="$HOME/Library/LaunchAgents"

    if [[ ! -d "$launch_dir" ]]; then

        success "✔ No se detectaron LaunchAgents relevantes"
        return
    fi

    local found=0

    while IFS= read -r plist; do

        [[ -z "$plist" ]] && continue

        local name

        name=$(basename "$plist")

        if [[ "$found" -eq 0 ]]; then
            info "LaunchAgents detectados:"
            echo ""
        fi

        found=1

        printf "• %s\n" "$name"

    done < <(
        find "$launch_dir" \
            -name "*.plist" \
            2>/dev/null
    )

    if [[ "$found" -eq 0 ]]; then
        success "✔ No se detectaron LaunchAgents relevantes"
    fi
}

# =========================
# Main storage flow
# =========================

run_storage_analysis() {

    print_cloud_storage_status

    scan_large_files

    scan_launch_agents
}
