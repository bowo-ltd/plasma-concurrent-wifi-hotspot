#!/usr/bin/env bash
# ==============================================================================
# scripts/install.sh
# Production Installer for Concurrent Wi-Fi Hotspot & KDE Plasma 6 Applet
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CLI_TARGET="/usr/local/bin/wifi-hotspot"
UI_HELPER_TARGET="/usr/local/bin/wifi-hotspot-toggle-ui"
CONF_TARGET="/etc/wifi-hotspot.conf"
SUDOERS_TARGET="/etc/sudoers.d/wifi-hotspot"
DESKTOP_DIR="${HOME}/.local/share/applications"
DESKTOP_TARGET="${DESKTOP_DIR}/wifi-hotspot-toggle.desktop"
PLASMOID_ID="org.local.wifihotspot"
PLASMOID_SRC="${REPO_ROOT}/plasmoid/${PLASMOID_ID}"
PLASMOID_DEST="${HOME}/.local/share/plasma/plasmoids/${PLASMOID_ID}"

log() { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[-]\033[0m %s\n' "$*" >&2; exit 1; }

echo "======================================================================"
echo "Installing Concurrent Wi-Fi Hotspot & KDE Plasma 6 Panel Applet"
echo "======================================================================"

# 1. Check Dependencies
log "Verifying system dependencies (iw, ip, hostapd, wpa_supplicant, dnsmasq, nft)..."
MISSING=()
for bin in iw ip hostapd wpa_supplicant dnsmasq nft; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        MISSING+=("$bin")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    warn "The following recommended packages are missing: ${MISSING[*]}"
    warn "On Arch Linux: sudo pacman -S iw iproute2 hostapd wpa_supplicant dnsmasq nftables"
    warn "On Debian/Ubuntu: sudo apt install iw iproute2 hostapd wpasupplicant dnsmasq nftables"
fi

# 2. Install CLI Daemon & Desktop Toggle Wrapper
log "Installing ${CLI_TARGET} and ${UI_HELPER_TARGET}..."
sudo install -m 0755 "${REPO_ROOT}/scripts/wifi-hotspot" "${CLI_TARGET}"
sudo install -m 0755 "${REPO_ROOT}/scripts/wifi-hotspot-toggle-ui" "${UI_HELPER_TARGET}"

# 3. Setup Configuration File
if [ ! -f "${CONF_TARGET}" ]; then
    log "Creating default configuration at ${CONF_TARGET}..."
    sudo install -m 0600 "${REPO_ROOT}/configs/wifi-hotspot.conf.example" "${CONF_TARGET}"
    log "Please review and edit ${CONF_TARGET} with your desired SSID, passphrase, and interface."
else
    log "Existing configuration preserved at ${CONF_TARGET}."
fi

# 4. Setup Sudoers Rule for Passwordless Toggle & Credential Reveal
if [ ! -f "${SUDOERS_TARGET}" ]; then
    if ! command -v visudo >/dev/null 2>&1 || sudo visudo -cf "${REPO_ROOT}/configs/sudoers-wifi-hotspot.example" >/dev/null 2>&1; then
        log "Setting up passwordless sudo rule at ${SUDOERS_TARGET}..."
        sudo install -m 0440 "${REPO_ROOT}/configs/sudoers-wifi-hotspot.example" "${SUDOERS_TARGET}"
    else
        warn "visudo validation failed on sudoers template; skipping ${SUDOERS_TARGET} (pkexec fallback remains available)."
    fi
fi

# 5. Install Desktop Launcher Entry
log "Installing desktop entry at ${DESKTOP_TARGET}..."
mkdir -p "${DESKTOP_DIR}"
install -m 0644 "${REPO_ROOT}/configs/wifi-hotspot-toggle.desktop" "${DESKTOP_TARGET}"
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
fi

# 6. Install KDE Plasma 6 Plasmoid
log "Installing Plasmoid (${PLASMOID_ID})..."
if command -v kpackagetool6 >/dev/null 2>&1; then
    if kpackagetool6 -t Plasma/Applet --list 2>/dev/null | grep -qx "${PLASMOID_ID}"; then
        kpackagetool6 -t Plasma/Applet -u "${PLASMOID_SRC}"
    else
        mkdir -p "$(dirname "${PLASMOID_DEST}")"
        kpackagetool6 -t Plasma/Applet -i "${PLASMOID_SRC}"
    fi
else
    mkdir -p "$(dirname "${PLASMOID_DEST}")"
    rm -rf "${PLASMOID_DEST}"
    cp -a "${PLASMOID_SRC}" "${PLASMOID_DEST}"
fi

# 7. Reload Guidance for Plasma Shell
if pgrep -x plasmashell >/dev/null 2>&1; then
    warn "If an existing panel widget was updated and does not reflect QML changes, restart Plasma shell with:"
    echo "  systemctl --user restart plasma-plasmashell.service"
fi

echo "======================================================================"
log "Installation complete!"
echo "You can now add 'Wi-Fi Hotspot' to your KDE Plasma Panel or System Tray:"
echo "  1. Right-click your Plasma panel -> 'Add Widgets...'"
echo "  2. Search for 'Wi-Fi Hotspot' and drag it to your panel or tray."
echo "Or test the CLI directly:"
echo "  wifi-hotspot status"
echo "  sudo wifi-hotspot on"
echo "======================================================================"
