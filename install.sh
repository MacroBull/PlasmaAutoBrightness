#!/usr/bin/env bash
# install.sh – install / reinstall the plasmoid into the user's Plasma session
set -euo pipefail

PLUGIN_ID="org.kde.plasma.autobrightness"
INSTALL_DIR="$HOME/.local/share/plasma/plasmoids/$PLUGIN_ID"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LICENSE_FILE="$SCRIPT_DIR/LICENSE"

case "${1:-install}" in
install)
    echo "Installing $PLUGIN_ID …"
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cp "$SCRIPT_DIR/metadata.json" "$INSTALL_DIR/"
    cp -r "$SCRIPT_DIR/contents"   "$INSTALL_DIR/"
    cp "$LICENSE_FILE" "$INSTALL_DIR/"
    find "$HOME/.cache" -type f -name "*.qmlc" -delete 2>/dev/null || true
    echo "Files installed:"
    find "$INSTALL_DIR" -type f | sed "s|$INSTALL_DIR/|  |"

    # Inject into system tray config so it appears after plasmashell restart
    qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
        var tray = null;
        panels().forEach(function(p) {
            p.widgets().forEach(function(w) {
                if (w.type === "org.kde.plasma.systemtray") tray = w;
            });
        });
        if (tray) {
            tray.currentConfigGroup = ["General"];
            var shown = tray.readConfig("shownItems","").split(",").filter(Boolean);
            if (shown.indexOf("org.kde.plasma.autobrightness") === -1)
                shown.push("org.kde.plasma.autobrightness");
            tray.writeConfig("shownItems", shown.join(","));
            tray.reloadConfig();
        }' 2>/dev/null || true

    echo ""
    echo "Test now:  plasmawindowed org.kde.plasma.autobrightness"
    echo "Permanent: kquitapp5 plasmashell && kstart5 plasmashell"
    ;;
uninstall)
    echo "Removing $PLUGIN_ID …"
    rm -rf "$INSTALL_DIR"
    echo "Done."
    ;;
package)
    OUT_DIR="${2:-$SCRIPT_DIR/dist}"
    PACKAGE_FILE="$OUT_DIR/${PLUGIN_ID}.plasmoid"

    echo "Packaging $PLUGIN_ID …"
    mkdir -p "$OUT_DIR"
    rm -f "$PACKAGE_FILE"
    (
        cd "$SCRIPT_DIR"
        zip -qr "$PACKAGE_FILE" metadata.json contents LICENSE README.md
    )
    echo "Package created: $PACKAGE_FILE"
    ;;
*)
    echo "Usage: $0 [install|uninstall|package [output_dir]]"
    exit 1
    ;;
esac
