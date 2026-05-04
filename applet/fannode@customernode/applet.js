/*
 * FanNode Cinnamon applet
 * https://github.com/CustomerNode/FanNode
 *
 * Reads /run/fannode/status.json (written by the fannode daemon) and
 * displays a live max-core temperature plus a state-colored fan icon
 * in the panel. Pops a critical-notify on health errors.
 */

const Applet     = imports.ui.applet;
const PopupMenu  = imports.ui.popupMenu;
const Settings   = imports.ui.settings;
const Mainloop   = imports.mainloop;
const Main       = imports.ui.main;
const Util       = imports.misc.util;
const St         = imports.gi.St;
const GLib       = imports.gi.GLib;

const UUID = "fannode@customernode";
const STALE_AFTER_SECONDS = 30;

class FanNodeApplet extends Applet.TextIconApplet {
    constructor(metadata, orientation, panelHeight, instanceId) {
        super(orientation, panelHeight, instanceId);

        this._metadata = metadata;
        this._lastHealth = null;
        this._timeoutId = 0;

        this.settings = new Settings.AppletSettings(this, UUID, instanceId);
        this.settings.bind("show-temp-in-panel",  "showTempInPanel",  () => this._refresh());
        this.settings.bind("refresh-interval",    "refreshInterval",  () => {});
        this.settings.bind("notify-on-critical",  "notifyOnCritical", () => {});
        this.settings.bind("notify-on-recovery",  "notifyOnRecovery", () => {});
        this.settings.bind("status-file",         "statusFile",       () => {});

        this._setIcon("inactive");
        this.set_applet_label("—");
        this.set_applet_tooltip("FanNode — initializing");

        this._buildMenu();
        this._refresh();
    }

    _buildMenu() {
        this.menuManager = new PopupMenu.PopupMenuManager(this);
        this.menu = new Applet.AppletPopupMenu(this, this.actor.orientation || St.Side.TOP);
        this.menuManager.addMenu(this.menu);

        this._statusItem = new PopupMenu.PopupMenuItem("FanNode", { reactive: false });
        this._coreItem   = new PopupMenu.PopupMenuItem("",        { reactive: false });
        this._fanItem    = new PopupMenu.PopupMenuItem("",        { reactive: false });
        this._healthItem = new PopupMenu.PopupMenuItem("",        { reactive: false });

        this.menu.addMenuItem(this._statusItem);
        this.menu.addMenuItem(this._coreItem);
        this.menu.addMenuItem(this._fanItem);
        this.menu.addMenuItem(this._healthItem);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        this._addAction("Show details…",   "utilities-terminal-symbolic",
            () => this._spawnTerm("fannode status; read -p 'Press Enter to close…'"));
        this._addAction("View logs",       "view-list-symbolic",
            () => this._spawnTerm("fannode tail"));
        this._addAction("Run doctor",      "system-run-symbolic",
            () => this._spawnTerm("fannode doctor; read -p 'Press Enter to close…'"));
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        this._addAction("Open project page", "applications-internet-symbolic",
            () => Util.spawnCommandLine("xdg-open https://github.com/CustomerNode/FanNode"));
    }

    _addAction(label, iconName, callback) {
        const item = new PopupMenu.PopupIconMenuItem(label, iconName, St.IconType.SYMBOLIC);
        item.connect("activate", callback);
        this.menu.addMenuItem(item);
    }

    on_applet_clicked() {
        this.menu.toggle();
    }

    on_applet_removed_from_panel() {
        if (this._timeoutId) {
            Mainloop.source_remove(this._timeoutId);
            this._timeoutId = 0;
        }
        if (this.settings) this.settings.finalize();
    }

    _setIcon(state) {
        const path = `${this._metadata.path}/icons/fannode-${state}.svg`;
        try {
            this.set_applet_icon_path(path);
        } catch (e) {
            this.set_applet_icon_symbolic_name("fan-symbolic");
        }
    }

    _readStatus() {
        try {
            const [ok, contents] = GLib.file_get_contents(this.statusFile || "/run/fannode/status.json");
            if (!ok) return null;
            // contents is a Uint8Array; decode as UTF-8 (avoids the deprecated
            // implicit .toString() conversion that GJS warns about).
            const text = new TextDecoder("utf-8").decode(contents);
            return JSON.parse(text);
        } catch (e) {
            return null;
        }
    }

    _isFresh(status) {
        if (!status || !status.last_update) return false;
        const updated = Date.parse(status.last_update);
        if (isNaN(updated)) return false;
        return (Date.now() - updated) / 1000 < STALE_AFTER_SECONDS;
    }

    _refresh() {
        const status = this._readStatus();
        if (!status || !this._isFresh(status)) {
            this._renderInactive(status ? "stale" : "missing");
        } else {
            this._renderActive(status);
        }
        this._scheduleNext();
    }

    _scheduleNext() {
        if (this._timeoutId) Mainloop.source_remove(this._timeoutId);
        const interval = Math.max(1, this.refreshInterval || 2);
        this._timeoutId = Mainloop.timeout_add_seconds(interval, () => {
            this._refresh();
            return false;
        });
    }

    _renderInactive(reason) {
        this._setIcon("inactive");
        this.set_applet_label(this.showTempInPanel ? "—" : "");
        const tip = (reason === "stale")
            ? "FanNode daemon is not updating the status file (stale)."
            : "FanNode daemon is not running.\nStart it: sudo systemctl start fannode";
        this.set_applet_tooltip(tip);

        this._statusItem.label.set_text("FanNode — inactive");
        this._coreItem.label.set_text("");
        this._fanItem.label.set_text("");
        this._healthItem.label.set_text(tip);

        if (this._lastHealth !== "inactive" && this.notifyOnCritical) {
            this._criticalNotify(
                "FanNode stopped",
                "The FanNode daemon is not running. Fan control has reverted to the BIOS."
            );
        }
        this._lastHealth = "inactive";
    }

    _renderActive(status) {
        const zone   = status.zone || "normal";
        const maxT   = status.max_core_temp;
        const rpm    = status.fan_rpm;
        const pwm    = status.pwm;
        const pwmPct = Math.round((pwm * 100) / 255);
        const health = status.health || "ok";

        let iconState = zone === "critical" ? "critical" : zone;
        if (health === "thermal_overrun" || health === "sensor_error") iconState = "critical";
        this._setIcon(iconState);

        this.set_applet_label(this.showTempInPanel ? `${maxT}°C` : "");

        const tooltip = [
            "FanNode — active",
            `Hottest core: ${maxT}°C`,
            `Fan: ${rpm} RPM (${pwmPct}% PWM)`,
            `Curve zone: ${zone}`,
            `Health: ${health}`,
        ].join("\n");
        this.set_applet_tooltip(tooltip);

        this._statusItem.label.set_text(`FanNode — ${health === "ok" ? "active" : health}`);
        this._coreItem.label.set_text(`Hottest core: ${maxT}°C`);
        this._fanItem.label.set_text(`Fan: ${rpm} RPM (${pwmPct}% PWM, ${zone})`);
        this._healthItem.label.set_text(`Health: ${health}`);

        // Health transitions
        if (health !== this._lastHealth) {
            if (health !== "ok" && this.notifyOnCritical) {
                this._notifyHealth(health, status);
            } else if (health === "ok"
                       && this._lastHealth
                       && this._lastHealth !== "ok"
                       && this._lastHealth !== "inactive"
                       && this.notifyOnRecovery) {
                this._infoNotify("FanNode", "Temperatures back to normal.");
            }
        }
        this._lastHealth = health;
    }

    _notifyHealth(health, status) {
        const titles = {
            thermal_overrun: "FanNode: cooling can't keep up",
            sustained_hot:   "FanNode: sustained high temperature",
            bios_reclaim:    "FanNode: BIOS keeps reclaiming fan control",
            sensor_error:    "FanNode: sensor read error",
        };
        const bodies = {
            thermal_overrun:
                `Cores hit ${status.max_core_temp}°C with the fan already at maximum. Reduce load and check cooling.`,
            sustained_hot:
                "Cores have been hot for over 2 minutes. Investigate workload or cooling.",
            bios_reclaim:
                "The BIOS is repeatedly overriding FanNode's fan setting. Cooling may be intermittent.",
            sensor_error:
                "FanNode could not read CPU temperatures. Is the coretemp module loaded?",
        };
        this._criticalNotify(titles[health] || `FanNode: ${health}`,
                             bodies[health] || `Health state: ${health}`);
    }

    _criticalNotify(title, body) {
        try {
            Main.criticalNotify(title, body);
        } catch (e) {
            Util.spawnCommandLine(
                `notify-send -u critical -i dialog-error "${title}" "${body}"`);
        }
    }

    _infoNotify(title, body) {
        try {
            Main.notify(title, body);
        } catch (e) {
            Util.spawnCommandLine(`notify-send -u low "${title}" "${body}"`);
        }
    }

    _spawnTerm(cmd) {
        // Different terminals disagree on how to pass a command.
        // Modern GTK terminals (gnome-terminal, mate-terminal, xfce4-terminal,
        // tilix) want `-- bash -c CMD`. Classic terminals (xterm, konsole,
        // urxvt) want `-e bash -c CMD`. Try preferred, in order, and use the
        // array form of spawn so we don't have to escape shell quotes.
        const candidates = [
            ["gnome-terminal",  "--"],
            ["mate-terminal",   "--"],
            ["xfce4-terminal",  "--"],
            ["tilix",           "--"],
            ["konsole",         "-e"],
            ["urxvt",           "-e"],
            ["xterm",           "-e"],
        ];
        const envTerm = GLib.getenv("TERMINAL");
        if (envTerm) candidates.unshift([envTerm, "--"]);

        for (const [bin, sep] of candidates) {
            if (GLib.find_program_in_path(bin)) {
                Util.spawn([bin, sep, "bash", "-c", cmd]);
                return;
            }
        }
        // Last-resort fallback
        Util.spawn(["x-terminal-emulator", "-e", "bash", "-c", cmd]);
    }
}

function main(metadata, orientation, panelHeight, instanceId) {
    return new FanNodeApplet(metadata, orientation, panelHeight, instanceId);
}
