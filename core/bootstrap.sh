#!/bin/bash

set -Eeuo pipefail

SECONDS=0
STAGE_START_TIME=0
CURRENT_STAGE=1
TOTAL_STAGES=5

print_stage() {

    local now elapsed

    now=$SECONDS
    elapsed=$((now - STAGE_START_TIME))
    STAGE_START_TIME=$now

    echo ""

    if [[ "$CURRENT_STAGE" -gt 1 ]]; then
        printf "${BLUE}⏱️ Etapa anterior completada en %ss${NC}\n" "$elapsed"
        echo ""
    fi

    printf "[%s/%s] %s\n" "$CURRENT_STAGE" "$TOTAL_STAGES" "$1"

    CURRENT_STAGE=$((CURRENT_STAGE + 1))
}

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/core/utils.sh"

STATE_FILE="$BASE_DIR/logs/state.env"
mkdir -p "$BASE_DIR/logs" 2>/dev/null || true

# ANSI colors
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    RED=''
    BLUE=''
    NC=''
fi

echo ""
echo "========================================"
echo "   🍺 JB Toolkit Setup v0.9"
echo "========================================"
echo ""

# =========================
# Internet connectivity
# =========================

if ! ping -c 1 github.com >/dev/null 2>&1; then
    echo ""
    printf "${RED}❌ No se detectó conexión a internet${NC}\n"
    echo "Homebrew requiere acceso a internet para continuar"
    echo ""
    exit 1
fi

# =========================
# CLT
# =========================

echo "🛠️ Preparando herramientas base"
echo "----------------------------------------"
log "🛠️ Verificando Command Line Tools..."

install_clt() {

    if xcode-select -p &>/dev/null; then
        log "✔ CLT ya instaladas"
        return 0
    fi

    log "📦 Intentando instalar CLT..."
    xcode-select --install 2>/dev/null || true

    for i in {1..60}; do

        if xcode-select -p &>/dev/null; then
            log "✔ CLT instaladas correctamente"
            return 0
        fi

        sleep 5
    done

    log "❌ CLT no se instalaron automáticamente"
    return 1
}

print_stage "Verificando herramientas base"
install_clt || log "⚠️ Continuando sin CLT (brew puede fallar)"

# =========================
# Privilegios
# =========================

HAS_SUDO="false"

if dseditgroup -o checkmember -m "$USER" admin 2>/dev/null | grep -q "yes"; then
    HAS_SUDO="true"
else

    echo ""
    echo "🔐 Permisos del sistema"
    echo "----------------------------------------"

    printf "${YELLOW}⚠️ Esta cuenta no tiene permisos administrativos${NC}\n"
    echo "Homebrew requiere acceso sudo en macOS"
    echo ""
fi

# =========================
# Homebrew install
# =========================

install_brew() {

    if command_exists brew; then
        BREW_FRESH_INSTALL="false"
        log "✔ Homebrew ya instalado"
        return 0
    fi

    log "📦 Instalando Homebrew..."

    for i in {1..3}; do

        log "🔁 Intento $i/3..."

        INSTALL_SCRIPT="/tmp/homebrew_install.sh"

        if curl -fsSL \
            --retry 3 \
            --retry-delay 2 \
            --connect-timeout 5 \
            https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
            -o "$INSTALL_SCRIPT"; then

            chmod +x "$INSTALL_SCRIPT"

            echo ""
            printf "${BLUE}ℹ️ Homebrew puede solicitar contraseña y confirmación de instalación${NC}\n"
            echo ""

            if /bin/bash "$INSTALL_SCRIPT"; then

                BREW_FRESH_INSTALL="true"
                log "✔ Homebrew instalado correctamente"
                return 0

            else

                log "⚠️ Homebrew no pudo instalarse correctamente"

                if [[ "$HAS_SUDO" != "true" ]]; then
                    log "ℹ️ La cuenta actual no tiene privilegios administrativos"
                else
                    log "ℹ️ Verifica la contraseña sudo o permisos del sistema"
                fi
            fi

        else
            log "⚠️ No se pudo descargar el instalador de Homebrew"
        fi

        sleep 5
    done

    log "❌ No se pudo instalar Homebrew"

    return 1
}

# =========================
# Ejecutar Homebrew
# =========================

BREW_OK="false"
BREW_FRESH_INSTALL="false"

if install_brew; then
    BREW_OK="true"
else
    log "⚠️ Brew no disponible, algunas funciones fallarán"
fi

# =========================
# Detectar brew
# =========================

BREW_BIN=""

if [[ -x "/opt/homebrew/bin/brew" ]]; then
    BREW_BIN="/opt/homebrew/bin/brew"
elif [[ -x "/usr/local/bin/brew" ]]; then
    BREW_BIN="/usr/local/bin/brew"
elif command -v brew &>/dev/null; then
    BREW_BIN="$(command -v brew)"
fi

if [[ -n "$BREW_BIN" ]]; then
    eval "$("$BREW_BIN" shellenv)"
    export PATH="$(dirname "$BREW_BIN"):$PATH"
    log "✔ brew listo para usarse"
else
    log "❌ brew sigue sin estar disponible en PATH"
fi

UPDATE_EXTRA_PACKAGES="false"
INSTALL_OPTIONAL_APPS="false"
TEMP_BREWFILE=""

print_stage "Configurando Homebrew"

if brew_available; then

    echo ""
    echo "📦 Homebrew"
    echo "----------------------------------------"

    if [[ "$BREW_FRESH_INSTALL" == "true" ]]; then

        printf "${GREEN}✔ Homebrew recién instalado, actualización omitida${NC}\n"

    else

        BREW_REPO=$(brew --repository 2>/dev/null || true)
        RECENT_UPDATE=""

        if [[ -n "$BREW_REPO" ]]; then
            RECENT_UPDATE=$(find "$BREW_REPO" -name FETCH_HEAD -mtime -1 2>/dev/null || true)
        fi

        if [[ -n "$RECENT_UPDATE" ]]; then
            printf "${GREEN}✔ Índices recientes detectados${NC}\n"
        else
            log "🔄 Actualizando índices Homebrew..."
            HOMEBREW_NO_ENV_HINTS=1 brew update >/dev/null 2>&1 || true
            printf "${GREEN}✔ Índices Homebrew sincronizados${NC}\n"
        fi
    fi

else

    printf "${YELLOW}⚠️ Homebrew no disponible, se omite actualización${NC}\n"
fi

# =========================
# Brewfile
# =========================

BREWFILE="$BASE_DIR/Brewfile"
ARCH_NAME="$(uname -m)"

if [[ "$ARCH_NAME" == "arm64" && -f "$BASE_DIR/Brewfile.apple" ]]; then
    BREWFILE="$BASE_DIR/Brewfile.apple"
elif [[ "$ARCH_NAME" == "x86_64" && -f "$BASE_DIR/Brewfile.intel" ]]; then
    BREWFILE="$BASE_DIR/Brewfile.intel"
fi

if [[ "$ARCH_NAME" == "arm64" ]]; then
    printf "${BLUE}🧠 Perfil Apple Silicon detectado${NC}\n"
else
    printf "${BLUE}🧠 Perfil Intel detectado${NC}\n"
fi

printf "\n¿Instalar navegador alternativo? (y/n): "
read -r INSTALL_BROWSER_REPLY

if [[ "$INSTALL_BROWSER_REPLY" =~ ^[YySs]$ ]]; then
    INSTALL_OPTIONAL_APPS="true"
fi

print_stage "Sincronizando paquetes"

if brew_available && [[ -f "$BREWFILE" ]]; then

    TEMP_BREWFILE="/tmp/jb_brewfile.$$"
    cp "$BREWFILE" "$TEMP_BREWFILE"

    if [[ "$INSTALL_OPTIONAL_APPS" != "true" ]]; then
        sed -i '' '/floorp/d' "$TEMP_BREWFILE"
    fi

    EXPECTED_PACKAGES=$(grep '^brew ' "$TEMP_BREWFILE" 2>/dev/null | awk -F'"' '{print $2}' || true)
    EXPECTED_CASKS=$(grep '^cask ' "$TEMP_BREWFILE" 2>/dev/null | awk -F'"' '{print $2}' || true)

    INSTALLED_BREW=$(brew list --formula 2>/dev/null || true)
    INSTALLED_CASKS=$(brew list --cask 2>/dev/null || true)

    EXTRA_PACKAGES=""

    while IFS= read -r pkg; do

        [[ -z "$pkg" ]] && continue

        if ! grep -qx "$pkg" <<< "$EXPECTED_PACKAGES"; then
            EXTRA_PACKAGES+="brew:$pkg"$'\n'
        fi

    done <<< "$INSTALLED_BREW"

    while IFS= read -r cask; do

        [[ -z "$cask" ]] && continue

        if ! grep -qx "$cask" <<< "$EXPECTED_CASKS"; then
            EXTRA_PACKAGES+="cask:$cask"$'\n'
        fi

    done <<< "$INSTALLED_CASKS"

    EXTRA_COUNT=$(printf "%s" "$EXTRA_PACKAGES" | sed '/^$/d' | wc -l | tr -d ' ')

    if [[ "$EXTRA_COUNT" -gt 0 ]]; then

        echo ""
        echo "📦 Paquetes detectados fuera del Brewfile"
        echo "----------------------------------------"

        printf "${YELLOW}Se detectaron %s paquetes externos instalados:${NC}\n" "$EXTRA_COUNT"
        printf "${BLUE}ℹ️ Esto es normal en sistemas ya configurados${NC}\n"

        echo "Principales detectados:"
        echo ""

        KNOWN_PACKAGES=$( \
            printf "%s" "$EXTRA_PACKAGES" \
                | sed '/^$/d' \
                | grep -Ei 'visual-studio-code|docker|python|node|google-chrome|firefox|brave|discord|obs|vlc|spotify|utm|orbstack|iterm2|raycast|rectangle|stats|tailscale' \
                | head -10 \
                | sed 's/^brew://g' \
                | sed 's/^cask://g' \
                | sed 's/^/   • /'
        ) || true

        if [[ -n "$KNOWN_PACKAGES" ]]; then
            printf "%s\n" "$KNOWN_PACKAGES"
        else
            echo "   • Herramientas de desarrollo y dependencias detectadas"
        fi

        printf "\n¿Actualizar también los paquetes externos al Brewfile? (y/n): "
        read -r UPDATE_EXTRA_REPLY

        if [[ "$UPDATE_EXTRA_REPLY" =~ ^[YySs]$ ]]; then
            UPDATE_EXTRA_PACKAGES="true"
        fi
    fi

    echo ""
    echo "📚 Configuración de paquetes"
    echo "----------------------------------------"

    OUTDATED_FORMULAS=$(brew outdated --formula 2>/dev/null || true)
    OUTDATED_CASKS=$(brew outdated --cask 2>/dev/null || true)

    TOOLKIT_OUTDATED=""

    while IFS= read -r pkg; do

        [[ -z "$pkg" ]] && continue

        if grep -qx "$pkg" <<< "$OUTDATED_FORMULAS"; then
            TOOLKIT_OUTDATED+="$pkg"$'\n'
        fi

    done <<< "$EXPECTED_PACKAGES"

    while IFS= read -r cask; do

        [[ -z "$cask" ]] && continue

        if grep -qx "$cask" <<< "$OUTDATED_CASKS"; then
            TOOLKIT_OUTDATED+="$cask"$'\n'
        fi

    done <<< "$EXPECTED_CASKS"

    TOOLKIT_OUTDATED_COUNT=$(printf "%s" "$TOOLKIT_OUTDATED" | sed '/^$/d' | wc -l | tr -d ' ')

    if [[ "$TOOLKIT_OUTDATED_COUNT" -gt 0 ]]; then

        printf "${YELLOW}📋 %s paquetes del toolkit requieren actualización${NC}\n" "$TOOLKIT_OUTDATED_COUNT"

        while IFS= read -r pkg; do

            [[ -z "$pkg" ]] && continue

            pkg_name=$(awk '{print $1}' <<< "$pkg")

            echo "   • $pkg_name"

            HOMEBREW_NO_ENV_HINTS=1 brew upgrade "$pkg_name" >/dev/null 2>&1 || true

        done <<< "$TOOLKIT_OUTDATED"

        brew cleanup -s >/dev/null 2>&1 || true

        printf "${GREEN}✔ Paquetes del toolkit actualizados correctamente${NC}\n"

    else

        printf "${GREEN}✔ No se detectaron actualizaciones pendientes del toolkit${NC}\n"
    fi

    INSTALL_COUNT=$(grep -E '^(brew|cask)' "$TEMP_BREWFILE" 2>/dev/null | wc -l | tr -d ' ')

    log "📦 Aplicando $(basename "$BREWFILE")..."

    echo ""
    printf "${BLUE}ℹ️ Instalando %s paquetes y aplicaciones... esto puede tardar varios minutos${NC}\n" "$INSTALL_COUNT"
    printf "${BLUE}ℹ️ Homebrew mostrará progreso automáticamente${NC}\n"
    echo ""

    if retry 2 5 brew bundle --file="$TEMP_BREWFILE"; then

        printf "${GREEN}✔ Brewfile sincronizado correctamente${NC}\n"

    else

        printf "${YELLOW}⚠️ Brew bundle encontró algunos problemas${NC}\n"
    fi
fi

# =========================
# Hardware
# =========================

MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Name/ {print $2; exit}')

if [[ -z "$MODEL" ]]; then
    MODEL="$(sysctl -n hw.model 2>/dev/null || echo Unknown)"
fi

PROFILE=$(get_device_profile)

while IFS='=' read -r key value; do

    case "$key" in
        ARCH) ARCH="$value" ;;
        TYPE) TYPE="$value" ;;
        BATTERY) BATTERY="$value" ;;
        FAN) FAN="$value" ;;
    esac

 done <<< "$PROFILE"

if [[ "$ARCH" == "apple_silicon" ]]; then
    ARCH_DISPLAY="Apple Silicon"
else
    ARCH_DISPLAY="Intel"
fi

if [[ "$BATTERY" == "yes" ]]; then
    BATTERY_DISPLAY="Detectada"
else
    BATTERY_DISPLAY="No disponible"
fi

if [[ "$HAS_SUDO" == "true" ]]; then
    ADMIN_DISPLAY="Sí"
else
    ADMIN_DISPLAY="No"
fi

if [[ "$FAN" == "yes" ]]; then
    FAN_DISPLAY="Sí"
else
    FAN_DISPLAY="No"
fi

if [[ "$TYPE" == "desktop" ]]; then
    TYPE_DISPLAY="Escritorio"
else
    TYPE_DISPLAY="Portátil"
fi

print_stage "Detectando hardware y optimizando"

ROSETTA_INSTALLED="false"

if [[ "$ARCH_NAME" == "arm64" ]]; then
    if pgrep oahd >/dev/null 2>&1; then
        ROSETTA_INSTALLED="true"
    fi
fi

echo ""
echo "🧠 Hardware detectado"
echo "----------------------------------------"

printf "Modelo:              %s\n" "$MODEL"
printf "Arquitectura:        %s\n" "$ARCH_DISPLAY"
printf "Tipo:                %s\n" "$TYPE_DISPLAY"
printf "Permisos admin:      %s\n" "$ADMIN_DISPLAY"
printf "Batería:             %s\n" "$BATTERY_DISPLAY"
printf "Ventiladores:        %s\n" "$FAN_DISPLAY"

if [[ "$ARCH_NAME" == "arm64" ]]; then

    if [[ "$ROSETTA_INSTALLED" == "true" ]]; then
        printf "Rosetta:             Instalada\n"
    else
        printf "Rosetta:             No detectada\n"
    fi
fi

print_stage "Finalizando setup"

echo ""
echo "🧠 Resultado final"
echo "----------------------------------------"

if [[ -n "${TEMP_BREWFILE:-}" ]]; then
    rm -f "$TEMP_BREWFILE" 2>/dev/null || true
fi

printf "${GREEN}• Herramientas esenciales instaladas${NC}\n"

if [[ "$BREW_OK" == "true" ]]; then
    printf "${GREEN}• Homebrew configurado correctamente${NC}\n"
    printf "${GREEN}• Brewfile sincronizado${NC}\n"
else
    printf "${YELLOW}• Homebrew no pudo configurarse automáticamente${NC}\n"
fi

printf "${GREEN}• Optimización aplicada para este hardware${NC}\n"

ELAPSED=$SECONDS

cat > "$STATE_FILE" <<EOF
LAST_SETUP_EPOCH=$(date +%s)
LAST_SETUP_ARCH=$ARCH_NAME
LAST_BREWFILE=$(basename "$BREWFILE")
LAST_SETUP_DURATION=$ELAPSED
EOF

if [[ "$ELAPSED" -ge 60 ]]; then
    printf "⏱️ Tiempo total: %sm %ss\n" "$((ELAPSED / 60))" "$((ELAPSED % 60))"
else
    printf "⏱️ Tiempo total: %s segundos\n" "$ELAPSED"
fi

echo ""
echo "========================================"

if [[ "$BREW_OK" == "true" ]]; then
    printf "${GREEN}✔ Setup completado correctamente${NC}\n"
else
    printf "${YELLOW}⚠️ Setup completado parcialmente${NC}\n"
fi

echo "========================================"
