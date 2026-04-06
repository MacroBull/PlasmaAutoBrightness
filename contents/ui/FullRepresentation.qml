import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

ColumnLayout {
    id: fullRep

    Layout.minimumWidth: Kirigami.Units.gridUnit * 18
    Layout.minimumHeight: implicitHeight
    spacing: Kirigami.Units.largeSpacing

    // ── Section 1: Info ─────────────────────────────────────────────────────

    // Header: icon + name + enable switch
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
            checked: plasmoid.configuration.enabled
            onToggled: plasmoid.configuration.enabled = checked
        }
    }

    // Status rows: label | value text | inline bar  (3-col GridLayout)
    GridLayout {
        id: infoGrid
        columns: 3
        Layout.fillWidth: true
        columnSpacing: Kirigami.Units.smallSpacing
        rowSpacing: Kirigami.Units.smallSpacing / 2

        opacity: plasmoid.configuration.enabled ? 1.0 : 0.4
        Behavior on opacity { NumberAnimation { duration: 200 } }

        // Row 1: Ambient lux
        PC3.Label {
            text: "Ambient"
            color: Kirigami.Theme.disabledTextColor
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
        PC3.Label {
            text: root.sensorAvailable
                      ? "%1 lux  (EMA %2)".arg(root.currentLux.toFixed(0))
                                          .arg(root.emaLux >= 0 ? root.emaLux.toFixed(0) : "—")
                      : "No sensor"
            font.family: "monospace"
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            Layout.minimumWidth: Kirigami.Units.gridUnit * 8
        }
        QQC2.ProgressBar {
            Layout.fillWidth: true
            implicitHeight: Kirigami.Units.smallSpacing * 2
            from: 0; to: 1
            value: root.luxLogPos
            Behavior on value { NumberAnimation { duration: 400 } }
        }

        // Row 2: Screen brightness
        PC3.Label {
            text: "Brightness"
            color: Kirigami.Theme.disabledTextColor
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
        PC3.Label {
            text: root.maxRaw > 0
                      ? "%1%  (→ %2%)".arg(Math.round(root.currentBrightness / root.maxRaw * 100))
                                      .arg(Math.round(root.targetPercent))
                      : "—"
            font.family: "monospace"
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            Layout.minimumWidth: Kirigami.Units.gridUnit * 8
        }
        QQC2.ProgressBar {
            Layout.fillWidth: true
            implicitHeight: Kirigami.Units.smallSpacing * 2
            from: 0; to: 100
            value: root.targetPercent
            Behavior on value { NumberAnimation { duration: 400 } }
        }
    }

    // ── Curve chart ──────────────────────────────────────────────────────────
    // Shows the lux→brightness mapping curve (log X, linear Y).
    // Green dot = current position.
    Item {
        id: chartArea
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 5
        opacity: plasmoid.configuration.enabled ? 1.0 : 0.35
        Behavior on opacity { NumberAnimation { duration: 200 } }

        // Axis labels (bottom-left: luxMin, bottom-right: luxMax)
        PC3.Label {
            anchors { left: parent.left; bottom: parent.bottom }
            text: plasmoid.configuration
                      ? (plasmoid.configuration.luxMin < 1000
                             ? plasmoid.configuration.luxMin + " lx"
                             : (plasmoid.configuration.luxMin / 1000).toFixed(0) + "k lx")
                      : ""
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
            color: Kirigami.Theme.disabledTextColor
        }
        PC3.Label {
            anchors { right: parent.right; bottom: parent.bottom }
            text: plasmoid.configuration
                      ? (plasmoid.configuration.luxMax < 1000
                             ? plasmoid.configuration.luxMax + " lx"
                             : (plasmoid.configuration.luxMax / 1000).toFixed(0) + "k lx")
                      : ""
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
            color: Kirigami.Theme.disabledTextColor
        }
        // Y labels
        PC3.Label {
            anchors { left: parent.left; top: parent.top }
            text: plasmoid.configuration ? plasmoid.configuration.maxBrightness + "%" : ""
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
            color: Kirigami.Theme.disabledTextColor
        }
        PC3.Label {
            anchors { left: parent.left; bottom: parent.bottom; bottomMargin: Kirigami.Units.gridUnit }
            text: plasmoid.configuration ? plasmoid.configuration.minBrightness + "%" : ""
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
            color: Kirigami.Theme.disabledTextColor
        }

        // Margin so the curve doesn't overlap axis labels
        readonly property int marginLeft:  Kirigami.Units.gridUnit * 2
        readonly property int marginRight: Kirigami.Units.gridUnit * 2
        readonly property int marginTop:   Kirigami.Units.smallSpacing
        readonly property int marginBot:   Kirigami.Units.gridUnit

        Canvas {
            id: curveCanvas
            anchors.fill: parent

            // Redrawn when config changes or size changes
            onWidthChanged:  requestPaint()
            onHeightChanged: requestPaint()

            Connections {
                target: plasmoid.configuration
                function onUserBiasChanged()      { curveCanvas.requestPaint() }
                function onMinBrightnessChanged() { curveCanvas.requestPaint() }
                function onMaxBrightnessChanged() { curveCanvas.requestPaint() }
                function onLuxMinChanged()        { curveCanvas.requestPaint() }
                function onLuxMaxChanged()        { curveCanvas.requestPaint() }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (!plasmoid.configuration || width < 10 || height < 10) return

                var ml = chartArea.marginLeft
                var mr = chartArea.marginRight
                var mt = chartArea.marginTop
                var mb = chartArea.marginBot
                var cw = width  - ml - mr   // drawable width [px]
                var ch = height - mt - mb   // drawable height [px]

                // Subtle background
                ctx.fillStyle = Qt.rgba(
                    Kirigami.Theme.backgroundColor.r,
                    Kirigami.Theme.backgroundColor.g,
                    Kirigami.Theme.backgroundColor.b, 0.3)
                ctx.fillRect(ml, mt, cw, ch)

                // Grid lines at 25/50/75%
                ctx.strokeStyle = Qt.rgba(
                    Kirigami.Theme.textColor.r,
                    Kirigami.Theme.textColor.g,
                    Kirigami.Theme.textColor.b, 0.08)
                ctx.lineWidth = 1
                ;[0.25, 0.5, 0.75].forEach(function(f) {
                    var y = mt + ch * (1 - f)
                    ctx.beginPath(); ctx.moveTo(ml, y); ctx.lineTo(ml + cw, y); ctx.stroke()
                })

                // Build curve points (N=60): t is the x-position ratio,
                var N = 60
                var pts = []
                for (var i = 0; i <= N; i++) {
                    var t  = i / N                            // [ratio 0..1]
                    var br = root._tToPercent(t) / 100  // [ratio 0..1]
                    pts.push({ x: ml + t * cw, y: mt + ch * (1 - br) })
                }

                // Fill under curve
                ctx.beginPath()
                ctx.moveTo(pts[0].x, pts[0].y)
                for (var j = 1; j < pts.length; j++)
                    ctx.lineTo(pts[j].x, pts[j].y)
                ctx.lineTo(ml + cw, mt + ch)
                ctx.lineTo(ml,      mt + ch)
                ctx.closePath()
                ctx.fillStyle = Qt.rgba(
                    Kirigami.Theme.highlightColor.r,
                    Kirigami.Theme.highlightColor.g,
                    Kirigami.Theme.highlightColor.b, 0.15)
                ctx.fill()

                // Curve line
                ctx.beginPath()
                ctx.moveTo(pts[0].x, pts[0].y)
                for (var k = 1; k < pts.length; k++)
                    ctx.lineTo(pts[k].x, pts[k].y)
                ctx.strokeStyle = Qt.rgba(
                    Kirigami.Theme.highlightColor.r,
                    Kirigami.Theme.highlightColor.g,
                    Kirigami.Theme.highlightColor.b, 0.9)
                ctx.lineWidth = 1.5
                ctx.lineJoin = "round"
                ctx.stroke()
            }
        }

        // Current-position dot (animated)
        Rectangle {
            id: posDot
            width: 8; height: 8; radius: 4
            color: Kirigami.Theme.positiveTextColor
            border.color: Kirigami.Theme.backgroundColor
            border.width: 1.5
            visible: root.emaLux > 0 && plasmoid.configuration

            x: chartArea.marginLeft
               + root.luxLogPos * (chartArea.width - chartArea.marginLeft - chartArea.marginRight)
               - width / 2
            y: chartArea.marginTop
               + (chartArea.height - chartArea.marginTop - chartArea.marginBot) * (1 - root.targetPercent / 100)
               - height / 2
            Behavior on x { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        }
    }

    Kirigami.Separator { Layout.fillWidth: true }

    // ── Section 2: Controls ─────────────────────────────────────────────────

    // Internal display bias slider
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        RowLayout {
            Layout.fillWidth: true

            PC3.Label {
                text: plasmoid.configuration.externalEnabled
                    ? "Internal bias" : "Brightness bias"
                font.bold: true
                Layout.fillWidth: true
            }

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
            PC3.Label {
                text: "Dim"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
            }
            Item { Layout.fillWidth: true }
            PC3.Label {
                text: "Bright"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }

    // External display bias slider (visible only when external DDC/CI is enabled)
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        visible: plasmoid.configuration.externalEnabled

        RowLayout {
            Layout.fillWidth: true

            PC3.Label {
                text: "External bias"
                font.bold: true
                Layout.fillWidth: true
            }

            PC3.Label {
                text: plasmoid.configuration.externalBias === 50
                    ? "Neutral"
                    : (plasmoid.configuration.externalBias > 50 ? "+" : "") +
                      (plasmoid.configuration.externalBias - 50) + "%"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.family: "monospace"
            }
        }

        QQC2.Slider {
            id: externalBiasSlider
            Layout.fillWidth: true
            implicitHeight: Kirigami.Units.gridUnit * 1.5
            from: 0; to: 100; stepSize: 1
            value: plasmoid.configuration.externalBias
            onMoved: plasmoid.configuration.externalBias = Math.round(value)
        }

        RowLayout {
            Layout.fillWidth: true
            PC3.Label {
                text: "Dim"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
            }
            Item { Layout.fillWidth: true }
            PC3.Label {
                text: "Bright"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }

    // Brightness range slider
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        RowLayout {
            Layout.fillWidth: true

            PC3.Label {
                text: "Brightness range"
                font.bold: true
                Layout.fillWidth: true
            }

            PC3.Label {
                text: "%1% – %2%".arg(Math.round(rangeSlider.first.value)).arg(Math.round(rangeSlider.second.value))
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.family: "monospace"
            }
        }

        QQC2.RangeSlider {
            id: rangeSlider
            Layout.fillWidth: true
            implicitHeight: Kirigami.Units.gridUnit * 1.5
            from: 1; to: 100; stepSize: 1

            Component.onCompleted: setValues(plasmoid.configuration.minBrightness,
                                             plasmoid.configuration.maxBrightness)

            Connections {
                target: plasmoid.configuration
                function onMinBrightnessChanged() {
                    rangeSlider.setValues(plasmoid.configuration.minBrightness,
                                         rangeSlider.second.value)
                }
                function onMaxBrightnessChanged() {
                    rangeSlider.setValues(rangeSlider.first.value,
                                         plasmoid.configuration.maxBrightness)
                }
            }

            first.onMoved:  plasmoid.configuration.minBrightness = Math.round(first.value)
            second.onMoved: plasmoid.configuration.maxBrightness = Math.round(second.value)
        }

        RowLayout {
            Layout.fillWidth: true
            PC3.Label {
                text: "Min"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
            }
            Item { Layout.fillWidth: true }
            PC3.Label {
                text: "Max"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }

    Kirigami.Separator { Layout.fillWidth: true }

    // ── Section 3: Presets ──────────────────────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        PC3.Label {
            text: "Presets:"
            font.bold: true
        }

        Item { Layout.fillWidth: true }

        PC3.Button {
            text: "Standard"
            onClicked: {
                plasmoid.configuration.minBrightness = 5
                plasmoid.configuration.maxBrightness = 100
                plasmoid.configuration.userBias = 50
            }
        }

        PC3.Button {
            text: "OLED safe"
            onClicked: {
                plasmoid.configuration.minBrightness = 40
                plasmoid.configuration.maxBrightness = 80
                plasmoid.configuration.userBias = 50
            }
        }

        PC3.Button {
            text: "Night"
            onClicked: {
                plasmoid.configuration.minBrightness = 1
                plasmoid.configuration.maxBrightness = 30
                plasmoid.configuration.userBias = 50
            }
        }
    }
}
