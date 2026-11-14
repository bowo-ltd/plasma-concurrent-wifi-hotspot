# Complete Developer Guide: Building Standalone KDE Plasma 6 Panel Applets from Scratch

This guide is an end-to-end architectural manual for creating, packaging, testing, and debugging **native desktop and panel widgets (Plasmoids) for KDE Plasma 6** on modern Linux (Wayland / X11).

Whether you want to build a system monitor, a hardware toggle (like Wi-Fi Hotspot or Bluetooth), or an API dashboard, this blueprint documents the exact concepts, templates, and runtime mechanisms so you can build new applets without confusion.

---

## 1. Core Concepts: How KDE Plasma 6 Applets Work

### What is a Plasmoid?
A **Plasmoid** is a modular QML/Qt 6 component managed by the KDE Plasma desktop shell (`plasmashell`). It is packaged as a standard directory containing a manifest (`metadata.json`) and QML source files (`contents/ui/main.qml`).

### Containments vs. Applets
In KDE Plasma architecture:
- A **Containment** is a container that hosts widgets (e.g., your Desktop background, a top/bottom Panel, or the System Tray).
- An **Applet** is the individual widget hosted inside a containment.

Depending on where a user places your Plasmoid, Plasma alters its presentation:
1. **Inside a Panel (Top, Bottom, Left, or Right edge)**:
   The Plasmoid renders its **Compact Representation** (typically a small icon, status indicator, or badge fitting the panel thickness).
2. **When Clicked from a Panel**:
   Plasma opens a flyout popup bubble rendering its **Full Representation** (a rich UI with tabs, action buttons, lists, and toggles).
3. **Placed Directly on the Desktop**:
   Plasma directly renders the **Full Representation** as a floating desktop widget.

---

## 2. Directory Structure & Package Anatomy

Every KDE Plasma 6 Plasmoid follows this strict directory layout:

```text
~/.local/share/plasma/plasmoids/<unique.applet.id>/
├── metadata.json                 # Package descriptor, metadata, API version, category
└── contents/
    ├── config/                   # (Optional) User configuration definitions
    │   ├── main.xml              # KConfig schema for persistent settings
    │   └── config.qml            # Configuration dialog UI
    └── ui/
        ├── main.qml              # Root PlasmoidItem (Mandatory entrypoint)
        ├── CompactRepresentation.qml  # (Optional: can be inlined in main.qml)
        └── FullRepresentation.qml     # (Optional: can be inlined in main.qml)
```

### The Manifest (`metadata.json`)
The manifest informs `plasmashell` how to load, categorize, and display your applet.

```json
{
    "KPackageStructure": "Plasma/Applet",
    "KPlugin": {
        "Authors": [
            {
                "Name": "Your Name",
                "Email": "you@example.com"
            }
        ],
        "Category": "System Information",
        "Description": "Toggle and monitor system services in real-time",
        "EnabledByDefault": true,
        "Icon": "network-wireless-hotspot",
        "Id": "org.local.mywidget",
        "License": "GPL-2.0-or-later",
        "Name": "My Custom Widget",
        "Version": "1.0.0"
    },
    "X-Plasma-API": "declarativeappletscript",
    "X-Plasma-API-Minimum-Version": "6.0",
    "X-Plasma-MainScript": "ui/main.qml",
    "X-Plasma-NotificationArea": "true",
    "X-Plasma-NotificationAreaCategory": "SystemServices"
}
```

#### Critical Keys:
- **`Id`**: Must use unique reverse-DNS notation (e.g., `org.local.wifihotspot`, `com.company.monitor`).
- **`X-Plasma-API-Minimum-Version`**: Must be `"6.0"` for KDE Plasma 6.
- **`X-Plasma-NotificationArea`**: Set to `"true"` if you want your applet to be eligible to sit inside the **System Tray** expandable menu in addition to regular panels.
- **`X-Plasma-NotificationAreaCategory`**: Options include `SystemServices`, `Hardware`, `ApplicationStatus`, or `Communications`.

---

## 3. Plasma 5 vs. Plasma 6: Breaking Changes & Migration

If you have worked with older KDE Plasma 5 tutorials, be aware of these critical architectural shifts in Plasma 6 (Qt 6 / KF6):

| Feature / API | KDE Plasma 5 (Qt 5) | KDE Plasma 6 (Qt 6) |
|---|---|---|
| **Root Item** | `Item { ... }` with attached `Plasmoid` | **`PlasmoidItem { ... }`** (Mandatory root component) |
| **Attached Properties** | `Plasmoid.compactRepresentation` | Direct property: `compactRepresentation: ...` |
| **Data Engine Import** | `import org.kde.plasma.core as PlasmaCore` | **`import org.kde.plasma.plasma5support as Plasma5Support`** |
| **Controls Components** | `org.kde.plasma.components 2.0 / 3.0` | **`org.kde.plasma.components as PlasmaComponents3`** |
| **Heading / Extras** | `org.kde.plasma.extras 2.0` | **`import org.kde.plasma.extras as PlasmaExtras`** |
| **Kirigami Framework** | Kirigami 2 | **Kirigami 3** (`import org.kde.kirigami as Kirigami`) |

---

## 4. Responsive Geometry: Panel vs. Desktop Detection

To make your widget behave seamlessly whether placed in a thin top bar, a vertical side panel, or on the desktop, implement edge detection:

```qml
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    // Determine if the widget is docked inside any panel
    readonly property bool inPanel: [
        PlasmaCore.Types.TopEdge,
        PlasmaCore.Types.RightEdge,
        PlasmaCore.Types.BottomEdge,
        PlasmaCore.Types.LeftEdge
    ].includes(Plasmoid.location)

    // Automatically switch between compact icon and full popup card
    preferredRepresentation: inPanel ? compactRepresentation : fullRepresentation

    // Define compact icon for panels
    compactRepresentation: MouseArea {
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) - Kirigami.Units.smallSpacing * 2
            height: width
            source: "utilities-system-monitor"
        }
    }

    // Define expanded flyout card
    fullRepresentation: PlasmaExtras.Representation {
        // Detailed popup content here
    }
}
```

---

## 5. Backend Execution: Running CLI Commands from QML

You do **not** need to write C++ plugins to run Linux shell commands or query system daemons. KDE provides `Plasma5Support.DataSource` with the built-in `executable` engine.

### Safe Execution Pattern (Preventing Memory Leaks):

```qml
import org.kde.plasma.plasma5support as Plasma5Support

Plasma5Support.DataSource {
    id: execEngine
    engine: "executable"
    connectedSources: []

    onNewData: function(sourceName, data) {
        var stdout = (data["stdout"] || "").trim();
        var stderr = (data["stderr"] || "").trim();
        var exitCode = data["exit code"];

        console.log("Command finished:", sourceName, "Output:", stdout);

        // Process data
        root.parseOutput(stdout);

        // ⚠️ CRITICAL: Disconnect one-shot commands to prevent memory leaks!
        disconnectSource(sourceName);
    }
}

function runCommand(commandString) {
    execEngine.connectSource(commandString);
}
```

### Polling with a Timer:
```qml
Timer {
    interval: 5000 // Poll every 5 seconds
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
        root.runCommand("/usr/local/bin/wifi-hotspot status --porcelain");
    }
}
```

---

## 6. Development, Live Reload & Debugging Workflow

You do **not** need to log out, restart your computer, or kill your desktop to develop and test Plasma 6 widgets.

### Step 1: Symlink Your Project to the Plasmoids Directory
Link your working git directory directly into the Plasma search path:

```bash
mkdir -p ~/.local/share/plasma/plasmoids/
ln -sfn /path/to/my-plasmoid ~/.local/share/plasma/plasmoids/org.local.mywidget
```

### Step 2: Test in an Isolated Window with `plasmawindowed`
KDE provides `plasmawindowed` to run any Plasmoid in a standalone test window:

```bash
plasmawindowed org.local.mywidget
```
*Benefits:* If your QML has syntax errors, only the test window closes; your desktop and taskbar remain completely unaffected!

### Step 3: Hot-Reload KDE Plasma Shell
When you make changes to `main.qml` or `metadata.json` and want to see them live on your actual panel:

```bash
# Reload all active Plasma shell components instantly
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell
```

### Step 4: Inspect Live QML Console & Error Logs
Use `journalctl` to tail live `console.log` statements and QML engine warnings:

```bash
# Follow live Plasma logs filtered for your widget
journalctl --user -u plasma-plasmashell -f | grep -i "mywidget"
```

---

## 7. Fast-Track: Creating a New Widget Using the Template Generator

This repository includes a reusable generator in `scripts/create-plasma-widget.sh`:

```bash
# 1. Run generator
./scripts/create-plasma-widget.sh \
  --id org.custom.servicewatch \
  --name "Service Watchdog" \
  --desc "Real-time service watcher for Plasma 6" \
  --icon "utilities-system-monitor"

# 2. Test immediately in window
plasmawindowed org.custom.servicewatch

# 3. Add to your panel
# Right-click panel -> "Add Widgets..." -> Drag "Service Watchdog"
```

With this template and workflow, creating custom, enterprise-grade KDE Plasma 6 desktop and panel tools takes **under five minutes**.
