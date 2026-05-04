#!/usr/bin/env bash
# FanNode uninstaller. Removes all installed files and hands fan control
# back to the BIOS. Preserves /etc/fannode.conf unless --purge is given.

set -euo pipefail

PURGE=false
[[ "${1:-}" == "--purge" ]] && PURGE=true

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    exec sudo -E bash "$0" "$@"
fi

bold "Removing FanNode…"

if systemctl is-active --quiet fannode.service 2>/dev/null; then
    systemctl stop fannode.service
    ok "Stopped fannode.service"
fi
if systemctl is-enabled --quiet fannode.service 2>/dev/null; then
    systemctl disable fannode.service
    ok "Disabled fannode.service"
fi

rm -f /etc/systemd/system/fannode.service
rm -f /usr/local/bin/fannode
rm -f /usr/local/bin/fannode-indicator
rm -f /etc/xdg/autostart/fannode-indicator.desktop
rm -rf /usr/local/share/fannode
rm -rf /usr/share/fannode
rm -rf /usr/share/cinnamon/applets/fannode@customernode
rm -rf /run/fannode
rm -f /etc/modules-load.d/fannode.conf
ok "Removed installed files"

if $PURGE; then
    rm -f /etc/fannode.conf
    ok "Removed /etc/fannode.conf (--purge)"
else
    if [[ -f /etc/fannode.conf ]]; then
        warn "Kept /etc/fannode.conf (use --purge to remove)"
    fi
fi

systemctl daemon-reload
ok "Reloaded systemd"

bold "FanNode is uninstalled."
echo "  Fan control will return to the BIOS within a few minutes."
