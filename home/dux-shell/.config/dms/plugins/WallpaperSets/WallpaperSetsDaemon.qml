import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import "sets.js" as Sets

// IPC surface: `dms ipc call wallpaperSets <fn> [name]`, for keybinds and
// scripts. The dash tab (WallpaperSetsTab.qml) is the GUI for the same data.
Item {
    id: root

    property string pluginId: ""
    property var pluginService: null

    function sets() {
        return Sets.load(pluginService, pluginId);
    }

    function applyAt(list, index) {
        const set = list[index];
        const result = Sets.apply(set, SessionData, Quickshell.screens);
        let msg = "SUCCESS: applied set \"" + set.name + "\" to " + (result.applied.join(", ") || "no outputs");
        if (result.missing.length > 0)
            msg += " (not connected: " + result.missing.join(", ") + ")";
        return msg;
    }

    function step(delta) {
        const list = sets();
        if (list.length === 0)
            return "ERROR: no wallpaper sets saved";
        const current = Sets.activeIndex(list, SessionData, Quickshell.screens);
        const start = current < 0 ? (delta > 0 ? -1 : 0) : current;
        const next = ((start + delta) % list.length + list.length) % list.length;
        return applyAt(list, next);
    }

    IpcHandler {
        target: "wallpaperSets"

        // One set per line; the active one is prefixed with "* ".
        function list(): string {
            const all = root.sets();
            if (all.length === 0)
                return "";
            const active = Sets.activeIndex(all, SessionData, Quickshell.screens);
            return all.map((s, i) => (i === active ? "* " : "  ") + s.name).join("\n");
        }

        function current(): string {
            const all = root.sets();
            const active = Sets.activeIndex(all, SessionData, Quickshell.screens);
            return active < 0 ? "" : all[active].name;
        }

        function show(name: string): string {
            const all = root.sets();
            const i = Sets.indexOf(all, name);
            if (i < 0)
                return "ERROR: no set named \"" + name + "\"";
            const s = all[i];
            return Sets.orderedOutputs(s.wallpapers, s.layout, Quickshell.screens).map(o => o + "\t" + s.wallpapers[o]).join("\n");
        }

        function apply(name: string): string {
            const all = root.sets();
            const i = Sets.indexOf(all, name);
            if (i < 0)
                return "ERROR: no set named \"" + name + "\"";
            return root.applyAt(all, i);
        }

        // Saves (or overwrites) a set from what each display shows now.
        function save(name: string): string {
            if (!name || !name.trim())
                return "ERROR: no name provided";
            const all = root.sets();
            const existed = Sets.indexOf(all, name) >= 0;
            const next = Sets.upsert(all, name, Sets.snapshot(SessionData, Quickshell.screens), Sets.layoutOf(Quickshell.screens));
            Sets.store(root.pluginService, root.pluginId, next);
            return "SUCCESS: " + (existed ? "updated" : "saved") + " set \"" + name.trim() + "\"";
        }

        function remove(name: string): string {
            const all = root.sets();
            if (Sets.indexOf(all, name) < 0)
                return "ERROR: no set named \"" + name + "\"";
            Sets.store(root.pluginService, root.pluginId, Sets.without(all, name));
            return "SUCCESS: removed set \"" + name + "\"";
        }

        function next(): string {
            return root.step(1);
        }

        function prev(): string {
            return root.step(-1);
        }
    }
}
