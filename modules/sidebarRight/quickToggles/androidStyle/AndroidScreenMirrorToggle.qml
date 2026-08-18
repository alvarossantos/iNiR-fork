import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

AndroidQuickToggleButton {
    id: root

    name: Translation.tr("Screen Mirror")
    toggled: false
    buttonIcon: "screen_share"

    signal openMirrorDialog()

    function refreshStatus() {
        checkMirrorProc.running = false;
        checkMirrorProc.running = true;
    }

    mainAction: () => {
        if (toggled) {
            stopMirrorProc.running = true;
        } else {
            root.openMirrorDialog();
        }
    }

    altAction: () => {
        root.openMirrorDialog();
    }

    Process {
        id: checkMirrorProc
        command: ["pgrep", "-x", "wl-mirror"]
        onExited: (exitCode) => {
            root.toggled = (exitCode === 0);
            root.visible = true;
        }
    }

    Process {
        id: stopMirrorProc
        command: ["pkill", "-x", "wl-mirror"]
        onExited: (exitCode) => { root.refreshStatus(); }
    }

    Timer {
        id: pollTimer
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: GlobalStates.sidebarRightOpen
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: root.refreshStatus()
    StyledToolTip {
        text: root.toggled
            ? Translation.tr("Screen Mirror — active (click to stop)")
            : Translation.tr("Screen Mirror — click to configure")
    }
}
