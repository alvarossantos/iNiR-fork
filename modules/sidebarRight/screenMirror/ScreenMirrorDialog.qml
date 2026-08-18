pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 520
    backgroundWidth: 380

    readonly property var outputs: NiriService.outputs ?? ({})
    readonly property var outputNames: Object.keys(outputs)
    readonly property string focusedOutput: NiriService.currentOutput ?? ""

    property string mirrorSource: focusedOutput
    property string mirrorDestination: ""
    property bool isMirroring: false
    property string mirrorActiveSource: ""
    property string mirrorActiveDestination: ""

    readonly property color _colPrimary: Appearance.inirEverywhere ? Appearance.inir.colPrimary
        : Appearance.colors.colPrimary
    readonly property color _colSecondary: Appearance.inirEverywhere ? Appearance.inir.colSecondary
        : Appearance.colors.colSecondary
    readonly property color _colError: Appearance.colors.colError
    readonly property color _colText: Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnLayer1
    readonly property color _colSub: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colSubtext

    function isOutputOn(name) {
        const out = outputs[name];
        return out && out.logical !== null && out.logical !== undefined;
    }

    function isSource(name) {
        return root.isMirroring ? root.mirrorActiveSource === name : root.mirrorSource === name;
    }

    function isDest(name) {
        return root.isMirroring ? root.mirrorActiveDestination === name : root.mirrorDestination === name;
    }

    function outputIcon(name) {
        const n = name.toLowerCase();
        if (n.includes("edp") || n.includes("lvds") || n.includes("panel")) return "laptop";
        if (n.includes("hdmi")) return "tv";
        if (n.includes("dp") || n.includes("displayport")) return "monitor";
        if (n.includes("vga")) return "desktop_windows";
        return "monitor";
    }

    function outputResolution(name) {
        const out = root.outputs[name];
        if (!out) return "";
        if (!out.logical) return Translation.tr("Off");
        if (out.modes && out.modes.length > 0 && out.current_mode !== undefined) {
            const mode = out.modes[out.current_mode];
            if (mode) {
                const hz = mode.refresh_rate ? " " + (mode.refresh_rate / 1000).toFixed(0) + "Hz" : "";
                return mode.width + "×" + mode.height + hz;
            }
        }
        return Translation.tr("On");
    }

    function startMirror() {
        if (root.mirrorSource === "" || root.mirrorDestination === "" || root.mirrorSource === root.mirrorDestination) return;
        root.mirrorActiveSource = root.mirrorSource;
        root.mirrorActiveDestination = root.mirrorDestination;
        Quickshell.execDetached(["wl-mirror", "--fullscreen-output", root.mirrorDestination, root.mirrorSource]);
        root.refreshStatus();
        GlobalStates.sidebarRightOpen = false;
    }

    function stopMirror() {
        stopMirrorProc.running = true;
    }

    function refreshStatus() {
        checkMirrorProc.running = false;
        checkMirrorProc.running = true;
    }

    // ─── Title ─────────────────────────────────────────────────────
    WindowDialogTitle {
        text: Translation.tr("Screen Mirror")
    }

    // ─── Active mirror banner ──────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
        radius: 0
        color: ColorUtils.transparentize(root._colPrimary, 0.88)
        visible: root.isMirroring

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Appearance.rounding.large + 4
            anchors.rightMargin: Appearance.rounding.large + 4
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                color: ColorUtils.transparentize(root._colPrimary, 0.80)

                MaterialSymbol {
                    anchors.centerIn: parent
                    iconSize: 16
                    color: root._colPrimary
                    text: "link"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: root._colPrimary
                    text: Translation.tr("Mirroring active")
                }

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root._colSub
                    text: root.mirrorActiveSource + "  →  " + root.mirrorActiveDestination
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: stopMA.containsPress ? ColorUtils.transparentize(root._colError, 0.78)
                    : stopMA.containsMouse ? ColorUtils.transparentize(root._colError, 0.84)
                    : ColorUtils.transparentize(root._colError, 0.88)

                MaterialSymbol {
                    anchors.centerIn: parent
                    iconSize: 16
                    color: root._colError
                    text: "stop_circle"
                }

                MouseArea {
                    id: stopMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.stopMirror()
                }
            }
        }
    }

    // ─── Source section ────────────────────────────────────────────
    WindowDialogSectionHeader {
        text: Translation.tr("Source")
    }

    WindowDialogSeparator {
        Layout.topMargin: -22
        Layout.leftMargin: 0
        Layout.rightMargin: 0
    }

    Repeater {
        model: root.outputNames

        delegate: Rectangle {
            id: srcCard
            required property string modelData
            readonly property bool isOn: root.isOutputOn(modelData)
            readonly property bool isSelected: root.isSource(modelData)
            readonly property bool canSelect: isOn && !root.isMirroring

            Layout.fillWidth: true
            Layout.preferredHeight: 44
            Layout.leftMargin: -Appearance.rounding.large
            Layout.rightMargin: -Appearance.rounding.large
            radius: 0
            color: srcMA.containsPress && canSelect ? Appearance.colors.colLayer2Active
                : srcMA.containsMouse && canSelect ? Appearance.colors.colLayer2Hover
                : "transparent"

            MouseArea {
                id: srcMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: canSelect ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: canSelect
                onClicked: root.mirrorSource = modelData
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Appearance.rounding.large + 4
                anchors.rightMargin: Appearance.rounding.large + 4
                spacing: 10

                // Selection indicator
                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: isSelected ? root._colPrimary : "transparent"
                }

                // Icon in circle
                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 15
                    color: ColorUtils.transparentize(isSelected ? root._colPrimary : root._colSub, 0.84)
                    opacity: isOn ? 1 : 0.35

                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 16
                        text: root.outputIcon(modelData)
                        color: isSelected ? root._colPrimary : root._colSub
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: isSelected ? Font.DemiBold : Font.Normal
                        color: isOn ? root._colText : root._colSub
                        opacity: isOn ? 1 : 0.5
                        text: modelData
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: isSelected ? root._colPrimary : root._colSub
                        opacity: isOn ? 0.8 : 0.4
                        text: root.outputResolution(modelData)
                        elide: Text.ElideRight
                    }
                }

                // Check
                MaterialSymbol {
                    visible: isSelected
                    iconSize: 18
                    color: root._colPrimary
                    text: "check_circle"
                }
            }
        }
    }

    // ─── Destination section ───────────────────────────────────────
    WindowDialogSectionHeader {
        Layout.topMargin: 4
        text: Translation.tr("Destination")
    }

    WindowDialogSeparator {
        Layout.topMargin: -22
        Layout.leftMargin: 0
        Layout.rightMargin: 0
    }

    Repeater {
        model: root.outputNames

        delegate: Rectangle {
            id: dstCard
            required property string modelData
            readonly property bool isOn: root.isOutputOn(modelData)
            readonly property bool isSourceScreen: root.isSource(modelData)
            readonly property bool isSelected: root.isDest(modelData)
            readonly property bool canSelect: isOn && !isSourceScreen && !root.isMirroring

            Layout.fillWidth: true
            Layout.preferredHeight: 44
            Layout.leftMargin: -Appearance.rounding.large
            Layout.rightMargin: -Appearance.rounding.large
            radius: 0
            color: dstMA.containsPress && canSelect ? Appearance.colors.colLayer2Active
                : dstMA.containsMouse && canSelect ? Appearance.colors.colLayer2Hover
                : "transparent"

            MouseArea {
                id: dstMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: canSelect ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: canSelect
                onClicked: root.mirrorDestination = modelData
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Appearance.rounding.large + 4
                anchors.rightMargin: Appearance.rounding.large + 4
                spacing: 10

                // Selection indicator
                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: isSelected ? root._colSecondary : "transparent"
                }

                // Icon in circle
                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 15
                    color: ColorUtils.transparentize(isSelected ? root._colSecondary : root._colSub, 0.84)
                    opacity: isOn && !isSourceScreen ? 1 : 0.35

                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 16
                        text: root.outputIcon(modelData)
                        color: isSelected ? root._colSecondary : root._colSub
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: isSelected ? Font.DemiBold : Font.Normal
                        color: (isOn && !isSourceScreen) ? root._colText : root._colSub
                        opacity: (isOn && !isSourceScreen) ? 1 : 0.5
                        text: modelData
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: isSelected ? root._colSecondary : root._colSub
                        opacity: (isOn && !isSourceScreen) ? 0.8 : 0.4
                        text: isSourceScreen ? Translation.tr("Source") : root.outputResolution(modelData)
                        elide: Text.ElideRight
                    }
                }

                // Check
                MaterialSymbol {
                    visible: isSelected
                    iconSize: 18
                    color: root._colSecondary
                    text: "check_circle"
                }
            }
        }
    }

    // ─── Button row ────────────────────────────────────────────────
    WindowDialogButtonRow {
        Layout.fillWidth: true

        DialogButton {
            visible: root.isMirroring
            buttonText: Translation.tr("Stop Mirror")
            colText: root._colError
            onClicked: root.stopMirror()
        }

        DialogButton {
            visible: !root.isMirroring
            enabled: root.mirrorSource !== "" && root.mirrorDestination !== ""
                && root.mirrorSource !== root.mirrorDestination
            buttonText: Translation.tr("Start Mirror")
            colText: root._colPrimary
            onClicked: root.startMirror()
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            visible: !root.isMirroring
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }

    // ─── Processes ─────────────────────────────────────────────────
    Process {
        id: checkMirrorProc
        command: ["pgrep", "-x", "wl-mirror"]
        onExited: (exitCode) => {
            root.isMirroring = (exitCode === 0);
            if (!root.isMirroring) {
                root.mirrorActiveSource = "";
                root.mirrorActiveDestination = "";
            }
        }
    }

    Process {
        id: stopMirrorProc
        command: ["pkill", "-x", "wl-mirror"]
        onExited: (exitCode) => {
            root.mirrorActiveSource = "";
            root.mirrorActiveDestination = "";
            root.refreshStatus();
        }
    }

    Timer {
        id: pollTimer
        interval: 2000
        repeat: true
        running: root.show
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: root.refreshStatus()
}
