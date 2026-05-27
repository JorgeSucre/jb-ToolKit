

#!/bin/bash

# =========================
# Storage analysis
# =========================

LARGE_FILES_FOUND=0

# =========================
# Helpers
# =========================

human_size() {

    local size_mb="$1"

    if [[ "$size_mb" -ge 1024 ]]; then

        awk "BEGIN {printf \"%.1fGB\", $size_mb/1024}"

    else

        printf "%sMB" "$size_mb"
    fi
}

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

is_relevant_large_file() {

    local file="$1"

    case "$file" in

        *.iso) return 0 ;;
        *.dmg) return 0 ;;
        *.zip) return 0 ;;
        *.tar) return 0 ;;
        *.gz) return 0 ;;
        *.pkg) return 0 ;;
        *.ipsw) return 0 ;;
        *.mp4) return 0 ;;
        *.mov) return 0 ;;
        *.mkv) return 0 ;;
        *.utm) return 0 ;;
        *.pvm) return 0 ;;
        *.vmdk) return 0 ;;
        *.qcow2) return 0 ;;

    esac

    return 1
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

    while IFS= read -r file; do

        [[ -z "$file" ]] && continue

        if is_excluded_path "$file"; then
            continue
        fi

        if ! is_relevant_large_file "$file"; then
            continue
        fi

        local size_mb

        size_mb=$(du -sm "$file" 2>/dev/null \
            | awk '{print $1+0}')

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

        local filename

        filename=$(basename "$file")

        printf "• %s (%s)\n" \
            "$filename" \
            "$(human_size "$size_mb")"

    done < <(
        find ~/Downloads \
            ~/Movies \
            ~/Desktop \
            ~/Documents \
            /Applications \
            -type f \
            -size +1024M \
            2>/dev/null
    )

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
            echo "LaunchAgents detectados:"
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