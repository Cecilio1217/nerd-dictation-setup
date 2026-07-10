#!/bin/bash
# ============================================================
# nerd-dictation-setup — install script
# ============================================================
# Ejecutar así (desde el directorio del repo):
#   chmod +x install.sh
#   ./install.sh
#
# O en seco para ver qué haría:
#   ./install.sh --dry-run
#
# O auto (sin preguntas):
#   ./install.sh --auto
#
# ============================================================
set -euo pipefail

# ─── Config ─────────────────────────────────────────────────
NERD_DIR="$HOME/nerd-dictation"
VENV_DIR="$NERD_DIR/venv"
MODEL_DIR="$NERD_DIR/vosk-model-small-es"
MODEL_URL="https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip"
MODEL_ZIP="$NERD_DIR/vosk-model-small-es.zip"
REPO_URL="https://github.com/ideasman42/nerd-dictation.git"
PATCH_DIR="$(dirname "$0")/patches"
CONFIG_DIR="$(dirname "$0")/config"
SYSTEMD_DIR="$(dirname "$0")/systemd"
DRY_RUN=false
AUTO=false

# ─── Argumentos ─────────────────────────────────────────────
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --auto)    AUTO=true ;;
    esac
done

# ─── Colores ────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; }
section() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }
run() {
    if $DRY_RUN; then
        echo -e "${YELLOW}[dry-run]${NC} $*"
    else
        "$@"
    fi
}

confirm() {
    if $AUTO; then return 0; fi
    echo -ne "${YELLOW}¿$1? [S/n]${NC} "
    read -r resp
    [[ "$resp" =~ ^[nN] ]] && return 1 || return 0
}

# ═══════════════════════════════════════════════════════════
#  PRERREQUISITOS
# ═══════════════════════════════════════════════════════════
section "1/8 — Prerrequisitos del sistema"

DEPS=(
    xdotool
    python3
    python3-pip
    python3-venv
    pipewire
    pipewire-pulse
    libportaudio2
    libasound2-dev
    alsa-utils
    unzip
    wget
    liblilv-0-5  # para LADSPA en PipeWire filter-chain
)

if $DRY_RUN; then
    info "Paquetes necesarios: ${DEPS[*]}"
elif confirm "Instalar dependencias del sistema (apt install)"; then
    sudo apt update
    sudo apt install -y "${DEPS[@]}"
    info "Dependencias instaladas"
else
    warn "Saltando instalación de dependencias — asegurate de tenerlas"
fi

# ═══════════════════════════════════════════════════════════
#  CLONAR NERD-DICTATION
# ═══════════════════════════════════════════════════════════
section "2/8 — Clonar nerd-dictation"

if [ -d "$NERD_DIR" ]; then
    warn "Ya existe $NERD_DIR"
    if confirm "¿Actualizar repo existente (git pull)?"; then
        run git -C "$NERD_DIR" pull
    fi
else
    run git clone "$REPO_URL" "$NERD_DIR"
    info "Clonado: $NERD_DIR"
fi

# ═══════════════════════════════════════════════════════════
#  APLICAR PARCHE DE LATENCIA
# ═══════════════════════════════════════════════════════════
section "3/8 — Aplicar parche de latencia"

if [ -f "$PATCH_DIR/nerd-dictation-changes.patch" ]; then
    run git -C "$NERD_DIR" apply "$PATCH_DIR/nerd-dictation-changes.patch"
    info "Parche aplicado (block_size=4000, latency=5)"
else
    warn "No se encontró el parche en $PATCH_DIR"
fi

# ═══════════════════════════════════════════════════════════
#  VENV + VOSK
# ═══════════════════════════════════════════════════════════
section "4/8 — Entorno virtual Python + VOSK"

if [ ! -d "$VENV_DIR" ]; then
    run python3 -m venv "$VENV_DIR"
    info "Virtualenv creado"
fi

run "$VENV_DIR/bin/pip" install --upgrade pip
run "$VENV_DIR/bin/pip" install vosk
info "VOSK instalado en el virtualenv"

# Actualizar shebang del script para usar el venv
run sed -i "1s|.*|#!$VENV_DIR/bin/python3|" "$NERD_DIR/nerd-dictation"
info "Shebang actualizado a $VENV_DIR/bin/python3"

# ═══════════════════════════════════════════════════════════
#  MODELO VOSK
# ═══════════════════════════════════════════════════════════
section "5/8 — Descargar modelo VOSK (español pequeño ~58MB)"

if [ -d "$MODEL_DIR" ] && [ -f "$MODEL_DIR/am" ]; then
    info "Modelo ya existe en $MODEL_DIR"
elif confirm "¿Descargar modelo VOSK español"; then
    run wget -O "$MODEL_ZIP" "$MODEL_URL"
    run unzip -o "$MODEL_ZIP" -d "$NERD_DIR"
    run rm -f "$MODEL_ZIP"
    # Mover si quedó en subdirectorio
    if [ -d "$NERD_DIR/vosk-model-small-es-0.42" ]; then
        run mv "$NERD_DIR/vosk-model-small-es-0.42"/* "$MODEL_DIR/"
        run rmdir "$NERD_DIR/vosk-model-small-es-0.42"
    fi
    info "Modelo descargado en $MODEL_DIR"
else
    warn "Saltando descarga del modelo"
    warn "Descargalo manualmente: $MODEL_URL"
    warn "Y descomprimilo en: $MODEL_DIR"
fi

# ═══════════════════════════════════════════════════════════
#  SYSTEMD SERVICE
# ═══════════════════════════════════════════════════════════
section "6/8 — Instalar systemd service"

SERVICE_SRC="$SYSTEMD_DIR/nerd-dictation.service"
SERVICE_DST="$HOME/.config/systemd/user/nerd-dictation.service"

if [ -f "$SERVICE_SRC" ]; then
    run mkdir -p "$(dirname "$SERVICE_DST")"
    run cp "$SERVICE_SRC" "$SERVICE_DST"
    info "Service copiado a $SERVICE_DST"

    run systemctl --user daemon-reload

    if confirm "¿Habilitar e iniciar el servicio ahora"; then
        run systemctl --user enable nerd-dictation.service
        run systemctl --user start nerd-dictation.service
        info "Service habilitado e iniciado"
    fi
else
    warn "No se encontró $SERVICE_SRC"
fi

# ═══════════════════════════════════════════════════════════
#  TOGGLE SCRIPT
# ═══════════════════════════════════════════════════════════
section "7/8 — Instalar toggle script"

run mkdir -p "$HOME/.local/bin"
if [ -f "$CONFIG_DIR/nerd-dictation-toggle" ]; then
    run cp "$CONFIG_DIR/nerd-dictation-toggle" "$HOME/.local/bin/nerd-dictation-toggle"
    run chmod +x "$HOME/.local/bin/nerd-dictation-toggle"
    info "Toggle script: ~/.local/bin/nerd-dictation-toggle"
fi

# PipeWire filter-chain (opcional)
if [ -f "$CONFIG_DIR/pipewire/noise-reduction-source.conf" ]; then
    run mkdir -p "$HOME/.config/pipewire/filter-chain.conf.d"
    run cp "$CONFIG_DIR/pipewire/noise-reduction-source.conf" \
        "$HOME/.config/pipewire/filter-chain.conf.d/noise-reduction-source.conf"
    info "PipeWire filter-chain copiada"
    if confirm "¿Recargar PipeWire para activar filter-chain"; then
        run systemctl --user restart pipewire
        info "PipeWire recargado"
    fi
fi

# ═══════════════════════════════════════════════════════════
#  ALSA / POST-INSTALL INFO
# ═══════════════════════════════════════════════════════════
section "8/8 — Configuración manual restante"

echo -e "${YELLOW}── ALSA Gains (DMIC) ──────────────────────${NC}"
echo "Ejecutar para evitar saturación del micrófono interno:"
echo ""
echo "  amixer -c 0 cset numid=41 35   # Dmic0 Capture Volume"
echo "  amixer -c 0 cset numid=44 35   # Dmic1 Capture Volume"
echo "  amixer -c 0 cset numid=8 1     # Mic Boost (30dB→10dB)"
echo "  amixer -c 0 cset numid=6 45    # Capture Volume"
echo ""
echo "Para persistir: sudo alsactl store"
echo ""

echo -e "${YELLOW}── Hotkey (KDE) ────────────────────────────${NC}"
echo "Para asignar Ctrl+Shift+Space al toggle:"
echo "  1. Preferencias del Sistema → Atajos de teclado"
echo "  2. Atajos personalizados → Editar → Nuevo → Atajo global → Comando/URL"
echo "  3. Nombre: nerd-dictation toggle"
echo "  4. Comando: $HOME/.local/bin/nerd-dictation-toggle"
echo "  5. Asignar la tecla: Ctrl+Shift+Space"
echo ""

echo -e "${GREEN}━━━ Instalación completada ━━━${NC}"
echo ""
echo "Comandos útiles:"
echo "  systemctl --user status nerd-dictation     # Ver estado del servicio"
echo "  journalctl --user -u nerd-dictation -f     # Ver logs en vivo"
echo "  ~/.local/bin/nerd-dictation-toggle         # Probar toggle manual"
echo "  amixer -c 0 -V capture                     # Monitorear niveles DMIC"
echo ""

if ! $DRY_RUN; then
    info "¡Listo! Si el service está corriendo, deberías poder dictar."
    info "Si no, revisá los logs con: journalctl --user -u nerd-dictation -f"
fi
