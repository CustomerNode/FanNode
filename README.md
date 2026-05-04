<div align="center">

```
   ___       _   _      _      
  / __\__ _ | \ | | ___ | |_  ___ 
 / _\ / _` ||  \| |/ _ \| __|/ _ \
/ /  | (_| || |\  | (_) | |_|  __/
\/    \__,_||_| \_|\___/ \__|\___|
```

**BIOS-side fan control for hardware Dell forgot.**

Userland fan-curve daemon for the Dell Studio XPS 9100, with a Cinnamon panel applet and AppIndicator fallback.

[Install](#install) · [How it works](#how-it-works) · [Configuration](#configuration) · [Hardware support](docs/supported-hardware.md) · [Troubleshooting](docs/troubleshooting.md)

</div>

---

## Why

In 2010, Dell shipped a desktop where the BIOS reads CPU temperature from a thermistor inside a $20 fan.

Fifteen years later, those thermistors fail. The fan stops ramping. Cores hit 90°C while the fan idles at 1000 RPM. The BIOS sees nothing wrong. The system freezes.

A05 was never released. Dell stopped patching this hardware in 2010.

**FanNode is the BIOS patch Dell never wrote.** It reads live core temperatures from `coretemp`, applies a configurable fan curve, and writes PWM directly to `dell_smm_hwmon` — winning the tug-of-war with the BIOS by re-asserting the value every few seconds.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/CustomerNode/FanNode/main/install.sh | bash
```

The installer:

1. Verifies hardware (`Studio XPS 9100` family) and required kernel modules
2. Installs the daemon to `/usr/local/bin/fannode`
3. Drops a hardened systemd unit and starts it
4. Installs the Cinnamon applet (if Cinnamon is detected) or the AppIndicator fallback
5. Prints what to do next

To uninstall:

```bash
fannode uninstall
```

## Quick look

```text
$ fannode status

FanNode — active
Hottest core: Core 2 — 64°C
Fan: 1820 RPM (45% PWM)  Curve zone: warm
BIOS reclaim events: 0   Health: ok
Daemon: running for 2h 14m
```

In the Cinnamon panel:

```
…  🌀 47°C  🔊  🕐 14:32
```

The fan icon is green when normal, yellow in the warm zone, red in the hot zone, and turns red with a blinking outline plus a critical-notify popup if cooling can no longer keep up.

## How it works

The Studio XPS 9100's BIOS doesn't drive its fan curve from CPU core sensors. It reads a thermistor embedded in the original Dell CPU fan assembly. When that thermistor degrades — common after 15+ years — the BIOS thinks the system is always cool and pins the fan around 1000 RPM regardless of actual load.

FanNode bypasses that path entirely:

```
   ┌─────────────┐    poll 3s     ┌──────────────────────┐
   │  coretemp   │ ─────────────▶ │  fannode (daemon)    │
   │  hwmon      │                │  bash, ~250 lines    │
   └─────────────┘                └──────────┬───────────┘
                                              │ write
                                              ▼
                                  ┌─────────────────────┐
                                  │ /sys/.../hwmon0/pwm1 │
                                  └──────────┬───────────┘
                                              │
                                              ▼
                                          CPU fan
```

A status JSON is written to `/run/fannode/status.json` on each cycle. The Cinnamon applet and AppIndicator both consume that file.

For the full story including the BIOS reverse-engineering rabbit hole, see [docs/how-it-works.md](docs/how-it-works.md).

## Configuration

`/etc/fannode.conf`:

```ini
# Polling interval (seconds). BIOS reclaims after a few minutes,
# so values above ~10 risk losing the tug-of-war.
INTERVAL=3

# Fan curve: max-core-temp (°C) -> PWM (0-255)
CURVE_NORMAL_MAX_TEMP=70
CURVE_NORMAL_PWM=80
CURVE_WARM_MAX_TEMP=85
CURVE_WARM_PWM=180
CURVE_HOT_MAX_TEMP=95
CURVE_HOT_PWM=240
CURVE_CRITICAL_PWM=255

# Hysteresis: temp must drop this many °C below a zone boundary
# before stepping down. Prevents fan oscillation.
HYSTERESIS_DROP=3

# Health alerts
CRITICAL_TEMP=95
SUSTAINED_HOT_SECS=120
```

After editing, restart with `sudo systemctl restart fannode`.

## CLI

```text
fannode status      live status (text or --json)
fannode tail        follow journal (journalctl -fu fannode)
fannode doctor      check hardware, modules, permissions
fannode install     idempotent install (run by curl-pipe; safe to re-run)
fannode uninstall   reverse install, hand control back to BIOS
```

## Supported hardware

Tested on:

| Model | BIOS | Status |
|---|---|---|
| Dell Studio XPS 9100 | A04 | ✅ Working |

Likely-compatible (untested — please open a [hardware report](https://github.com/CustomerNode/FanNode/issues/new?template=hardware-report.yml) if you try):

- Other Westmere-era Dell Studio XPS desktops with `dell_smm-isa` fan layout
- Some Dell Optiplex 980 / 990 series

See [docs/supported-hardware.md](docs/supported-hardware.md) for details.

## Safety

- The daemon does not modify BIOS, firmware, or persistent settings. Stopping the service or rebooting hands fan control back to the BIOS within a few minutes.
- The systemd unit runs hardened: `NoNewPrivileges=yes`, `ProtectSystem=strict`, `ProtectHome=yes`, `PrivateTmp=yes`, write access limited to `/sys/class/hwmon/hwmon0/pwm1` and `/run/fannode`.
- The installer refuses to run on hardware it doesn't recognize.

## Contributing

Hardware reports are the most useful contribution — see the [hardware-report template](https://github.com/CustomerNode/FanNode/issues/new?template=hardware-report.yml).

For code: see [CONTRIBUTING.md](CONTRIBUTING.md). CI runs `shellcheck` and `shfmt`; PRs that don't pass them are auto-blocked.

## License

[MIT](LICENSE) © 2026 CustomerNode
