

#!/bin/bash

# =========================
# Hardware helpers
# =========================

ARCH_NAME="$(uname -m)"
IS_APPLE_SILICON=0
ROSETTA_INSTALLED=0

if [[ "$ARCH_NAME" == "arm64" ]]; then
    IS_APPLE_SILICON=1
fi

# =========================
# Rosetta
# =========================

detect_rosetta() {

    ROSETTA_INSTALLED=0

    (( IS_APPLE_SILICON )) || return 0

    # Primary: check for the Rosetta runtime binary (fast, filesystem-only)
    if [[ -f "/Library/Apple/usr/share/rosetta/rosetta" ]]; then
        ROSETTA_INSTALLED=1
        return 0
    fi

    # Fallback: query the package database (authoritative but slower)
    if pkgutil --pkg-info com.apple.pkg.RosettaUpdateAuto >/dev/null 2>&1; then
        ROSETTA_INSTALLED=1
    fi
}

# =========================
# Hardware profile
# =========================

load_hardware_profile() {

    PROFILE=$(get_device_profile)

    while IFS='=' read -r key value; do

        case "$key" in
            ARCH) ARCH="$value" ;;
            TYPE) TYPE="$value" ;;
            BATTERY) BATTERY="$value" ;;
            FAN) FAN="$value" ;;
        esac

    done <<< "$PROFILE"
}

detect_machine_family() {
    load_hardware_info

    case "$HARDWARE_NAME" in
        *"MacBook Air"*) MACHINE_FAMILY="macbook_air" ;;
        *"MacBook Pro"*) MACHINE_FAMILY="macbook_pro" ;;
        *"Mac mini"*) MACHINE_FAMILY="mac_mini" ;;
        *"Mac Studio"*) MACHINE_FAMILY="mac_studio" ;;
        *"iMac"*) MACHINE_FAMILY="imac" ;;
        *) MACHINE_FAMILY="other" ;;
    esac
}

# =========================
# Hardware info
# =========================

detect_model() {
    load_hardware_info
    MODEL="${HARDWARE_NAME}"
}

# =========================
# Display labels
# =========================

build_hardware_labels() {

    ARCH_DISPLAY=$([[ "$ARCH" == "apple_silicon" ]] \
        && echo "Apple Silicon" \
        || echo "Intel")

    BATTERY_DISPLAY=$([[ "$BATTERY" == "yes" ]] \
        && echo "Detectada" \
        || echo "No disponible")

    FAN_DISPLAY=$([[ "$FAN" == "yes" ]] \
        && echo "Sí" \
        || echo "No")

    TYPE_DISPLAY=$([[ "$TYPE" == "desktop" ]] \
        && echo "Escritorio" \
        || echo "Portátil")

    if (( HAS_SUDO )); then
        ADMIN_DISPLAY="Sí"
    else
        ADMIN_DISPLAY="No"
    fi
}

# =========================
# Hardware summary
# =========================

print_hardware_summary() {

    detect_model
    load_hardware_profile
    build_hardware_labels

    print_section "🧠 Hardware detectado"

    printf "Modelo:              %s\n" "$MODEL"
    printf "Arquitectura:        %s\n" "$ARCH_DISPLAY"
    printf "Tipo:                %s\n" "$TYPE_DISPLAY"
    printf "Permisos admin:      %s\n" "$ADMIN_DISPLAY"
    printf "Batería:             %s\n" "$BATTERY_DISPLAY"
    printf "Ventiladores:        %s\n" "$FAN_DISPLAY"

    if (( IS_APPLE_SILICON )); then

        if (( ROSETTA_INSTALLED )); then
            printf "Rosetta:             Instalada\n"
        else
            printf "Rosetta:             No detectada\n"
        fi
    fi
}

# =========================
# Optimization summary
# =========================

print_optimization_summary() {

    print_section "🧠 Resumen de configuración"

    if [[ "$BATTERY" == "yes" ]]; then
        success "• Perfil portátil aplicado"
    else
        info "• Perfil de escritorio aplicado"
    fi

    if [[ "$FAN" == "yes" ]]; then
        success "• Herramientas térmicas disponibles"
    else
        info "• Equipo silencioso/sin ventiladores"
    fi

    if (( IS_APPLE_SILICON )); then
        info "• Perfil optimizado para Apple Silicon"
    else
        info "• Perfil optimizado para Intel"
    fi
}
