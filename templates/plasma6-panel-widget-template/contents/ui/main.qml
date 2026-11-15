import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

// ==============================================================================
// KDE Plasma 6 Universal Panel Widget Boilerplate
// ==============================================================================
// Root container must be PlasmoidItem in Plasma 6.
// Handles both Compact Representation (inside top/bottom/left/right panels)
// and Full Representation (flyout popup when clicked).
// ==============================================================================

PlasmoidItem {
    id: root

    // --- State Properties ---
    property bool isActive: false
    property bool isBusy: false
    property string statusText: "Ready"
    property string lastOutput: ""
    property bool enableBackgroundPolling: false
    property int refreshIntervalSec: 5

    // --- Panel Location Helper ---
    readonly property bool inPanel: [
        PlasmaCore.Types.TopEdge,
        PlasmaCore.Types.RightEdge,
        PlasmaCore.Types.BottomEdge,
        PlasmaCore.Types.LeftEdge
    ].includes(Plasmoid.location)

    // Preferred sizes for desktop vs popup
    preferredRepresentation: inPanel ? compactRepresentation : fullRepresentation
    width: inPanel ? Kirigami.Units.gridUnit * 2 : Kirigami.Units.gridUnit * 18
    height: inPanel ? Kirigami.Units.gridUnit * 2 : Kirigami.Units.gridUnit * 14

    // --- Tooltip Details ---
    toolTipMainText: "{{APPLET_NAME}}"
    toolTipSubText: statusText + (isActive ? " (Active)" : " (Idle)")

    // ==========================================================================
    // Backend Execution Engine (Plasma5Support.DataSource)
    // ==========================================================================
    // Uses the "executable" data engine to run Linux bash commands or Python scripts
    // directly from QML without requiring custom C++ plugins or DBus daemons.
    // ==========================================================================
    Plasma5Support.DataSource {
        id: execEngine
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim();
            var stderr = (data["stderr"] || "").trim();
            var exitCode = data["exit code"];

            root.lastOutput = stdout ? stdout : (stderr ? "Error: " + stderr : "Done");
            root.isBusy = false;

            // Disconnect one-shot command sources to prevent memory leaks
            disconnectSource(sourceName);
        }
    }

    function runCommand(cmd) {
        root.isBusy = true;
        execEngine.connectSource(cmd);
    }

    // Refresh Mode:
    // - Zero-polling default (recommended for battery/CPU efficiency): refreshes on init, popup open, and manual clicks.
    // - Optional background polling: set enableBackgroundPolling = true when live tray badge updates are required.
    Component.onCompleted: runCommand("uptime -p")
    onExpandedChanged: if (expanded) runCommand("uptime -p")

    Timer {
        id: pollTimer
        interval: root.refreshIntervalSec * 1000
        running: root.enableBackgroundPolling
        repeat: true
        onTriggered: {
            // Replace with your real status probe (e.g. CLI command with --json or --porcelain)
            runCommand("uptime -p");
        }
    }

    // ==========================================================================
    // 1. Compact Representation (Panel Icon & Indicator)
    // ==========================================================================
    compactRepresentation: MouseArea {
        id: compactRoot
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) - Kirigami.Units.smallSpacing * 2
            height: width
            source: root.isActive ? "{{APPLET_ICON}}" : "{{APPLET_ICON}}-offline"
            opacity: root.isBusy ? 0.5 : 1.0

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }

        // Small notification badge when busy
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 2
            width: 6
            height: 6
            radius: 3
            color: Kirigami.Theme.highlightColor
            visible: root.isBusy
        }
    }

    // ==========================================================================
    // 2. Full Representation (Popup Card with Details & Actions)
    // ==========================================================================
    fullRepresentation: PlasmaExtras.Representation {
        id: fullRoot
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 12
        Layout.preferredHeight: Kirigami.Units.gridUnit * 16

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "{{APPLET_ICON}}"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Layout.preferredWidth
                }

                PlasmaComponents3.Label {
                    text: "{{APPLET_NAME}}"
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                PlasmaComponents3.BusyIndicator {
                    running: root.isBusy
                    visible: root.isBusy
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Layout.preferredWidth
                }
            }
        }

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            // Status Card
            Kirigami.Card {
                Layout.fillWidth: true
                banner.title: "System Status"

                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        PlasmaComponents3.Label {
                            text: "State:"
                            font.bold: true
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                        }
                        PlasmaComponents3.Label {
                            text: root.isActive ? "ACTIVE" : "IDLE"
                            color: root.isActive ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                            font.bold: true
                        }
                    }

                    RowLayout {
                        PlasmaComponents3.Label {
                            text: "Output:"
                            font.bold: true
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                        }
                        PlasmaComponents3.Label {
                            text: root.lastOutput || "Awaiting telemetry..."
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Action Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Button {
                    text: root.isActive ? "Stop" : "Start"
                    icon.name: root.isActive ? "media-playback-stop" : "media-playback-start"
                    Layout.fillWidth: true
                    onClicked: {
                        root.isActive = !root.isActive;
                        root.runCommand(root.isActive ? "echo Started" : "echo Stopped");
                    }
                }

                PlasmaComponents3.Button {
                    icon.name: "view-refresh"
                    text: "Refresh"
                    onClicked: root.runCommand("uptime -p")
                }
            }
        }
    }
}
