

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

    if (( IS_APPLE_SILICON )); then

        if pgrep oahd >/dev/null 2>&1; then
            ROSETTA_INSTALLED=1
        fi
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

# =========================
# Hardware info
# =========================

detect_model() {

    MODEL=$(system_profiler SPHardwareDataType 2>/dev/null \
        | awk -F': ' '/Model Name/ {print $2; exit}')

    if [[ -z "$MODEL" ]]; then
        MODEL="$(sysctl -n hw.model 2>/dev/null || echo Unknown)"
    fi
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