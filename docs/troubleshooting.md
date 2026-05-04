# Troubleshooting

Run `fannode doctor` first. It checks hardware, modules, file permissions, and service state, and tells you what's missing.

## "pwm1 not writable"

```text
FATAL: pwm1 not writable at /sys/class/hwmon/hwmon0/pwm1 (run as root)
```

Three reasons this happens:

1. **You ran as a non-root user.** Use `sudo systemctl start fannode` — the systemd unit handles privileges correctly.
2. **`dell_smm_hwmon` was loaded without `force=1` on a desktop.** The driver is officially a *laptop* driver. On unsupported desktops it usually still loads in read-only mode. Run:
   ```bash
   echo 'options dell_smm_hwmon force=1 restricted=0' | sudo tee /etc/modprobe.d/dell_smm_hwmon.conf
   sudo modprobe -r dell_smm_hwmon
   sudo modprobe dell_smm_hwmon
   ```
3. **The wrong hwmon path.** Auto-discovery picks the hwmon named `dell_smm`, but if your system has multiple, set `PWM_FILE` and `TACH_FILE` explicitly in `/etc/fannode.conf`.

## "coretemp hwmon not found"

Make sure the `coretemp` module is loaded:

```bash
sudo modprobe coretemp
```

The installer adds this to `/etc/modules-load.d/fannode.conf` so it persists across reboots.

## Service starts, but the fan still won't ramp

Confirm the daemon is actually writing:

```bash
fannode status --json
watch -n1 'cat /sys/class/hwmon/hwmon0/pwm1'
```

If `fannode status` shows a sane PWM (e.g., 180 in the warm zone) but the actual file reads 0, the BIOS is winning the tug-of-war. Two paths:

1. **Drop `INTERVAL`.** Default is 3 seconds; try 2 or even 1.
2. **Check `bios_reclaim_count`.** If it's growing over time, your BIOS is reclaiming faster than the default interval re-asserts.

## Cinnamon applet doesn't appear in the Add Applet dialog

The applet was installed system-wide to `/usr/share/cinnamon/applets/fannode@customernode/`. Cinnamon caches the applet list; restart the panel:

```text
Alt+F2  →  type r  →  Enter
```

Then right-click panel → Applets → "Manage" tab. FanNode should be in the list.

## AppIndicator doesn't show up in the tray

Two likely causes on Mint:

1. **Missing GI bindings.** Re-run the installer, or:
   ```bash
   sudo apt install python3-gi gir1.2-ayatanaappindicator3-0.1 gir1.2-notify-0.7
   ```
2. **Cinnamon doesn't show legacy tray icons by default.** Right-click panel → Applets → enable "XApp Status Applet" — it relays AppIndicators into the panel.

(If you're on Cinnamon, prefer the FanNode applet over the AppIndicator — same data, native panel integration.)

## Notification popups don't fire

If `fannode status` shows `health` flipping but no popup appears:

- **Cinnamon:** Make sure "Notifications" is enabled in System Settings → Notifications.
- **Other DEs:** Check that a notification daemon (`mate-notification-daemon`, `xfce4-notifyd`, etc.) is running.
- **Fallback test:**
  ```bash
  notify-send -u critical "test" "FanNode notification test"
  ```
  If this also fails to pop, the issue is your DE's notification setup, not FanNode.

## "Hardware not in tested set" warning

FanNode has only been tested on the Dell Studio XPS 9100. The installer warns and asks before continuing on anything else. If it works for you, please file a [hardware report](https://github.com/CustomerNode/FanNode/issues/new?template=hardware-report.yml) so the next person knows.

## Removing FanNode cleanly

```bash
fannode uninstall              # keeps /etc/fannode.conf
fannode uninstall --purge      # removes config too
```

The BIOS regains fan control automatically within a few minutes. No reboot required.
