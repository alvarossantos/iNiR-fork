import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell.Io
import Quickshell

QuickToggleButton {
    id: root

    toggled: false
    visible: false

    signal openMirrorDialog()

    function refreshStatus() {
        checkMirrorProc.running = false;
        checkMirrorProc.running = true;
    }

    contentItem: Item {
        CustomIcon {
            source: 'screen-share'
            anchors.centerIn: parent
            width: 16
            height: 16
            colorize: true
            color: root.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1

            Behavior on color {
                enabled: Appearance.animationsEnabled
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }
    }

    onClicked: {
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
