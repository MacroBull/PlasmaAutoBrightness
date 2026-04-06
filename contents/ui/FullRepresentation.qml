import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

ColumnLayout {
    id: fullRep

    Layout.minimumWidth:  Kirigami.Units.gridUnit * 16
    Layout.minimumHeight: implicitHeight
    spacing: Kirigami.Units.smallSpacing

    // ── Header: enable toggle ───────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: "video-display-brightness"
            Layout.preferredWidth:  Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
        }

        PC3.Label {
            text: "Auto Brightness"
            font.bold: true
            Layout.fillWidth: true
        }

        PC3.Switch {
            id: enableSwitch
            checked: plasmoid.configuration.enabled
            onToggled: plasmoid.configuration.enabled = checked
        }
    }

    Kirigami.Separator { Layout.fillWidth: true }

    // ── Status readouts ─────────────────────────────────────────────────────
    GridLayout {
        columns: 2
        Layout.fillWidth: true
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing:    Kirigami.Units.smallSpacing

        opacity: plasmoid.configuration.enabled ? 1.0 : 0.4
        Behavior on opacity { NumberAnimation { duration: 200 } }

        PC3.Label { text: "Ambient light"; color: Kirigami.Theme.disabledTextColor }
        PC3.Label {
            text: root.sensorAvailable
                      ? qsTr("%1 lux").arg(root.currentLux.toFixed(1))
                      : "No sensor"
            font.family: "monospace"
        }

        PC3.Label { text: "Smoothed lux"; color: Kirigami.Theme.disabledTextColor }
        PC3.Label {
            text: root.emaLux >= 0
                      ? qsTr("%1 lux").arg(root.emaLux.toFixed(1))
                      : "—"
            font.family: "monospace"
        }

        PC3.Label { text: "Screen brightness"; color: Kirigami.Theme.disabledTextColor }
        PC3.Label {
            text: root.maxRaw > 0
                      ? qsTr("%1 %  (%2 / %3)").arg(Math.round(root.currentBrightness / root.maxRaw * 100))
                                               .arg(root.currentBrightness)
                                               .arg(root.maxRaw)
                      : "—"
            font.family: "monospace"
        }
    }

    // ── Visual brightness bar ───────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        opacity: plasmoid.configuration.enabled ? 1.0 : 0.4
        Behavior on opacity { NumberAnimation { duration: 200 } }

        PC3.Label {
            text: "Target brightness"
            color: Kirigami.Theme.disabledTextColor
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }

        QQC2.ProgressBar {
            Layout.fillWidth: true
            implicitHeight: Kirigami.Units.smallSpacing * 2
            from: 0; to: 1
            value: root.maxRaw > 0 ? root.currentBrightness / root.maxRaw : 0
            Behavior on value { NumberAnimation { duration: 400 } }
        }
    }

    Kirigami.Separator { Layout.fillWidth: true }

    // ── Bias slider ─────────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        opacity: plasmoid.configuration.enabled ? 1.0 : 0.4
        Behavior on opacity { NumberAnimation { duration: 200 } }

        RowLayout {
            Layout.fillWidth: true
            PC3.Label {
                text: "Brightness bias"
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
            Item { Layout.fillWidth: true }
            PC3.Label {
                text: plasmoid.configuration.userBias === 50
                    ? "Neutral"
                    : (plasmoid.configuration.userBias > 50 ? "+" : "") +
                      (plasmoid.configuration.userBias - 50) + "%"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.family: "monospace"
            }
        }

        QQC2.Slider {
            id: biasSlider
            Layout.fillWidth: true
            implicitHeight: Kirigami.Units.gridUnit * 1.5
            from: 0; to: 100; stepSize: 1
            value: plasmoid.configuration.userBias
            onMoved: plasmoid.configuration.userBias = Math.round(value)
        }

        RowLayout {
            Layout.fillWidth: true
            PC3.Label { text: "Dim"; font.pointSize: Kirigami.Theme.smallFont.pointSize; color: Kirigami.Theme.disabledTextColor }
            Item { Layout.fillWidth: true }
            PC3.Label { text: "Bright"; font.pointSize: Kirigami.Theme.smallFont.pointSize; color: Kirigami.Theme.disabledTextColor }
        }
    }

    Kirigami.Separator { Layout.fillWidth: true }
    PC3.Button {
        Layout.alignment: Qt.AlignRight
        text: "Configure…"
        icon.name: "configure"
        flat: true
        onClicked: plasmoid.action("configure").trigger()
    }
}
