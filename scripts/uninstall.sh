#!/usr/bin/env bash
# ==============================================================================
# scripts/uninstall.sh
# Clean Uninstaller for Concurrent Wi-Fi Hotspot & KDE Plasma 6 Applet
# ==============================================================================
set -euo pipefail

CLI_TARGET="/usr/local/bin/wifi-hotspot"
UI_HELPER_TARGET="/usr/local/bin/wifi-hotspot-toggle-ui"
CONF_TARGET="/etc/wifi-hotspot.conf"
SUDOERS_TARGET="/etc/sudoers.d/wifi-hotspot"
DESKTOP_DIR="${HOME}/.local/share/applications"
DESKTOP_TARGET="${DESKTOP_DIR}/wifi-hotspot-toggle.desktop"
PLASMOID_ID="org.local.wifihotspot"
PLASMOID_DEST="${HOME}/.local/share/plasma/plasmoids/${PLASMOID_ID}"

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
if command -v kpackagetool6 >/dev/null 2>&1 && kpackagetool6 -t Plasma/Applet --list 2>/dev/null | grep -qx "${PLASMOID_ID}"; then
    log "Removing KDE Plasma widget via kpackagetool6..."
    kpackagetool6 -t Plasma/Applet -r "${PLASMOID_ID}" || rm -rf "${PLASMOID_DEST}"
elif [ -d "${PLASMOID_DEST}" ]; then
    log "Removing KDE Plasma widget from ${PLASMOID_DEST}..."
    rm -rf "${PLASMOID_DEST}"
fi

# 3. Remove Desktop Launcher Entry
if [ -f "${DESKTOP_TARGET}" ]; then
    log "Removing desktop entry ${DESKTOP_TARGET}..."
    rm -f "${DESKTOP_TARGET}"
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
    fi
fi

# 4. Remove Binaries & Sudoers
for bin_path in "${CLI_TARGET}" "${UI_HELPER_TARGET}"; do
    if [ -f "${bin_path}" ]; then
        log "Removing binary ${bin_path}..."
        sudo rm -f "${bin_path}"
    fi
done

if [ -f "${SUDOERS_TARGET}" ]; then
    log "Removing sudoers rule ${SUDOERS_TARGET}..."
    sudo rm -f "${SUDOERS_TARGET}"
fi

# 5. Optional Config Removal
if [ -f "${CONF_TARGET}" ]; then
    warn "Configuration file preserved at ${CONF_TARGET}."
    warn "To delete it permanently, run: sudo rm -f ${CONF_TARGET}"
fi

# 6. Plasma Shell Notice
if pgrep -x plasmashell >/dev/null 2>&1; then
    warn "To clear any remaining panel widget cache, restart Plasma shell with:"
    echo "  systemctl --user restart plasma-plasmashell.service"
fi

log "Uninstallation finished cleanly."
