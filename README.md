# nerd-dictation-setup

Configuración optimizada de [nerd-dictation](https://github.com/ideasman42/nerd-dictation) para reconocimiento de voz en español con latencia reducida.

## ⚡ Lo que hace

- Dictado por voz continuo con **VOSK** (offline, español)
- **Latencia reducida** (~50ms vs ~300ms original)
- **Daemon systemd** que arranca automáticamente al iniciar sesión
- **Toggle** con atajo de teclado (Ctrl+Shift+Space) para pausar/reanudar
- **DMIC interno Intel** optimizado (sin saturación)
- Filter-chain de **PipeWire** opcional para reducción de ruido

## 📦 Instalación en PC nueva

```bash
# 1. Clonar este repo
git clone https://github.com/Cecilio1217/nerd-dictation-setup.git
cd nerd-dictation-setup

# 2. Ejecutar instalador
chmod +x install.sh
./install.sh
```

El instalador va preguntando cada paso. Para instalación automática:

```bash
./install.sh --auto
```

Para ver qué haría sin ejecutar nada:

```bash
./install.sh --dry-run
```

## 📋 Qué instala

| Componente | Ruta |
|---|---|
| nerd-dictation (clonado) | `~/nerd-dictation/` |
| Virtualenv con VOSK | `~/nerd-dictation/venv/` |
| Modelo VOSK español | `~/nerd-dictation/vosk-model-small-es/` |
| Systemd service | `~/.config/systemd/user/nerd-dictation.service` |
| Toggle script | `~/.local/bin/nerd-dictation-toggle` |
| Filter-chain (opcional) | `~/.config/pipewire/filter-chain.conf.d/noise-reduction-source.conf` |

## 🎯 Uso diario

- **Ctrl+Shift+Space** — pausar/reanudar dictado
- El servicio arranca automáticamente al iniciar sesión
- Hablás al micrófono y el texto se escribe donde esté el foco

## 🔧 Modificaciones respecto al upstream

- `--latency 5` (vs 10ms) — respuesta más rápida de `parec`
- `block_size = 4000` (vs 1MB) — resultados parciales más frecuentes
- `--idle-time 0.05` (vs 0.3s) — menos latencia entre detecciones
- DMIC gain reducido para evitar saturación

## 📁 Estructura del repo

```
nerd-dictation-setup/
├── install.sh                 # Instalador completo
├── README.md                  # Este archivo
├── systemd/
│   └── nerd-dictation.service # Service de systemd
├── config/
│   ├── nerd-dictation-toggle  # Script para pausar/reanudar
│   ├── alsa/
│   │   └── alsa-controls.txt  # Gains del DMIC
│   └── pipewire/
│       └── noise-reduction-source.conf  # Filtro LADSPA
└── patches/
    └── nerd-dictation-changes.patch  # Parche de latencia
```
