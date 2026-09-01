pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: true
    property int popupSequence: 0

    readonly property string stateFile: "/run/user/1000/touchpad-state"
    readonly property string popupMaterialIcon: "touchpad"
    readonly property string popupText: root.active ? "Touchpad ativado" : "Touchpad desativado"

    FileView {
        id: stateView
        path: root.stateFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const val = String(text()).trim();
            const nextActive = val === "on";
            if (root.active !== nextActive) {
                root.active = nextActive;
                root.popupSequence += 1;
            }
        }
        onLoadFailed: {
            // Se arquivo não existe, assume ativo
            if (!root.active) {
                root.active = true;
                root.popupSequence += 1;
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: false
        onTriggered: stateView.reload()
    }
}
