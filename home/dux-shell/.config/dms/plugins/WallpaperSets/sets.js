.pragma library

// Shared logic for the Wallpaper Sets plugin (daemon + dash tab).
// Pure functions: callers pass Dux's SessionData singleton, Quickshell.screens
// and the PluginService, so nothing here depends on the importing context.
//
// A set is { name, wallpapers: { <output>: <path or #colour> },
//            layout: { <output>: [x, y, width, height] }, savedAt }.
// `layout` is the screen geometry at save time, used to draw the preview
// in the physical left-to-right order even when an output is unplugged.

var KEY = "sets";

function normalize(raw) {
    if (!Array.isArray(raw))
        return [];
    var out = [];
    for (var i = 0; i < raw.length; i++) {
        var s = raw[i];
        if (!s || typeof s.name !== "string" || !s.name.trim())
            continue;
        if (!s.wallpapers || typeof s.wallpapers !== "object")
            continue;
        out.push({
            name: s.name.trim(),
            wallpapers: Object.assign({}, s.wallpapers),
            layout: s.layout && typeof s.layout === "object" ? Object.assign({}, s.layout) : {},
            savedAt: Number(s.savedAt) || 0
        });
    }
    return out;
}

function load(pluginService, pluginId) {
    if (!pluginService || !pluginId)
        return [];
    return normalize(pluginService.loadPluginData(pluginId, KEY, []));
}

function store(pluginService, pluginId, list) {
    if (!pluginService || !pluginId)
        return false;
    return pluginService.savePluginData(pluginId, KEY, normalize(list));
}

function indexOf(list, name) {
    var wanted = String(name || "").trim().toLowerCase();
    for (var i = 0; i < list.length; i++) {
        if (list[i].name.toLowerCase() === wanted)
            return i;
    }
    return -1;
}

function layoutOf(screens) {
    var layout = {};
    for (var i = 0; i < screens.length; i++) {
        var s = screens[i];
        layout[s.name] = [s.x, s.y, s.width, s.height];
    }
    return layout;
}

// Output names of a set, in physical order (left to right, then top down).
function orderedOutputs(wallpapers, layout, screens) {
    var live = layoutOf(screens || []);
    var names = Object.keys(wallpapers || {});
    function pos(name) {
        return live[name] || (layout && layout[name]) || [Number.MAX_SAFE_INTEGER, 0, 16, 9];
    }
    names.sort(function (a, b) {
        var pa = pos(a), pb = pos(b);
        return pa[0] - pb[0] || pa[1] - pb[1] || (a < b ? -1 : a > b ? 1 : 0);
    });
    return names;
}

// width / height of an output: live geometry first, then the saved layout.
function aspectOf(name, layout, screens) {
    var live = layoutOf(screens || []);
    var g = live[name] || (layout && layout[name]);
    if (!g || !(g[2] > 0) || !(g[3] > 0))
        return 16 / 9;
    return g[2] / g[3];
}

function snapshot(session, screens) {
    var wallpapers = {};
    for (var i = 0; i < screens.length; i++) {
        var name = screens[i].name;
        wallpapers[name] = session.getMonitorWallpaper(name) || "";
    }
    return wallpapers;
}

function upsert(list, name, wallpapers, layout) {
    var next = list.slice();
    var entry = {
        name: String(name).trim(),
        wallpapers: wallpapers,
        layout: layout,
        savedAt: Date.now()
    };
    var i = indexOf(next, name);
    if (i >= 0)
        next[i] = entry;
    else
        next.push(entry);
    return next;
}

function without(list, name) {
    var i = indexOf(list, name);
    if (i < 0)
        return list;
    var next = list.slice();
    next.splice(i, 1);
    return next;
}

// True when every connected output named in the set shows that set's image.
function matches(set, session, screens) {
    var connected = 0;
    for (var i = 0; i < screens.length; i++) {
        var name = screens[i].name;
        if (!(name in set.wallpapers))
            continue;
        connected++;
        if ((session.getMonitorWallpaper(name) || "") !== set.wallpapers[name])
            return false;
    }
    return connected > 0;
}

function activeIndex(list, session, screens) {
    for (var i = 0; i < list.length; i++) {
        if (matches(list[i], session, screens))
            return i;
    }
    return -1;
}

// Applies a set to the outputs that are connected now. Mirrors what
// `dms ipc call wallpaper setFor` does per output: turn per-display mode on,
// set the image, and drop that output's cycling folder so cycling doesn't
// immediately replace it. SessionData regenerates matugen colours only when
// the theme-source output changes, so this costs one regeneration at most.
function apply(set, session, screens) {
    var connected = {};
    for (var i = 0; i < screens.length; i++)
        connected[screens[i].name] = true;

    if (!session.perMonitorWallpaper)
        session.setPerMonitorWallpaper(true);

    var applied = [];
    var missing = [];
    var outputs = Object.keys(set.wallpapers);
    for (var j = 0; j < outputs.length; j++) {
        var name = outputs[j];
        if (!connected[name]) {
            missing.push(name);
            continue;
        }
        session.setMonitorWallpaper(name, set.wallpapers[name]);
        session.setMonitorCyclingFolderPath(name, "");
        applied.push(name);
    }
    return { applied: applied, missing: missing };
}

// Same list as Dux 2.1's Common/WallpaperFormats.js (VIDEO_EXTENSIONS); kept
// here because 2.0 doesn't ship that file.
var VIDEO_EXTENSIONS = ["mp4", "webm", "mkv", "mov", "m4v", "avi"];

function isVideo(path) {
    var clean = String(path || "").split(/[?#]/)[0];
    var dot = clean.lastIndexOf(".");
    if (dot <= clean.lastIndexOf("/"))
        return false;
    return VIDEO_EXTENSIONS.indexOf(clean.substring(dot + 1).toLowerCase()) >= 0;
}

function basename(path) {
    if (!path)
        return "";
    var s = String(path);
    return s.substring(s.lastIndexOf("/") + 1);
}
