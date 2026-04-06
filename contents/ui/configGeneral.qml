import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_luxMin:           luxMinField.value
    property alias cfg_luxMax:           luxMaxField.value
    property alias cfg_smoothing:        smoothSlider.value
    property alias cfg_externalEnabled:  externalEnabledCheck.checked
    property alias cfg_externalDisplayNum: externalDisplayField.value

    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Lux curve" }

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

    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "External display (DDC/CI)" }

    QQC2.CheckBox {
        id: externalEnabledCheck
        Kirigami.FormData.label: "Control external monitor:"
        text: "Enable (requires ddcutil)"
    }

    RowLayout {
        Kirigami.FormData.label: "Display number:"
        spacing: Kirigami.Units.smallSpacing
        enabled: externalEnabledCheck.checked
        QQC2.SpinBox { id: externalDisplayField; from: 1; to: 8; stepSize: 1 }
        PC3.Label {
            text: "  (run 'ddcutil detect' to find)"
            color: Kirigami.Theme.disabledTextColor
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
    }
}
