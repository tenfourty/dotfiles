// Ctrl+/ toggles Ghostty.
//   not on Ghostty -> remember where you are, switch to Ghostty, focus it
//   already on Ghostty -> go back to the window/desktop you came from
//
// Lives in KWin rather than a shell script because kdotool chains cannot
// branch, and a kglobalshortcutsrc entry would not apply until re-login.
var GHOSTTY = "com.mitchellh.ghostty";
var prevWindow = null;
var prevDesktop = null;

function findGhostty() {
    var wins = workspace.windowList ? workspace.windowList() : workspace.clientList();
    for (var i = 0; i < wins.length; i++) {
        var w = wins[i];
        if (w && !w.deleted && w.normalWindow &&
            String(w.resourceClass).toLowerCase() === GHOSTTY) {
            return w;
        }
    }
    return null;
}

function toggle() {
    var active = workspace.activeWindow || workspace.activeClient;
    var onGhostty = active &&
        String(active.resourceClass).toLowerCase() === GHOSTTY;

    if (onGhostty) {
        // Go back: prefer the exact window we came from, else the desktop.
        if (prevWindow && !prevWindow.deleted) {
            if (prevDesktop) { workspace.currentDesktop = prevDesktop; }
            workspace.activeWindow = prevWindow;
        } else if (prevDesktop) {
            workspace.currentDesktop = prevDesktop;
        } else {
            active.minimized = true;
        }
        prevWindow = null;
        prevDesktop = null;
        return;
    }

    var g = findGhostty();
    if (!g) { return; }

    prevWindow = active && !active.deleted ? active : null;
    prevDesktop = workspace.currentDesktop;

    if (g.minimized) { g.minimized = false; }
    if (g.desktops && g.desktops.length > 0) {
        workspace.currentDesktop = g.desktops[0];
    }
    workspace.activeWindow = g;
}

registerShortcut("Ghostty Toggle", "Ghostty: switch to / back from", "Ctrl+/", toggle);
