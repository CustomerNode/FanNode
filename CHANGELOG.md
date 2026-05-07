# Changelog

All notable changes to FanNode are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] — 2026-05-06

### Added
- Multi-fan management. The daemon can now drive any subset of dell_smm fans (`pwm1`, `pwm2`, `pwm3`) instead of only `pwm1`. Default on Studio XPS 9100 is `cpu` + `motherboard`. This is important on the 9100 because the BIOS commands `pwm2` to 0 if it ever flagged the original chassis fan as failed — leaving a freshly-installed replacement fan briefly powered at boot, then stalled.
- New config keys: `MANAGED_FANS`, `FAN_PWM_FILE[name]`, `FAN_TACH_FILE[name]`.
- New status JSON: `fans` map and `primary_fan` field. Per-fan `pwm`, `pwm_readback`, `rpm`, `bios_reclaim_count`. Legacy top-level fields (`fan_rpm`, `pwm`, `pwm_readback`, `bios_reclaim_count`) are preserved and now reflect the primary fan (first entry in `MANAGED_FANS`, normally `cpu`) so the Cinnamon applet and pre-0.2 consumers keep working unchanged.
- `fannode status` shows a per-fan table when `jq` is installed (PWM%, readback, RPM, BIOS reclaim count). Falls back to the old primary-fan summary if `jq` is absent.
- `fannode doctor` checks each managed fan's PWM/tach file individually.

### Changed
- `BIOS_RECLAIM_COUNT` is per-fan; the daemon's overall `bios_reclaim` health state triggers when the *sum across all managed fans* hits the existing 5-event threshold.
- `apply_pwm` takes a fan name argument; the main loop applies the zone-derived PWM to every managed fan each iteration.

### Fixed
- Installer no longer registers the AppIndicator autostart on Cinnamon systems where the applet is being installed — previously this left users with two redundant fan icons in the panel. Existing autostart files from older installs are removed on re-install. The `fannode-indicator` binary is still installed and can be run manually for users who prefer the tray indicator.

### Backward compatibility
- Old `PWM_FILE` and `TACH_FILE` settings in `/etc/fannode.conf` still work — they're treated as overrides for the `cpu` fan only. Existing installs that do nothing will silently start managing `pwm2` after upgrade.

[Unreleased]: https://github.com/CustomerNode/FanNode/compare/v0.2.0...HEAD
[0.2.0]:      https://github.com/CustomerNode/FanNode/compare/v0.1.0...v0.2.0

## [0.1.0]

### Added
- Initial public release.
- `fannode` daemon with zone-based fan curve, hysteresis, and BIOS-reclaim detection (drop > 24 PWM AND > 15% counts as a reclaim event).
- `pwm_readback` in status JSON reports what the BIOS actually has the PWM file set to, separate from what the daemon wrote. `fannode status` flags inline when they diverge.
- Hardened systemd unit (`NoNewPrivileges`, `ProtectSystem=strict`, write paths whitelisted).
- Idempotent `install.sh` and `fannode uninstall`.
- Cinnamon panel applet (`fannode@customernode`) with live in-panel temperature, color-coded fan icon, and critical-notify popups on health errors.
- AppIndicator (`fannode-indicator`) fallback for non-Cinnamon desktops.
- Documentation: how-it-works, supported-hardware, troubleshooting.
- CI: shellcheck + shfmt linting on every push.

[0.1.0]: https://github.com/CustomerNode/FanNode/releases/tag/v0.1.0
