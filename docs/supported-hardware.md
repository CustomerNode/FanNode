# Supported hardware

FanNode targets Dell desktops where the BIOS fan curve can be observed to behave incorrectly and the `dell_smm_hwmon` driver exposes a writable `pwm1`.

## Confirmed working

| Model | BIOS | CPU | Notes |
|---|---|---|---|
| Dell Studio XPS 9100 | A04 (10/21/2010) | Intel Core i7 X 980 (Westmere, 6c/12t) | Original test bed. CPU fan thermistor degraded; daemon controls cleanly. |

## Likely-compatible (untested — please report back)

These models share the same `dell_smm-isa` fan layout (`Processor Fan` / `Motherboard Fan` / `Power Supply Fan`) and the same broad firmware family:

- Dell Studio XPS 8100
- Dell Studio XPS 7100
- Dell Optiplex 980
- Dell Optiplex 990
- Dell Precision T1500 / T3500

If you run FanNode on any of these (or any other Dell desktop), please open a [hardware report](https://github.com/CustomerNode/FanNode/issues/new?template=hardware-report.yml). Even a one-line "works" or "doesn't work" is useful.

## Known incompatible

- **Dell laptops.** Use [`i8kmon`](https://github.com/vitorafsr/i8kutils) instead — it's purpose-built for the laptop SMM fan-control quirks.
- **Modern Dell desktops (post-2017).** Newer BIOSes drive fan curves from CPU package temperature, not from a fan thermistor. They don't exhibit the failure mode FanNode addresses.
- **Non-Dell hardware.** No `dell_smm_hwmon`, nothing for FanNode to write to.

## Hardware that *should* work but probably won't

If your `dell_smm_hwmon` exposes `pwm1` as read-only (mode `0444` rather than `0644`), the kernel module was loaded without `force=1` or your BIOS doesn't permit SMM fan writes. FanNode will refuse to start with a clear error.

See [troubleshooting.md](troubleshooting.md#pwm-not-writable).
