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
    property real emaLux: -1             // [lux]  -1 = not yet initialised
    property int  lastSetRaw: -1         // [raw]

    // log10-normalised position of emaLux within [luxMin, luxMax] [ratio 0..1].
    // This is the same as the intermediate `t` inside luxToPercent(emaLux).
    readonly property real luxLogPos: (plasmoid.configuration && emaLux > 0)
        ? _luxToT(emaLux) : 0

    // Target brightness [%] from EMA lux; falls back to current if sensor not ready.
    // Uses cached luxLogPos to avoid recomputing _luxToT(emaLux).
    readonly property real targetPercent: emaLux > 0
        ? _tToPercent(luxLogPos)
        : (maxRaw > 0 ? currentBrightness / maxRaw * 100 : 0)

    readonly property real alpha /* [ratio] */: plasmoid.configuration
        ? plasmoid.configuration.smoothing / 100.0 : 0.15

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

    // ── Ambient light sensor ────────────────────────────────────────────────
    LightSensor {
        id: lightSensor
        active: plasmoid.configuration.enabled
        dataRate: 1

        onActiveChanged: { if (!active) root.emaLux = -1 }

        // Only capture the latest lux value; EMA is driven by emaTimer below.
        onReadingChanged: {
            root.sensorAvailable = true
            root.currentLux = reading.illuminance  // [lux]
        }
    }

    // EMA timer: ticks at 0.4 Hz, deterministic frequency regardless of whether
    // the sensor value changed (onReadingChanged only fires on value change).
    Timer {
        id: emaTimer
        interval: 2500
        repeat: true
        running: lightSensor.active && root.sensorAvailable
        onTriggered: { if (root.currentLux > 0) root.applyLux(root.currentLux) }
    }

    // ── Brightness curve ────────────────────────────────────────────────────

    // Private: log10-normalised position of lux within [luxMin, luxMax].
    // Returns t [ratio 0..1] — clamped, so out-of-range lux maps to 0 or 1.
    function _luxToT(lux /* [lux] */) /* [ratio 0..1] */ {
        const cfg  = plasmoid.configuration
        const logA /* [log10(lux)] */ = Math.log10(Math.max(1, cfg.luxMin))
        const logB /* [log10(lux)] */ = Math.max(logA + 0.1,
                                            Math.log10(Math.max(1, cfg.luxMax)))
        return Math.max(0, Math.min(1, (Math.log10(Math.max(1, lux)) - logA) / (logB - logA)))
    }

    // Maps ambient lux to target brightness [%] with gamma bias remap.
    //
    // Because the linear curve normalises to t (normAuto === t), the full
    // pipeline simplifies to a single power function applied to t:
    //   output = minBr + t^γ × (maxBr − minBr)
    //
    // Gamma semantics:
    //   userBias = 50  →  γ = 1  →  identity (neutral), always
    //   userBias > 50  →  γ < 1  →  brighter overall
    //   userBias < 50  →  γ > 1  →  dimmer overall

    // Second stage: gamma remap + range scale. Input is the normalised log-position t.
    function _tToPercent(t /* [ratio 0..1] */) /* [%] */ {
        const cfg    = plasmoid.configuration
        const range  /* [%] */ = cfg.maxBrightness - cfg.minBrightness
        if (range <= 0) return cfg.minBrightness

        // userBias [%abs 0..100] → midpoint anchor [ratio 0..1]
        // Anchored on absolute 0-100 scale: userBias=50 is always γ=1.
        const normAnchor /* [ratio 0..1] */ = Math.max(0.001, Math.min(0.999,
                                                  cfg.userBias / 100))
        const gamma    /* [dimensionless] */ = Math.log(normAnchor) / Math.log(0.5)
        const remapped /* [ratio 0..1] */    = Math.pow(t, gamma)

        return cfg.minBrightness /* [%] */ + remapped * range /* [%] */
    }

    // Full pipeline: lux → t → brightness [%]. Convenience wrapper.
    function luxToPercent(lux /* [lux] */) /* [%] */ {
        return _tToPercent(_luxToT(lux))
    }

    // Internal: send a raw brightness value to PowerDevil and record it.
    function _applyRaw(targetRaw /* [raw 0..maxRaw] */) {
        const service = pmSource.serviceForSource("PowerDevil")
        if (!service) return
        const op      = service.operationDescription("setBrightness")
        op.brightness = targetRaw   // [raw]
        op.silent     = true
        service.startOperationCall(op)
        lastSetRaw        = targetRaw   // [raw]
        currentBrightness = targetRaw   // [raw]
    }

    function forceApply() {
        if (!plasmoid.configuration.enabled) return
        if (currentLux > 0) emaLux = currentLux   // snap EMA [lux] to current sensor reading
        if (emaLux <= 0) return
        // luxLogPos is up-to-date after emaLux snap; use cached t to avoid double _luxToT
        _applyRaw(Math.round(_tToPercent(luxLogPos /* [ratio] */) /* [%] */ / 100 * maxRaw /* [raw] */))
    }

    // Called on every sensor reading: EMA smoothing + hysteresis gate.
    function applyLux(rawLux /* [lux] */) {
        if (!plasmoid.configuration.enabled) return

        // Exponential moving average
        emaLux /* [lux] */ = (emaLux < 0) ? rawLux : (alpha * rawLux + (1 - alpha) * emaLux)

        // luxLogPos updates reactively from emaLux; use it to avoid recomputing _luxToT
        const targetRaw /* [raw] */ = Math.round(_tToPercent(luxLogPos) / 100 * maxRaw)
        const threshold /* [raw] */ = Math.max(1, Math.round(0.01 * maxRaw))
        if (lastSetRaw >= 0 && Math.abs(targetRaw - lastSetRaw) < threshold) return

        _applyRaw(targetRaw)
    }
}
