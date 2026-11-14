# Architectural Decision Records (ADRs)

This document records the foundational architectural trade-offs made during the design and implementation of the **Concurrent Linux Wi-Fi Hotspot & Native KDE Plasma 6 Panel Applet**.

---

## ADR-001: Automatic Concurrency Triage (Virtual AP vs. P2P-GO)

### Context:
Consumer Linux Wi-Fi drivers support either Single-Channel Concurrency (SCC) via virtual Access Point interfaces (`type __ap`), Multi-Channel Concurrency (MCC) via Wi-Fi Direct Group Owner (`P2P-GO`), or no concurrency at all. Hardcoding either approach results in driver failures across varying chipsets (Intel AX200 vs Atheros vs Realtek).

### Decision:
Implement an adaptive three-tier concurrency mode (`auto`, `ap`, `p2p`):
1. In `auto` mode, the daemon interrogates `iw dev <iface> link` for upstream frequency and beacon intervals.
2. It attempts to instantiate a virtual AP (`ap0`) synchronized to the identical carrier frequency.
3. If virtual interface allocation yields `EBUSY` or hostapd socket binding fails, the daemon automatically falls back to `wpa_supplicant` Wi-Fi Direct P2P Group Owner (`p2p-wlp4s0-0`), which supports multi-channel frequency arbitration.

### Consequences:
- **Positive**: Maximum hardware compatibility without requiring manual driver patching or user intervention.
- **Negative**: P2P-GO mode generates dynamic interface names that require flexible parsing in firewall and routing rules.

---

## ADR-002: Plasma5Support Executable Engine vs. Custom DBus System Service

### Context:
The KDE Plasma 6 QML applet needs to query daemon state and trigger `on`/`off` mutations from an unprivileged user session. Standard alternatives include:
1. Writing a custom C++ DBus system daemon with Polkit action policies.
2. Using Qt 6 QML's `Plasma5Support.DataSource` with the built-in `executable` data engine.

### Decision:
Adopt `Plasma5Support.DataSource` (`engine: "executable"`) coupled with a strict least-privilege `sudoers` rule (`/etc/sudoers.d/wifi-hotspot`).

### Consequences:
- **Positive**:
  - Zero compilation overhead or C++ build dependencies (pure QML/Kirigami).
  - Portability across Arch Linux, Fedora, openSUSE, and Debian/Ubuntu without custom DBus policy XML files.
  - Sudoers rule restricts execution strictly to `/usr/local/bin/wifi-hotspot`.
- **Negative**: Requires disconnecting command sources manually (`disconnectSource(sourceName)`) inside `onNewData` to avoid memory accumulation over long desktop uptimes.

---

## ADR-003: Ephemeral Nftables Tables vs. Legacy Iptables

### Context:
Enabling NAT masquerade and packet forwarding on Linux typically involves adding rules to `iptables -t nat -A POSTROUTING` and `iptables -A FORWARD`. On developer machines running Docker, Libvirt/KVM, or UFW, modifying legacy iptables frequently breaks container networking or triggers firewall lockouts.

### Decision:
Isolate all hotspot packet filtering and NAT masquerading into an independent, ephemeral Netfilter table: `table ip wifi_hotspot`.

### Consequences:
- **Positive**:
  - Total isolation: zero interaction or collision with UFW, Docker, or Tailscale rules.
  - Atomic cleanup: `nft delete table ip wifi_hotspot` removes all chains and rules in a single atomic kernel transaction on daemon teardown.
- **Negative**: Requires modern kernel (>= 5.x) with `nftables` utility installed.

---

## ADR-004: Porcelain Machine-Readable Output over Heavy JSON Serializers

### Context:
The QML frontend requires real-time telemetry (active status, client counts, frequency, gateway IP). In bash, outputting structured JSON typically requires `jq` or Python runtime dependencies.

### Decision:
Implement a lightweight, shell-native `--porcelain` output format consisting of simple `KEY=VALUE` lines (`HOTSPOT_ACTIVE=1`, `CONNECTED_CLIENTS=2`, etc.).

### Consequences:
- **Positive**:
  - Zero external dependencies in the bash daemon (no `jq` or `python` required).
  - Extremely fast execution (< 25ms total process time for status queries).
  - Trivial, robust string splitting in QML (`line.split("=")`).
- **Negative**: Flattens nested data structures (sufficient for this domain).

---

## ADR-005: Decoupled Plasmoid Template Generator for Future Extension

### Context:
Developers frequently need custom panel widgets in KDE Plasma 6 for other services (Docker controls, VPN toggles, LLM agent monitors), but the lack of official documentation on Plasma 6 QML lifecycle and packaging creates high friction.

### Decision:
Extract the core panel widget patterns into a reusable template boilerplate (`templates/plasma6-panel-widget-template/`) and provide an automated CLI generator script (`scripts/create-plasma-widget.sh`).

### Consequences:
- **Positive**: Converts a single-project solution into an extensible developer platform, allowing rapid creation of new Plasma 6 panel tools in minutes.
- **Negative**: Adds a small maintenance surface for the template files.
