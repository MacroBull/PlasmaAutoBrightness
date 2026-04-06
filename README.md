# Auto Brightness — KDE Plasma 5 Plasmoid

A system-tray plasmoid for **KDE Plasma 5** that automatically adjusts screen brightness based on the ambient light sensor (ALS), with user-tunable bias and range controls.

> **Plasma 6.6+** ships native ALS auto-brightness. This plasmoid targets **Plasma 5.24 – 5.27** on systems where the hardware is ready but the desktop isn't.

---

## Features

- Pure QML — no Python, no C++, no daemons
- Reads ALS via [`iio-sensor-proxy`](https://gitlab.freedesktop.org/hadess/iio-sensor-proxy) through Qt Sensors
- Controls brightness via PowerDevil (D-Bus), same path the system uses
- Log-scale lux curve with configurable thresholds
- Gamma-remap bias: shift the curve dim/bright without breaking the endpoints
- Dual-handle range slider for min/max brightness bounds
- EMA smoothing with configurable responsiveness
- Live curve chart showing the current lux→brightness mapping
- Presets: Standard / OLED safe / Night

---

## Requirements

| Component | Minimum |
|-----------|---------|
| KDE Plasma | 5.24 |
| Qt | 5.15 |
| `iio-sensor-proxy` | any |
| `qml-module-qtsensors` | 5.x |

On Ubuntu/Debian:

```bash
sudo apt install iio-sensor-proxy qml-module-qtsensors
```

Verify your ALS sensor is working:

```bash
monitor-sensor   # should print LightLevel updates
```

---

## Installation

```bash
git clone https://github.com/macrobull/PlasmaAutoBrightness
cd PlasmaAutoBrightness
bash install.sh
```

Then add the **Auto Brightness** widget to your system tray via *Right-click panel → Add Widgets*.

To test without touching your panel:

```bash
plasmawindowed org.kde.plasma.autobrightness
```

---

## Lux → Brightness Pipeline

```
ALS sensor (lux)
      │
      ▼
 ┌─────────────────────────────────────────────────┐
 │  EMA smoothing                                   │
 │  emaLux = α·rawLux + (1−α)·emaLux               │
 │  α = smoothing / 100  (default 0.15)             │
 └──────────────────────────┬──────────────────────┘
                            │  emaLux  [lux]
                            ▼
 ┌─────────────────────────────────────────────────┐
 │  Log-scale curve                                 │
 │                                                  │
 │  t = (log₁₀(lux) − log₁₀(luxMin))              │
 │      ─────────────────────────────   ∈ [0, 1]   │
 │      (log₁₀(luxMax) − log₁₀(luxMin))            │
 │                                                  │
 │  auto = minBr + t · (maxBr − minBr)   [%]       │
 └──────────────────────────┬──────────────────────┘
                            │  auto  [%]
                            ▼
 ┌─────────────────────────────────────────────────┐
 │  Gamma bias remap                                │
 │                                                  │
 │  normAnchor = userBias / 100          ∈ (0, 1)  │
 │  γ          = log(normAnchor) / log(0.5)         │
 │  output = minBr + t^γ · (maxBr − minBr)    [%]  │
 │                                                  │
 │  (normAuto ≡ t, so the normalise step drops out) │
 └──────────────────────────┬──────────────────────┘
                            │  output  [%]
                            ▼
 ┌─────────────────────────────────────────────────┐
 │  Hysteresis gate                                 │
 │  skip if |targetRaw − lastSetRaw| < 1% maxRaw   │
 └──────────────────────────┬──────────────────────┘
                            │
                            ▼
              PowerDevil setBrightness (D-Bus)
```

### Stage 1 — EMA Smoothing

Exponential moving average prevents the screen from flickering in response to rapid sensor jitter:

```
emaLux = α · rawLux + (1 − α) · emaLux
```

`α` (`smoothing / 100`, default `0.15`) controls the trade-off:
- Low α → slow response, stable brightness
- High α → fast response, may flicker in unstable light

A fallback timer fires every 2 s to ensure EMA converges even when the sensor reports no change (some backends only emit signals on value change).

### Stage 2 — Log-Scale Curve

Human perception of brightness is roughly logarithmic. Mapping lux linearly would produce almost no change indoors and a huge jump in sunlight. The log-scale mapping distributes the curve evenly across the perceived range:

```
t = clamp((log₁₀(lux) − log₁₀(luxMin)) / (log₁₀(luxMax) − log₁₀(luxMin)), 0, 1)
auto_brightness = minBrightness + t × (maxBrightness − minBrightness)
```

| Config key | Default | Meaning |
|------------|---------|---------|
| `luxMin` | 5 lux | Lux at which screen reaches `minBrightness` |
| `luxMax` | 5000 lux | Lux at which screen reaches `maxBrightness` |
| `minBrightness` | 5 % | Floor brightness |
| `maxBrightness` | 100 % | Ceiling brightness |

### Stage 3 — Gamma Bias Remap

The bias slider lets users shift the curve without breaking the endpoints. It applies a power function within the `[minBr, maxBr]` range:

```
γ = log(userBias / 100) / log(0.5)

output = minBr + t^γ × (maxBr − minBr)
```

Since `normAuto ≡ t` (the linear curve already normalises to `t`), the separate normalise step drops out and the formula is a direct power function on `t`.

Key points:
- `userBias = 50` → `γ = 1` → identity (no change), regardless of `minBr`/`maxBr`
- `userBias > 50` → `γ < 1` → curve bends up (overall brighter)
- `userBias < 50` → `γ > 1` → curve bends down (overall dimmer)

The anchor is normalised over the absolute 0–100 % range, so "50 = neutral" is always true regardless of what min/max are set to.

### Stage 4 — Hysteresis Gate

Avoids redundant D-Bus calls when the computed brightness hasn't meaningfully changed:

```
skip if |targetRaw − lastSetRaw| < max(1, 1% × maxRaw)
```

---

## Configuration

### In-popup controls (instant effect)

| Control | Description |
|---------|-------------|
| Enable switch | Pause/resume the auto-brightness loop |
| Bias slider | 0 = always dim · 50 = neutral · 100 = always bright |
| Range slider | Min and max brightness bounds |
| Presets | Standard · OLED safe (40–80 %) · Night (1–30 %) |

### Advanced (via widget settings page)

| Key | Default | Description |
|-----|---------|-------------|
| `luxMin` | 5 lux | Dark threshold (lower end of lux curve) |
| `luxMax` | 5000 lux | Bright threshold (upper end of lux curve) |
| `smoothing` | 15 | EMA factor × 100 (5 = slow, 50 = fast) |

---

## Architecture

```
main.qml                    — root Item; sensor, PowerDevil, brightness logic
├── LightSensor             — QtSensors 5.0, backed by iio-sensor-proxy
├── PlasmaCore.DataSource   — powermanagement engine → PowerDevil
├── _luxToT(lux)            — log-scale normalisation → t ∈ [0,1]
├── _tToPercent(t)          — gamma bias remap + range scale → brightness %
├── luxToPercent(lux)       — convenience: _tToPercent(_luxToT(lux))
├── luxAtT(t)               — inverse of _luxToT; used for axis labels
├── _applyRaw()             — D-Bus setBrightness wrapper
├── applyLux()              — EMA + hysteresis gate (called by emaTimer)
└── forceApply()            — snaps EMA to current lux; used by slider Connections

FullRepresentation.qml      — popup UI
├── Section 1: Info         — ambient lux + brightness rows with inline bars
├── Curve chart             — Canvas, log-X, animated position dot
├── Section 2: Controls     — bias Slider + min/max RangeSlider
└── Section 3: Presets      — Standard / OLED safe / Night buttons

configGeneral.qml           — settings page (advanced only)
├── Lux curve               — luxMin / luxMax SpinBoxes
└── Responsiveness          — smoothing Slider
```

---

## License

GPL-2.0-or-later

---

## Credits

Written by [MacroBull](https://github.com/macrobull) with [GitHub Copilot](https://github.com/features/copilot).
