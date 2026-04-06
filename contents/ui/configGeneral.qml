import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

// Standard Plasma config page: root must be FormLayout,
// cfg_ aliases are read directly by the KCM framework.
Kirigami.FormLayout {
    id: page

    property alias cfg_minBrightness: minSlider.value
    property alias cfg_maxBrightness: maxSlider.value
    property alias cfg_luxMin:        luxMinField.value
    property alias cfg_luxMax:        luxMaxField.value
    property alias cfg_smoothing:     smoothSlider.value
    property alias cfg_userBias:      biasSlider.value

    // ── Presets ──────────────────────────────────────────────────────────────
    RowLayout {
        Kirigami.FormData.label: "Presets:"
        spacing: Kirigami.Units.smallSpacing

        PC3.Button {
            text: "Standard"
            onClicked: { minSlider.value = 5;  maxSlider.value = 100; biasSlider.value = 50 }
        }
        PC3.Button {
            text: "OLED safe"
            PC3.ToolTip.text: "Clamps to 40–80 % to reduce OLED wear"
            PC3.ToolTip.visible: hovered
            onClicked: { minSlider.value = 40; maxSlider.value = 80;  biasSlider.value = 50 }
        }
        PC3.Button {
            text: "Night"
            onClicked: { minSlider.value = 1;  maxSlider.value = 30;  biasSlider.value = 50 }
        }
    }

    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Brightness range" }

    // ── Brightness bounds ─────────────────────────────────────────────────────
    RowLayout {
        Kirigami.FormData.label: "Min brightness:"
        spacing: Kirigami.Units.smallSpacing

        QQC2.Slider {
            id: minSlider
            from: 1; to: 80; stepSize: 1
            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        }
        PC3.Label { text: minSlider.value + " %"; font.family: "monospace" }
    }

    RowLayout {
        Kirigami.FormData.label: "Max brightness:"
        spacing: Kirigami.Units.smallSpacing

        QQC2.Slider {
            id: maxSlider
            from: 20; to: 100; stepSize: 1
            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        }
        PC3.Label { text: maxSlider.value + " %"; font.family: "monospace" }
    }

    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Brightness bias" }

    // ── Bias (midpoint remap) ─────────────────────────────────────────────────
    RowLayout {
        Kirigami.FormData.label: "Bias:"
        spacing: Kirigami.Units.smallSpacing

        PC3.Label { text: "Dim" }
        QQC2.Slider {
            id: biasSlider
            from: 0; to: 100; stepSize: 1
            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        }
        PC3.Label { text: "Bright" }
        PC3.Label {
            text: biasSlider.value === 50
                      ? "Neutral"
                      : (biasSlider.value > 50 ? "+" : "") + (biasSlider.value - 50) + " %"
            font.family: "monospace"
            Layout.minimumWidth: Kirigami.Units.gridUnit * 4
        }
    }

    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Lux curve" }

    // ── Lux range ─────────────────────────────────────────────────────────────
    RowLayout {
        Kirigami.FormData.label: "Dark threshold:"
        spacing: Kirigami.Units.smallSpacing
        QQC2.SpinBox { id: luxMinField; from: 1; to: 500; stepSize: 1 }
        PC3.Label { text: "lux" }
    }

    RowLayout {
        Kirigami.FormData.label: "Bright threshold:"
        spacing: Kirigami.Units.smallSpacing
        QQC2.SpinBox { id: luxMaxField; from: 100; to: 50000; stepSize: 100 }
        PC3.Label { text: "lux" }
    }

    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Responsiveness" }

    // ── Smoothing ─────────────────────────────────────────────────────────────
    RowLayout {
        Kirigami.FormData.label: "Smoothing:"
        spacing: Kirigami.Units.smallSpacing
        PC3.Label { text: "Slow" }
        QQC2.Slider {
            id: smoothSlider
            from: 5; to: 50; stepSize: 1
            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        }
        PC3.Label { text: "Fast" }
    }
}
