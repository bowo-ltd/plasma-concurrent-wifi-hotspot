#!/usr/bin/env bash
# ==============================================================================
# scripts/create-plasma-widget.sh
# Interactive & CLI Generator for Native KDE Plasma 6 Panel Widgets
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE_DIR="${REPO_ROOT}/templates/plasma6-panel-widget-template"

log() { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[-]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Scaffold a production-grade KDE Plasma 6 panel widget boilerplate.

Options:
  -i, --id <applet_id>       Unique reverse-DNS ID (e.g. org.user.mywidget)
  -n, --name <name>          Human-readable display name (e.g. "My Service Monitor")
  -d, --desc <description>   Short summary of applet purpose
  --icon <freedesktop_icon>  System icon name (default: "applications-system")
  -a, --author <author>      Author name (default: current user)
  -o, --output <dir>         Target directory (default: ~/.local/share/plasma/plasmoids/<applet_id>)
  -h, --help                 Show this help message
EOF
    exit 0
}

APPLET_ID=""
APPLET_NAME=""
APPLET_DESC=""
APPLET_ICON="applications-system"
AUTHOR_NAME="${USER:-Developer}"
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--id) APPLET_ID="$2"; shift 2 ;;
        -n|--name) APPLET_NAME="$2"; shift 2 ;;
        -d|--desc) APPLET_DESC="$2"; shift 2 ;;
        --icon) APPLET_ICON="$2"; shift 2 ;;
        -a|--author) AUTHOR_NAME="$2"; shift 2 ;;
        -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) err "Unknown argument: $1" ;;
    esac
done

echo "======================================================================"
echo "KDE Plasma 6 Panel Widget Generator (S2P v2.0 Tooling)"
echo "======================================================================"

# Interactive Prompt if missing parameters
if [ -z "${APPLET_ID}" ]; then
    read -rp "Enter Applet Unique ID (e.g. org.local.systemguard): " APPLET_ID
fi
if [ -z "${APPLET_NAME}" ]; then
    read -rp "Enter Applet Display Name (e.g. System Guard): " APPLET_NAME
fi
if [ -z "${APPLET_DESC}" ]; then
    read -rp "Enter Applet Description: " APPLET_DESC
fi

[ -z "${APPLET_ID}" ] && err "Applet ID cannot be empty."
[ -z "${APPLET_NAME}" ] && err "Applet Name cannot be empty."
[ -z "${APPLET_DESC}" ] && APPLET_DESC="Custom panel widget for KDE Plasma 6"

if [ -z "${OUTPUT_DIR}" ]; then
    OUTPUT_DIR="${HOME}/.local/share/plasma/plasmoids/${APPLET_ID}"
fi

log "Creating widget structure at: ${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}/contents/ui"

# Copy and substitute placeholders
sed -e "s|{{APPLET_ID}}|${APPLET_ID}|g" \
    -e "s|{{APPLET_NAME}}|${APPLET_NAME}|g" \
    -e "s|{{APPLET_DESCRIPTION}}|${APPLET_DESC}|g" \
    -e "s|{{APPLET_ICON}}|${APPLET_ICON}|g" \
    -e "s|{{AUTHOR_NAME}}|${AUTHOR_NAME}|g" \
    "${TEMPLATE_DIR}/metadata.json" > "${OUTPUT_DIR}/metadata.json"

sed -e "s|{{APPLET_ID}}|${APPLET_ID}|g" \
    -e "s|{{APPLET_NAME}}|${APPLET_NAME}|g" \
    -e "s|{{APPLET_ICON}}|${APPLET_ICON}|g" \
    "${TEMPLATE_DIR}/contents/ui/main.qml" > "${OUTPUT_DIR}/contents/ui/main.qml"

log "Widget generated successfully!"
echo "----------------------------------------------------------------------"
echo "Package Details:"
echo "  • ID          : ${APPLET_ID}"
echo "  • Name        : ${APPLET_NAME}"
echo "  • Path        : ${OUTPUT_DIR}"
echo ""
echo "How to Test Live:"
echo "  1. Test in isolated window:"
echo "     plasmawindowed ${APPLET_ID}"
echo ""
echo "  2. Reload KDE Plasma Shell to pick up changes:"
echo "     qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell"
echo ""
echo "  3. Add to your panel:"
echo "     Right-click Panel -> 'Add Widgets...' -> Search for '${APPLET_NAME}'"
echo "----------------------------------------------------------------------"
