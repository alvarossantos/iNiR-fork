pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string currentProfile: ""
    property int popupSequence: 0

    readonly property string stateFile: "/run/user/1000/fan-mode-state"
    readonly property string popupMaterialIcon: "air"
    readonly property string popupText: {
        if (root.currentProfile.length === 0) return "Fan";
        return "Fan: " + root.currentProfile;
    }

    FileView {
        id: stateView
        path: root.stateFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const raw = text();
            const val = (typeof raw === "string") ? raw.trim() : "";
            if (val.length > 0 && val !== root.currentProfile) {
                root.currentProfile = val;
                root.popupSequence += 1;
            }
        }
    }

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: stateView.reload()
    }
}