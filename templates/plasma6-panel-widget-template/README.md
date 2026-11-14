# Universal KDE Plasma 6 Panel Applet Boilerplate

This directory provides a reference boilerplate template for building **native KDE Plasma 6 desktop & panel widgets** (Plasmoids) using Qt 6 QML and Kirigami.

---

## 📁 Package Anatomy

```
my-plasmoid/
├── metadata.json           # Plugin descriptor, unique ID, API versions, notification settings
└── contents/
    └── ui/
        └── main.qml        # Root PlasmoidItem handling compact & full representations
```

---

## ⚡ Quickstart: Generating a New Applet

You can use the automated generator script in `scripts/create-plasma-widget.sh`:

```bash
# Interactive mode
./scripts/create-plasma-widget.sh

# Or CLI one-liner
./scripts/create-plasma-widget.sh \
  --id org.custom.myservice \
  --name "My Service Monitor" \
  --desc "Real-time daemon monitor for KDE Plasma 6" \
  --icon "utilities-system-monitor"
```

---

## 🛠️ Testing Live (Without Restarting Desktop)

1. **Test in isolated window using `plasmawindowed`**:
   ```bash
   plasmawindowed org.custom.myservice
   ```
2. **Deploy to local Plasmoids directory**:
   ```bash
   cp -r my-plasmoid ~/.local/share/plasma/plasmoids/org.custom.myservice
   ```
3. **Live Reload Plasma Shell**:
   ```bash
   qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell
   ```
4. **Inspect Live QML Logs**:
   ```bash
   journalctl --user -u plasma-plasmashell -f | grep -i "myservice"
   ```
