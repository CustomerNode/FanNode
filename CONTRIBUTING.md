# Contributing to FanNode

Thanks for your interest. This project's most valuable contribution is **hardware reports** — confirming whether FanNode works on a given Dell model unblocks other users.

## Hardware reports

Open a [hardware report issue](https://github.com/CustomerNode/FanNode/issues/new?template=hardware-report.yml). The template asks for:

- Output of `sensors -u`
- Output of `lspci -nn | head -10`
- Output of `dmidecode -t bios -t baseboard` (run as root)
- Whether the daemon successfully drives `pwm1`
- Idle and load core temps with FanNode active vs disabled

## Code changes

```bash
git clone https://github.com/CustomerNode/FanNode.git
cd FanNode
# edit
shellcheck bin/fannode install.sh
shfmt -d bin/fannode install.sh
./tests/smoke.sh
```

CI runs `shellcheck` and `shfmt -d`. PRs that fail either are auto-blocked.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(applet): show fan RPM in tooltip
fix(daemon): handle missing coretemp hwmon gracefully
docs: add Optiplex 990 to supported-hardware
```

## Scope

FanNode is intentionally narrow: **drive a Dell desktop CPU fan when the BIOS won't.**

Out of scope:
- Laptop fan control (use `i8kmon`)
- GPU fan control
- Multi-fan curves beyond what `dell_smm_hwmon` already exposes
- Any change that requires running outside `dell_smm_hwmon`

If you want to extend the project, propose a discussion issue first.
