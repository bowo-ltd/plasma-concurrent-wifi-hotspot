import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    property bool hotspotActive: false
    property bool isBusy: false
    property string activeMode: ""
    property string hotspotIface: ""
    property string activeSsid: ""
    property string activeChannel: ""
    property string activeFreq: ""
    property string gatewayIp: ""
    property string upstreamIface: "wlp4s0"
    property string upstreamFreq: ""
    property string upstreamChannel: ""
    property string connectedClients: "0"
    property string revealedPass: ""
    property string errorMessage: ""
    property string selectedMode: "auto"

    readonly property bool inPanel: [
        PlasmaCore.Types.TopEdge,
        PlasmaCore.Types.RightEdge,
        PlasmaCore.Types.BottomEdge,
        PlasmaCore.Types.LeftEdge,
    ].includes(Plasmoid.location)

    readonly property string activeModeLabel: {
        if (activeMode === "p2p") {
            return "P2P-GO (Multi-Channel)";
        }
        if (activeMode === "ap") {
            return "AP (Virtual __ap)";
        }
        return activeMode;
    }

    readonly property string statusCmd: "/usr/local/bin/wifi-hotspot status --porcelain"
    readonly property string passCmd: "sudo -n /usr/local/bin/wifi-hotspot status --porcelain"

    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.busy: root.isBusy
    Plasmoid.icon: {
        if (root.hotspotActive) {
            return "network-wireless-hotspot";
        }
        return "network-wireless-hotspot-symbolic";
    }

    toolTipMainText: root.hotspotActive
        ? ("Wi-Fi Hotspot: ON (" + (root.activeMode === "p2p" ? "P2P-GO" : "AP") + ")")
        : "Wi-Fi Hotspot: OFF"
    toolTipSubText: {
        if (root.hotspotActive) {
            return root.activeSsid + " · Ch " + root.activeChannel + " (" + root.activeFreq + " MHz) · "
                + root.connectedClients + " client(s)\nParallel with " + root.upstreamIface;
        }
        if (root.upstreamFreq !== "") {
            const band = Number(root.upstreamFreq) >= 5000 ? "5 GHz (P2P-GO fallback ready)" : "2.4 GHz (AP ready)";
            return "Upstream " + root.upstreamIface + ": Ch " + root.upstreamChannel + " · " + band + "\nClick to open Hotspot controls";
        }
        return "Click to open Hotspot controls";
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: root.hotspotActive ? "Turn Hotspot OFF" : "Turn Hotspot ON (Auto)"
            icon.name: "network-wireless-hotspot"
            onTriggered: root.runAction("/usr/local/bin/wifi-hotspot-toggle-ui")
        },
        PlasmaCore.Action {
            text: "Start P2P-GO (Multi-Channel)"
            icon.name: "network-wireless-hotspot-symbolic"
            enabled: !root.hotspotActive && !root.isBusy
            onTriggered: root.runAction("/usr/local/bin/wifi-hotspot-toggle-ui --mode p2p")
        },
        PlasmaCore.Action {
            text: "Refresh Status"
            icon.name: "view-refresh"
            onTriggered: root.refreshStatus()
        }
    ]

    function parsePorcelain(text, includeSecret) {
        const lines = text.split("\n");
        let active = false;
        let mode = "";
        let iface = "";
        let ssid = "";
        let pass = "";
        let ch = "";
        let freq = "";
        let gw = "";
        let upstream = "wlp4s0";
        let upFreq = "";
        let upCh = "";
        let clients = "0";

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line) {
                continue;
            }
            const eq = line.indexOf("=");
            if (eq <= 0) {
                continue;
            }
            const k = line.slice(0, eq);
            const v = line.slice(eq + 1);
            switch (k) {
            case "HOTSPOT_ACTIVE": active = (v === "1"); break;
            case "ACTIVE_MODE": mode = v; break;
            case "HOTSPOT_IFACE": iface = v; break;
            case "HOTSPOT_SSID_ACTIVE": ssid = v; break;
            case "HOTSPOT_PASS_ACTIVE": pass = v; break;
            case "ACTIVE_CHANNEL": ch = v; break;
            case "ACTIVE_FREQ": freq = v; break;
            case "HOTSPOT_GW_ACTIVE": gw = v; break;
            case "UPSTREAM_IFACE": upstream = v; break;
            case "UPSTREAM_FREQ": upFreq = v; break;
            case "UPSTREAM_CHANNEL": upCh = v; break;
            case "CONNECTED_CLIENTS": clients = v; break;
            }
        }

        if (includeSecret) {
            if (pass !== "") {
                root.revealedPass = pass;
            }
            return;
        }

        root.hotspotActive = active;
        root.activeMode = mode;
        root.hotspotIface = iface;
        root.activeSsid = ssid;
        root.activeChannel = ch;
        root.activeFreq = freq;
        root.gatewayIp = gw;
        root.upstreamIface = upstream;
        root.upstreamFreq = upFreq;
        root.upstreamChannel = upCh;
        root.connectedClients = clients;
        if (!active) {
            root.revealedPass = "";
        }
    }

    function refreshStatus() {
        statusSource.disconnectSource(root.statusCmd);
        statusSource.connectSource(root.statusCmd);
    }

    function revealPassword() {
        root.errorMessage = "";
        secretSource.disconnectSource(root.passCmd);
        secretSource.connectSource(root.passCmd);
    }

    function runAction(cmd) {
        if (root.isBusy) {
            return;
        }
        root.errorMessage = "";
        root.isBusy = true;
        actionSource.disconnectSource(cmd);
        actionSource.connectSource(cmd);
    }

    function toggleHotspot() {
        if (root.hotspotActive) {
            root.runAction("/usr/local/bin/wifi-hotspot-toggle-ui");
        } else {
            root.runAction("/usr/local/bin/wifi-hotspot-toggle-ui --mode " + root.selectedMode);
        }
    }

    Plasma5Support.DataSource {
        id: statusSource
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            const exitCode = data["exit code"] !== undefined ? data["exit code"] : 0;
            if (exitCode === 0) {
                root.parsePorcelain(data["stdout"] || "", false);
            }
        }
    }

    Plasma5Support.DataSource {
        id: secretSource
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            const exitCode = data["exit code"] !== undefined ? data["exit code"] : 0;
            if (exitCode === 0) {
                root.parsePorcelain(data["stdout"] || "", true);
            } else {
                root.errorMessage = "Run 'sudo wifi-hotspot status' in a terminal or deploy /etc/sudoers.d/wifi-hotspot to reveal password without prompting (pkexec is used for toggle fallback).";
            }
        }
    }

    Plasma5Support.DataSource {
        id: actionSource
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            root.isBusy = false;
            const exitCode = data["exit code"] !== undefined ? data["exit code"] : 0;
            if (exitCode !== 0) {
                const err = (data["stderr"] || data["stdout"] || "").trim();
                root.errorMessage = err !== "" ? err : ("Hotspot command failed (exit " + exitCode + ")");
            }
            root.refreshStatus();
        }
    }

    Timer {
        interval: root.expanded ? 4000 : 12000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshStatus()
    }

    onExpandedChanged: {
        if (root.expanded) {
            root.refreshStatus();
        } else {
            root.revealedPass = "";
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        Layout.minimumHeight: Kirigami.Units.gridUnit * 16
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: Kirigami.Units.gridUnit * 18

        header: PlasmaExtras.PlasmoidHeading {
            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: root.hotspotActive ? "network-wireless-hotspot" : "network-wireless-hotspot-symbolic"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                }

                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true

                    PlasmaExtras.Heading {
                        level: 4
                        text: "Parallel Wi-Fi Hotspot"
                        Layout.fillWidth: true
                    }

                    PlasmaComponents3.Label {
                        text: root.hotspotActive ? "ACTIVE · " + root.activeModeLabel : "INACTIVE"
                        font: Kirigami.Theme.smallFont
                        color: root.hotspotActive ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                        Layout.fillWidth: true
                    }
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "view-refresh"
                    onClicked: root.refreshStatus()
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: "Refresh status"
                }
            }
        }

        Item {
            anchors.fill: parent

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.mediumSpacing

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    visible: root.errorMessage !== ""
                    type: Kirigami.MessageType.Error
                    text: root.errorMessage
                    actions: [
                        Kirigami.Action {
                            icon.name: "dialog-close"
                            text: "Dismiss"
                            onTriggered: root.errorMessage = ""
                        }
                    ]
                }

                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    visible: root.hotspotActive

                    PlasmaComponents3.Label {
                        Kirigami.FormData.label: "SSID:"
                        text: root.activeSsid
                        font.bold: true
                    }

                    RowLayout {
                        Kirigami.FormData.label: "Password:"
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents3.Label {
                            text: root.revealedPass !== "" ? root.revealedPass : "••••••••••••"
                            font.family: "monospace"
                        }

                        PlasmaComponents3.ToolButton {
                            icon.name: root.revealedPass !== "" ? "view-hidden" : "view-visible"
                            text: root.revealedPass !== "" ? "Hide" : "Show"
                            onClicked: {
                                if (root.revealedPass !== "") {
                                    root.revealedPass = "";
                                } else {
                                    root.revealPassword();
                                }
                            }
                        }
                    }

                    PlasmaComponents3.Label {
                        Kirigami.FormData.label: "Channel:"
                        text: "Ch " + root.activeChannel + " (" + root.activeFreq + " MHz)"
                    }

                    PlasmaComponents3.Label {
                        Kirigami.FormData.label: "Interface:"
                        text: root.hotspotIface + " (upstream: " + root.upstreamIface + ")"
                    }

                    PlasmaComponents3.Label {
                        Kirigami.FormData.label: "Gateway:"
                        text: root.gatewayIp
                    }

                    PlasmaComponents3.Label {
                        Kirigami.FormData.label: "Clients:"
                        text: root.connectedClients
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !root.hotspotActive
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: {
                            if (root.upstreamFreq !== "") {
                                const is5 = Number(root.upstreamFreq) >= 5000;
                                return "Upstream " + root.upstreamIface + " connected on Ch " + root.upstreamChannel
                                    + " (" + root.upstreamFreq + " MHz). Auto mode will use "
                                    + (is5 ? "P2P-GO (2.4 GHz)" : "Virtual AP (same channel)") + " without dropping Wi-Fi.";
                            }
                            return "Upstream " + root.upstreamIface + " is ready to run a parallel Hotspot without disconnecting primary Wi-Fi.";
                        }
                        opacity: 0.85
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        PlasmaComponents3.Label {
                            text: "Mode:"
                            font.bold: true
                        }

                        PlasmaComponents3.RadioButton {
                            text: "Auto (AP 2.4 GHz / P2P-GO 5 GHz)"
                            checked: root.selectedMode === "auto"
                            onToggled: if (checked) root.selectedMode = "auto"
                        }

                        PlasmaComponents3.RadioButton {
                            text: "Force AP (2.4 GHz same channel)"
                            checked: root.selectedMode === "ap"
                            onToggled: if (checked) root.selectedMode = "ap"
                        }

                        PlasmaComponents3.RadioButton {
                            text: "Force P2P-GO (2.4 GHz multi-channel)"
                            checked: root.selectedMode === "p2p"
                            onToggled: if (checked) root.selectedMode = "p2p"
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    highlighted: !root.hotspotActive
                    enabled: !root.isBusy
                    icon.name: root.hotspotActive ? "media-playback-stop" : "network-wireless-hotspot"
                    text: {
                        if (root.isBusy) {
                            return root.hotspotActive ? "Stopping Hotspot..." : "Starting Hotspot...";
                        }
                        return root.hotspotActive ? "Turn Hotspot OFF" : "Turn Hotspot ON";
                    }
                    onClicked: root.toggleHotspot()
                }
            }
        }
    }
}
