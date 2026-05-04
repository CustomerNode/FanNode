#!/usr/bin/env bash
# FanNode installer.
# Safe to curl-pipe:  curl -fsSL https://raw.githubusercontent.com/CustomerNode/FanNode/main/install.sh | bash
# Idempotent: re-running upgrades in place; existing /etc/fannode.conf is preserved.

set -euo pipefail

REPO_URL="https://github.com/CustomerNode/FanNode.git"
INSTALL_PREFIX=/usr/local
BIN_DIR="${INSTALL_PREFIX}/bin"
SHARE_DIR="${INSTALL_PREFIX}/share/fannode"
SYSTEMD_DIR=/etc/systemd/system
CONFIG_FILE=/etc/fannode.conf
APPLET_UUID="fannode@customernode"
CINNAMON_APPLET_DIR=/usr/share/cinnamon/applets/${APPLET_UUID}
AUTOSTART_DIR=/etc/xdg/autostart

bold()   { printf '\033[1m%s\033[0m\n' "$*"; }
ok()     { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn()   { printf '  \033[33m!\033[0m %s\n' "$*"; }
fail()   { printf '  \033[31m✗\033[0m %s\n' "$*"; }
die()    { fail "$*"; notify_critical "FanNode install failed" "$*"; exit 1; }

notify_critical() {
    # Best-effort GUI alert. Falls back silently if not in a desktop session.
    local title=$1 body=$2
    if command -v notify-send >/dev/null 2>&1; then
        # Try to reach the user's session even when run as root via sudo
        local user uid
        user="${SUDO_USER:-${USER:-}}"
        [[ -z "$user" ]] && return 0
        uid=$(id -u "$user" 2>/dev/null) || return 0
        sudo -u "$user" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
            DISPLAY="${DISPLAY:-:0}" \
            notify-send -u critical -i dialog-error "$title" "$body" 2>/dev/null || true
    fi
}

require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        bold "FanNode needs root to install. Re-running with sudo…"
        exec sudo -E bash "$0" "$@"
    fi
}

check_hardware() {
    bold "Checking hardware…"
    local product
    product=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || echo unknown)
    if [[ "$product" == *"Studio XPS 9100"* ]]; then
        ok "Detected: $product"
    else
        warn "Detected: $product"
        warn "FanNode is only tested on Dell Studio XPS 9100. It may still work."
        warn "Open a hardware report: https://github.com/CustomerNode/FanNode/issues"
        if [[ -t 0 ]]; then
            read -r -p "  Continue anyway? [y/N] " ans
            [[ "$ans" =~ ^[Yy] ]] || die "Aborted by user."
        else
            warn "Non-interactive install on untested hardware — proceeding."
        fi
    fi
}

check_modules() {
    bold "Checking kernel modules…"
    for mod in dell_smm_hwmon coretemp; do
        if lsmod | grep -q "^${mod}"; then
            ok "$mod loaded"
        else
            warn "$mod not loaded — attempting modprobe…"
            modprobe "$mod" 2>/dev/null || die "Failed to load $mod. FanNode cannot run without it."
            ok "$mod loaded"
        fi
    done
    # Persist auto-load on boot
    if ! grep -qsE '^dell_smm_hwmon$' /etc/modules-load.d/fannode.conf 2>/dev/null; then
        printf 'dell_smm_hwmon\ncoretemp\n' > /etc/modules-load.d/fannode.conf
        ok "Set modules to load on boot"
    fi
}

ensure_source_tree() {
    # If we're not running from inside a checkout, clone to a temp dir.
    if [[ -f ./bin/fannode && -f ./systemd/fannode.service ]]; then
        SRC=$(pwd)
        ok "Installing from local checkout: $SRC"
    else
        bold "Cloning FanNode…"
        SRC=$(mktemp -d)
        git clone --depth=1 "$REPO_URL" "$SRC" >/dev/null 2>&1 \
            || die "git clone failed. Is git installed?"
        ok "Cloned to $SRC"
    fi
}

install_files() {
    bold "Installing files…"
    install -m 0755 -d "$BIN_DIR" "$SHARE_DIR"
    install -m 0755 "$SRC/bin/fannode"           "$BIN_DIR/fannode"
    install -m 0755 "$SRC/install.sh"            "$SHARE_DIR/install.sh"
    install -m 0755 "$SRC/uninstall.sh"          "$SHARE_DIR/uninstall.sh"
    install -m 0644 "$SRC/systemd/fannode.service" "$SYSTEMD_DIR/fannode.service"

    if [[ -f "$CONFIG_FILE" ]]; then
        ok "Preserving existing $CONFIG_FILE"
    else
        install -m 0644 "$SRC/etc/fannode.conf" "$CONFIG_FILE"
        ok "Wrote default $CONFIG_FILE"
    fi
    ok "Daemon installed at $BIN_DIR/fannode"
}

install_indicator_icons() {
    # Used by both the AppIndicator and any out-of-tree consumer.
    install -m 0755 -d /usr/share/fannode/icons
    if [[ -d "$SRC/applet/$APPLET_UUID/icons" ]]; then
        cp "$SRC/applet/$APPLET_UUID/icons/"*.svg /usr/share/fannode/icons/
        find /usr/share/fannode/icons -type f -exec chmod 0644 {} \;
        ok "Indicator icons installed at /usr/share/fannode/icons"
    fi
}

install_indicator_deps() {
    # Best-effort: install GI bindings the indicator needs, on apt-based systems.
    command -v apt-get >/dev/null 2>&1 || return 0
    local missing=()
    dpkg -s python3-gi               >/dev/null 2>&1 || missing+=(python3-gi)
    dpkg -s gir1.2-notify-0.7        >/dev/null 2>&1 || missing+=(gir1.2-notify-0.7)
    if ! dpkg -s gir1.2-ayatanaappindicator3-0.1 >/dev/null 2>&1 \
        && ! dpkg -s gir1.2-appindicator3-0.1     >/dev/null 2>&1; then
        missing+=(gir1.2-ayatanaappindicator3-0.1)
    fi
    if [[ ${#missing[@]} -gt 0 ]]; then
        bold "Installing AppIndicator dependencies: ${missing[*]}"
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}" \
            || warn "Could not install AppIndicator deps. The applet/CLI still work; the tray icon may not."
    fi
}

install_indicator() {
    [[ -f "$SRC/indicator/fannode-indicator" ]] || return 0
    install_indicator_deps
    install_indicator_icons
    install -m 0755 "$SRC/indicator/fannode-indicator" "$BIN_DIR/fannode-indicator"
    if [[ -f "$SRC/indicator/fannode-indicator.desktop" ]]; then
        install -m 0644 "$SRC/indicator/fannode-indicator.desktop" \
            "$AUTOSTART_DIR/fannode-indicator.desktop"
        ok "AppIndicator installed (autostarts on next login)"
    fi
}

install_applet() {
    if [[ ! -d "$SRC/applet/$APPLET_UUID" ]]; then
        return 0
    fi
    if pgrep -x cinnamon >/dev/null 2>&1 || [[ "${XDG_CURRENT_DESKTOP:-}" == *"Cinnamon"* ]]; then
        bold "Cinnamon detected — installing applet…"
        install -m 0755 -d "$CINNAMON_APPLET_DIR/icons"
        cp -r "$SRC/applet/$APPLET_UUID/." "$CINNAMON_APPLET_DIR/"
        find "$CINNAMON_APPLET_DIR" -type f -exec chmod 0644 {} \;
        ok "Applet installed at $CINNAMON_APPLET_DIR"
        ok "Enable it: right-click panel → Applets → search 'FanNode' → enable"
    else
        ok "Non-Cinnamon desktop — skipping applet (using AppIndicator instead)"
    fi
}

start_service() {
    bold "Starting fannode.service…"
    systemctl daemon-reload
    systemctl enable --now fannode.service
    sleep 2
    if systemctl is-active --quiet fannode.service; then
        ok "fannode.service is active"
    else
        fail "fannode.service failed to start"
        warn "Recent journal:"
        journalctl -u fannode.service --no-pager -n 20 || true
        notify_critical "FanNode failed to start" \
            "Check status with: sudo systemctl status fannode"
        exit 1
    fi
}

print_next_steps() {
    cat <<EOF

$(bold "FanNode installed.")

  Status:   fannode status
  Logs:     fannode tail
  Doctor:   fannode doctor
  Config:   $CONFIG_FILE
  Repo:     https://github.com/CustomerNode/FanNode

EOF
    if pgrep -x cinnamon >/dev/null 2>&1; then
        cat <<EOF
  Cinnamon applet:
    Right-click your panel → Applets → search "FanNode" → enable.
    A live core temperature will appear in the panel.

EOF
    fi
}

main() {
    require_root "$@"
    bold "Installing FanNode…"
    check_hardware
    check_modules
    ensure_source_tree
    install_files
    install_indicator
    install_applet
    start_service
    print_next_steps
}

main "$@"
