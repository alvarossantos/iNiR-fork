pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string currentMode: ""
    property int popupSequence: 0

    readonly property string stateFile: "/run/user/1000/rgb-mode-state"
    readonly property string popupMaterialIcon: "palette"
    readonly property string popupText: {
        if (root.currentMode.length === 0) return "LED";
        if (root.currentMode === "Desligado") return "LED desligado";
        return "LED: " + root.currentMode;
    }

    FileView {
        id: stateView
        path: root.stateFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const raw = text();
            const val = (typeof raw === "string") ? raw.trim() : "";
            if (val.length > 0 && val !== root.currentMode) {
                root.currentMode = val;
                root.popupSequence += 1;
            }
        }
    }

    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: stateView.reload()
    }
}