import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtSensors 5.0
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore

Item {
    id: root

    // ── Exposed state for FullRepresentation ────────────────────────────────
    property real currentLux: 0
    property int  currentBrightness: 0   // raw value (0..maxRaw)
    property int  maxRaw: 100
    property bool sensorAvailable: false

    // ── Internal smoothing state ────────────────────────────────────────────
    property real emaLux: -1             // -1 = not yet initialised
    property int  lastSetRaw: -1
    property bool ignoreBrightnessChange: false  // gate: true while we're mid-write

    readonly property real alpha: plasmoid.configuration
                                      ? plasmoid.configuration.smoothing / 100.0
                                      : 0.15

    // Immediately re-apply when bias or brightness bounds change,
    // bypassing EMA hysteresis so the slider feels responsive.
    Connections {
        target: plasmoid.configuration ?? null
        function onUserBiasChanged()      { root.forceApply() }
        function onMinBrightnessChanged() { root.forceApply() }
        function onMaxBrightnessChanged() { root.forceApply() }
    }

    // ── Plasmoid metadata ───────────────────────────────────────────────────
    Plasmoid.icon: "video-display-brightness"
    Plasmoid.toolTipMainText: "Auto Brightness"
    Plasmoid.toolTipSubText: plasmoid.configuration && plasmoid.configuration.enabled
        ? qsTr("%1 lux → %2%").arg(currentLux.toFixed(1))
                              .arg(Math.round(currentBrightness / Math.max(1,maxRaw) * 100))
        : "Disabled"
    Plasmoid.fullRepresentation: FullRepresentation {}

    Plasmoid.compactRepresentation: Item {
        PlasmaCore.IconItem {
            anchors.fill: parent
            source: "video-display-brightness"
            opacity: plasmoid.configuration.enabled ? 1.0 : 0.4
        }
        MouseArea {
            anchors.fill: parent
            onClicked: plasmoid.expanded = !plasmoid.expanded
        }
    }

    // ── Power-management DataSource ─────────────────────────────────────────
    PlasmaCore.DataSource {
        id: pmSource
        engine: "powermanagement"
        connectedSources: ["PowerDevil"]
        onDataChanged: {
            const pd = data["PowerDevil"]
            if (!pd) return

            if (typeof pd["Maximum Screen Brightness"] === "number")
                root.maxRaw = pd["Maximum Screen Brightness"]

            const newBr = pd["Screen Brightness"]
            if (typeof newBr !== "number") return
            root.currentBrightness = newBr
        }
    }

    // Brief suppression window after we call setBrightness to avoid
    // treating our own write as a manual user change.
    Timer {
        id: suppressTimer
        interval: 1200
        onTriggered: root.ignoreBrightnessChange = false
    }

    // ── Ambient light sensor ────────────────────────────────────────────────
    LightSensor {
        id: lightSensor
        active: plasmoid.configuration.enabled
        dataRate: 1

        onActiveChanged: { if (!active) root.emaLux = -1 }

        onReadingChanged: {
            root.sensorAvailable = true
            const lux = reading.illuminance
            root.currentLux = lux
            root.applyLux(lux)
        }
    }

    // ── Brightness curve ────────────────────────────────────────────────────

    // Pure log-scale curve, no anchor applied.
    function baseCurve(lux) {
        const cfg  = plasmoid.configuration
        const logA = Math.log10(Math.max(1, cfg.luxMin))
        const logB = Math.log10(Math.max(logA + 0.1, cfg.luxMax))
        const t    = Math.max(0, Math.min(1,
                         (Math.log10(Math.max(1, lux)) - logA) / (logB - logA)))
        return cfg.minBrightness + t * (cfg.maxBrightness - cfg.minBrightness)
    }

    // Curve with gamma bias remapping applied.
    // Maps auto-curve output through a power function so that:
    //   f(0%)   = 0%   (always)
    //   f(50%)  = userBias%  (user's midpoint preference)
    //   f(100%) = 100%  (always)
    // userBias=50 → identity (γ=1, no change)
    // userBias>50 → γ<1, brighter overall
    // userBias<50 → γ>1, dimmer overall
    function luxToPercent(lux) {
        const cfg    = plasmoid.configuration
        const logA   = Math.log10(Math.max(1, cfg.luxMin))
        const logB   = Math.log10(Math.max(logA + 0.1, cfg.luxMax))
        const t      = Math.max(0, Math.min(1,
                           (Math.log10(Math.max(1, lux)) - logA) / (logB - logA)))
        const auto   = cfg.minBrightness + t * (cfg.maxBrightness - cfg.minBrightness)

        // Normalise to 0..1 within [minBr, maxBr] for gamma remap
        const range  = cfg.maxBrightness - cfg.minBrightness
        if (range <= 0) return cfg.minBrightness

        const normAuto   = (auto - cfg.minBrightness) / range          // 0..1
        const normAnchor = Math.max(0.001, Math.min(0.999,
                               (cfg.userBias - cfg.minBrightness) / range)  )
        const gamma      = Math.log(normAnchor) / Math.log(0.5)        // γ = log(anchor)/log(0.5)
        const remapped   = Math.pow(Math.max(0, Math.min(1, normAuto)), gamma)

        return cfg.minBrightness + remapped * range
    }

    // Force an immediate brightness update, ignoring hysteresis.
    // Used when config parameters change (bias, min/max bounds).
    function forceApply() {
        if (!plasmoid.configuration.enabled || emaLux <= 0) return
        const targetRaw = Math.round(luxToPercent(emaLux) / 100 * maxRaw)
        const service   = pmSource.serviceForSource("PowerDevil")
        if (!service) return
        const op      = service.operationDescription("setBrightness")
        op.brightness = targetRaw
        op.silent     = true
        ignoreBrightnessChange = true
        service.startOperationCall(op)
        suppressTimer.restart()
        lastSetRaw        = targetRaw
        currentBrightness = targetRaw
    }

    // EMA smoothing + hysteresis gate
    function applyLux(rawLux) {
        if (!plasmoid.configuration.enabled) return

        emaLux = (emaLux < 0) ? rawLux : (alpha * rawLux + (1 - alpha) * emaLux)

        const targetRaw   = Math.round(luxToPercent(emaLux) / 100 * maxRaw)
        const threshold   = Math.max(1, Math.round(0.01 * maxRaw))
        if (lastSetRaw >= 0 && Math.abs(targetRaw - lastSetRaw) < threshold) return

        const service = pmSource.serviceForSource("PowerDevil")
        if (!service) return
        const op      = service.operationDescription("setBrightness")
        op.brightness = targetRaw
        op.silent     = true

        ignoreBrightnessChange = true
        service.startOperationCall(op)
        suppressTimer.restart()

        lastSetRaw        = targetRaw
        currentBrightness = targetRaw
    }
}
