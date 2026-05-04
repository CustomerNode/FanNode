# How it works

The short version: the Studio XPS 9100 BIOS reads CPU temperature from a thermistor inside the original CPU fan, not from the CPU's own thermal sensors. When that thermistor degrades — common after 15+ years — the BIOS thinks the system is always cool. Cores hit 90°C while the fan idles at 1000 RPM. FanNode bypasses the BIOS curve in userland.

## The BIOS quirk

The Studio XPS 9100 ships with BIOS A04 (10/21/2010), which is the **final** BIOS Dell ever released for this model. There is no A05.

In Dell community threads from the era, Dell engineers explain the fan-control architecture:

> "Dell has a special temperature sensor in the original fan that controls the fan speed through the BIOS. However, if there's a fan error … BIOS won't be able to control the fan's speed based on CPU temps and cooling needs."

That sensor is a small thermistor mounted in the fan's plastic body, typically on the heatsink-side intake. The BIOS reads it via SMM (System Management Mode) — the same hidden execution context that handles things like power-management quirks. Linux can't see SMM activity directly.

When the thermistor returns realistic values, the BIOS ramps the fan correctly. When it ages out, gives up, or is replaced with a generic non-Dell fan that lacks the thermistor entirely, the BIOS effectively reads "always cool" and pins the fan at minimum.

The Linux `coretemp` driver, by contrast, reads the actual silicon temperatures from each core's on-die thermal sensor. Those numbers are accurate and never go away — they're literally part of the CPU.

## Where FanNode fits

```text
   ┌──────────────┐  read /sys/.../temp*_input  ┌────────────────────────┐
   │   coretemp   │ ──────────────────────────▶ │   fannode (bash, ~250  │
   │ (per-die)    │                             │   lines, root, in PID 1)│
   └──────────────┘                             └────────────┬───────────┘
                                                              │
                                          write to PWM file   │
                                                              ▼
                          ┌────────────────────────────────────────┐
                          │ /sys/class/hwmon/hwmonX/pwm1           │
                          │  (dell_smm_hwmon laptop driver, used   │
                          │   on this desktop with a quirk match)  │
                          └────────────────┬──────────────────────┘
                                           │
                                           ▼
                                       CPU fan
```

FanNode's control loop, every `INTERVAL` seconds (default 3):

1. Read every `temp*_input` from the `coretemp` hwmon. Take the **max**.
2. Map that temperature to a zone (`normal` / `warm` / `hot` / `critical`), with hysteresis to prevent oscillation.
3. Write the zone's target PWM (0–255) to the `dell_smm_hwmon` pwm1 file.
4. Atomically write a status JSON to `/run/fannode/status.json` for the applet/indicator to read.
5. Detect anomalies (BIOS reclaim, sustained hot, thermal overrun, sensor error) and reflect them in the `health` field.

## The tug-of-war with the BIOS

The Dell BIOS does not give up easily. Even with `dell_smm_hwmon` exposing writable `pwm1`, the BIOS will reclaim control after a few minutes if FanNode stops asserting. We confirmed this experimentally:

```text
t=0    pwm1 written = 255           fan ramps 1020 → 3600 RPM
t=60s  pwm1 reads back = 255        fan still 3600 RPM
t=4m   pwm1 reads back = 0          fan back to 1020 RPM (BIOS won)
```

The defense is simple: **re-assert on a tight interval**. At 3-second polling, the BIOS never gets a window long enough to override us. The daemon also tracks how often pwm reads back lower than what we wrote — that count surfaces in `fannode status` and triggers `health=bios_reclaim` if we ever start losing the battle.

When the daemon stops (via `systemctl stop fannode` or reboot), it does *not* try to fight back. We let the BIOS resume its lazy curve. There's no persistent state to clean up.

## Why a userland daemon and not a kernel patch

Three reasons:

1. **Scope.** The right fix lives in BIOS firmware — but Dell stopped patching this hardware in 2010. The right second-best fix lives in the kernel's `dell_smm_hwmon` driver, but a kernel patch would have to negotiate with all Dell desktops on this codepath, not just the XPS 9100. FanNode is intentionally narrow: this exact failure mode on this exact family.

2. **Reversibility.** A userland daemon writing to `/sys` makes zero permanent changes. Stop the service, reboot, and you're back to stock behavior. A kernel patch couldn't promise that.

3. **Iteration speed.** The fan-curve, hysteresis, and health thresholds need real-world tuning. A bash file you can edit and `systemctl restart` beats a kernel module rebuild.

## What FanNode is *not*

- Not a Dell laptop fan controller — for that, see [`i8kmon`](https://github.com/vitorafsr/i8kutils).
- Not a GPU fan controller.
- Not a replacement for cleaning your heatsink. If your CPU is at 90°C at idle, FanNode will keep the system from freezing — but the underlying problem is dust, paste, or a dying fan, and that's what you should fix first.

## References

- [Dell Studio XPS 9100 System BIOS, A04 (final)](https://www.dell.com/support/home/en-us/drivers/driversdetails?driverid=2ydk7) — the last firmware Dell ever shipped for this model.
- [Studio XPS 9100, CPU fan replacement (Dell Community)](https://www.dell.com/community/XPS-Desktops/Studio-XPS-9100-cpu-fan-replacement/td-p/7399220) — confirms the in-fan thermistor architecture.
- [Studio XPS 9100 Service Manual (PDF)](https://dl.dell.com/manuals/all-products/esuprt_desktop/esuprt_studio_xps_desktop/studio-xps-9100_service%20manual_en-us.pdf) — official thermal/cooling documentation.
- [`dell_smm_hwmon` kernel driver](https://www.kernel.org/doc/Documentation/hwmon/dell-smm-hwmon.rst) — the userland-facing fan control surface FanNode uses.
