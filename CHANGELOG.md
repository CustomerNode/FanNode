# Changelog

All notable changes to FanNode are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial public release.
- `fannode` daemon with zone-based fan curve, hysteresis, and BIOS-reclaim detection.
- Hardened systemd unit (`NoNewPrivileges`, `ProtectSystem=strict`, write paths whitelisted).
- Idempotent `install.sh` and `fannode uninstall`.
- Cinnamon panel applet (`fannode@customernode`) with live in-panel temperature, color-coded fan icon, and critical-notify popups on health errors.
- AppIndicator (`fannode-indicator`) fallback for non-Cinnamon desktops.
- Documentation: how-it-works, supported-hardware, troubleshooting.
- CI: shellcheck + shfmt linting on every push.

[Unreleased]: https://github.com/CustomerNode/FanNode/compare/main...HEAD
