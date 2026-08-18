import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root

    property real verticalPadding: 4
    property real horizontalPadding: 12

    // ─── Output state (via NiriService) ────────────────────────────
    readonly property var outputs: NiriService.outputs ?? ({})
    readonly property var outputNames: {
        const o = outputs;
        return Object.keys(o);
    }
    readonly property int outputCount: outputNames.length
    readonly property int activeOutputCount: {
        const o = outputs;
        let count = 0;
        for (const name in o) {
            if (o[name].logical !== null && o[name].logical !== undefined)
                count++;
        }
        return count;
    }

    // Guard against rapid double-clicks
    property bool _toggling: false

    // Style helpers
    readonly property color _colPrimary: Appearance.inirEverywhere ? Appearance.inir.colPrimary
        : Appearance.colors.colPrimary
    readonly property color _colText: Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnLayer1
    readonly property color _colSub: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colSubtext

    function isOutputOn(name) {
        const o = outputs;
        const out = o[name];
        return out && out.logical !== null && out.logical !== undefined;
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

    function outputMakeModel(name) {
        const out = root.outputs[name];
        if (!out) return "";
        const make = out.make || "";
        const model = out.model || "";
        if (make && model) return make + " " + model;
        if (make) return make;
        if (model) return model;
        return name;
    }

    function toggleOutput(name) {
        if (_toggling) return;
        if (isOutputOn(name)) {
            if (activeOutputCount <= 1) return;
        }
        _toggling = true;
        const action = isOutputOn(name) ? "off" : "on";
        Quickshell.execDetached(["niri", "msg", "output", name, action]);
        _refreshTimer1.restart();
    }

    Timer {
        id: _refreshTimer1
        interval: 300
        onTriggered: {
            NiriService.fetchOutputs();
            _refreshTimer2.restart();
        }
    }

    Timer {
        id: _refreshTimer2
        interval: 600
        onTriggered: {
            NiriService.fetchOutputs();
            root._toggling = false;
        }
    }

    // ─── Visual ────────────────────────────────────────────────────
    implicitWidth: contentColumn.implicitWidth + root.horizontalPadding * 2
    implicitHeight: contentColumn.implicitHeight + root.verticalPadding * 2
    radius: Appearance.zzzEverywhere ? Appearance.zzz.cardRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.normal
    Behavior on radius {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    color: Appearance.zzzEverywhere ? "transparent"
         : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
         : Appearance.inirEverywhere ? Appearance.inir.colLayer1
         : Appearance.auroraEverywhere ? "transparent"
         : Appearance.colors.colLayer1
    Behavior on color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    border.width: Appearance.zzzEverywhere ? 0 : (Appearance.angelEverywhere ? 0 : (Appearance.inirEverywhere ? 1 : 0))
    border.color: Appearance.zzzEverywhere ? "transparent"
        : Appearance.angelEverywhere ? "transparent"
        : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"

    AngelPartialBorder {
        targetRadius: root.radius
        coverage: 0.5
        visible: Appearance.angelEverywhere
    }

    ColumnLayout {
        id: contentColumn
        anchors {
            fill: parent
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
        }
        spacing: 6

        // Output cards
        Repeater {
            model: root.outputNames

            Rectangle {
                id: card
                required property string modelData
                readonly property bool isOn: root.isOutputOn(modelData)
                readonly property bool canToggle: (root.activeOutputCount > 1 || !card.isOn) && !root._toggling

                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall
                    : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                    : Appearance.rounding.small
                color: {
                    if (cardMA.containsPress)
                        return Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
                            : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
                            : Appearance.colors.colSecondaryContainerActive
                    if (cardMA.containsMouse)
                        return Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                            : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                            : Appearance.colors.colSecondaryContainerHover
                    return "transparent"
                }
                border.width: Appearance.inirEverywhere ? 1 : 0
                border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"

                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                MouseArea {
                    id: cardMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: card.canToggle ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.toggleOutput(card.modelData)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    // Icon in accent-tinted circle
                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 17
                        color: ColorUtils.transparentize(card.isOn ? root._colPrimary : root._colSub, 0.84)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: 18
                            text: root.outputIcon(card.modelData)
                            color: card.isOn ? root._colPrimary : root._colSub
                        }
                    }

                    // Name + make/model + resolution
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        StyledText {
                            Layout.fillWidth: true
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: root._colText
                            text: root.outputMakeModel(card.modelData)
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        StyledText {
                            Layout.fillWidth: true
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: card.isOn ? root._colPrimary : root._colSub
                            text: root.outputResolution(card.modelData)
                            elide: Text.ElideRight
                        }
                    }

                    // Power toggle
                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall
                            : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                            : Appearance.rounding.small
                        color: {
                            if (!card.canToggle) return "transparent"
                            if (card.isOn) {
                                if (powerMA.containsPress)
                                    return ColorUtils.transparentize(Appearance.colors.colError, 0.72)
                                if (powerMA.containsMouse)
                                    return ColorUtils.transparentize(Appearance.colors.colError, 0.78)
                                return ColorUtils.transparentize(Appearance.colors.colError, 0.84)
                            }
                            // When off — show green tint to indicate "turn on"
                            if (powerMA.containsPress)
                                return ColorUtils.transparentize(Appearance.colors.colPositive, 0.72)
                            if (powerMA.containsMouse)
                                return ColorUtils.transparentize(Appearance.colors.colPositive, 0.78)
                            return ColorUtils.transparentize(Appearance.colors.colPositive, 0.84)
                        }
                        border.width: 1
                        border.color: {
                            if (!card.canToggle) return "transparent"
                            if (card.isOn) {
                                if (powerMA.containsPress)
                                    return ColorUtils.transparentize(Appearance.colors.colPositive, 0.72)
                                if (powerMA.containsMouse)
                                    return ColorUtils.transparentize(Appearance.colors.colPositive, 0.78)
                                return ColorUtils.transparentize(Appearance.colors.colPositive, 0.84)
                            }
                            if (powerMA.containsPress)
                                return ColorUtils.transparentize(Appearance.colors.colPrimary, 0.72)
                            if (powerMA.containsMouse)
                                return ColorUtils.transparentize(Appearance.colors.colPrimary, 0.78)
                            return ColorUtils.transparentize(Appearance.colors.colPrimary, 0.84)
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: 18
                            text: card.isOn ? "power_settings_new" : "power"
                            color: card.isOn
                                ? Appearance.colors.colError
                                : Appearance.colors.colPositive
                            opacity: card.canToggle ? 1 : 0.3

                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            }
                        }

                        MouseArea {
                            id: powerMA
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: card.canToggle ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.toggleOutput(card.modelData)
                        }

                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        Behavior on border.color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                }
            }
        }

        // Safety message
        StyledText {
            Layout.fillWidth: true
            visible: root.activeOutputCount === 1 && root.outputCount > 1
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.italic: true
            color: root._colPrimary
            wrapMode: Text.WordWrap
            text: Translation.tr("Only 1 screen active — disabling locked")
        }
    }
}
