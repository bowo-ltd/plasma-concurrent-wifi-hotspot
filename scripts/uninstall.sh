#!/usr/bin/env bash
# ==============================================================================
# scripts/uninstall.sh
# Clean Uninstaller for Concurrent Wi-Fi Hotspot & KDE Plasma 6 Applet
# ==============================================================================
set -euo pipefail

CLI_TARGET="/usr/local/bin/wifi-hotspot"
CONF_TARGET="/etc/wifi-hotspot.conf"
SUDOERS_TARGET="/etc/sudoers.d/wifi-hotspot"
PLASMOID_DEST="${HOME}/.local/share/plasma/plasmoids/org.local.wifihotspot"

log() { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

echo "======================================================================"
echo "Uninstalling Concurrent Wi-Fi Hotspot & KDE Plasma 6 Applet"
echo "======================================================================"

# 1. Stop Active Hotspot
if command -v wifi-hotspot >/dev/null 2>&1; then
    log "Stopping any running hotspot session..."
    sudo wifi-hotspot off 2>/dev/null || true
fi

# 2. Remove Plasmoid
if [ -d "${PLASMOID_DEST}" ]; then
    log "Removing KDE Plasma widget from ${PLASMOID_DEST}..."
    rm -rf "${PLASMOID_DEST}"
fi

# 3. Remove Binary & Sudoers
if [ -f "${CLI_TARGET}" ]; then
    log "Removing CLI daemon ${CLI_TARGET}..."
    sudo rm -f "${CLI_TARGET}"
fi

if [ -f "${SUDOERS_TARGET}" ]; then
    log "Removing sudoers rule ${SUDOERS_TARGET}..."
    sudo rm -f "${SUDOERS_TARGET}"
fi

# 4. Optional Config Removal
if [ -f "${CONF_TARGET}" ]; then
    warn "Configuration file preserved at ${CONF_TARGET}."
    warn "To delete it permanently, run: sudo rm -f ${CONF_TARGET}"
fi

# 5. Refresh Plasma Shell
if pgrep -x plasmashell >/dev/null 2>&1; then
    log "Reloading KDE Plasma shell components..."
    if command -v qdbus6 >/dev/null 2>&1; then
        qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell 2>/dev/null || true
    elif command -v qdbus >/dev/null 2>&1; then
        qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell 2>/dev/null || true
    fi
fi

log "Uninstallation finished cleanly."
