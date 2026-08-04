import QtQuick
import QtQuick.Controls.Basic
import qs.animations as Animations
import qs.services

Button {
    id: root

    property url iconSource: ""
    property string iconName: ""
    property string accessibleName: ""
    property string accessibleDescription: ""
    property string toolTipText: ""
    property int toolTipDelay: 500
    property int toolTipTimeout: 5000
    property real toolTipOffset: 8

    property Item scaleTarget: root.contentItem
    property Item iconScaleTarget: null
    property Item textScaleTarget: null
    property bool scaleIcon: false
    property bool scaleText: false
    property real hoveredScale: 1.0
    property real unhoveredScale: 1.0
    property real baseScale: 1.0
    property int scaleAnimationDuration: Config.motion.micro
    property int scaleAnimationEasing: Easing.OutCubic
    property int cursorShape: Qt.PointingHandCursor

    property bool _toolTipShown: false

    hoverEnabled: true
    focusPolicy: Qt.TabFocus | Qt.ClickFocus
    background: null
    contentItem: defaultContent

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName || root.text
    Accessible.description: root.accessibleDescription

    function hideToolTip() {
        toolTipDelayTimer.stop();
        toolTipTimeoutTimer.stop();
        root._toolTipShown = false;
    }

    function scheduleToolTip() {
        root.hideToolTip();
        if (!root.hovered || root.down || root.toolTipText === "")
            return;
        if (root.toolTipDelay <= 0) {
            root.showToolTip();
            return;
        }
        toolTipDelayTimer.restart();
    }

    function showToolTip() {
        if (!root.hovered || root.down || root.toolTipText === "")
            return;
        root._toolTipShown = true;
        if (root.toolTipTimeout > 0)
            toolTipTimeoutTimer.restart();
    }

    Timer {
        id: toolTipDelayTimer
        interval: Math.max(0, root.toolTipDelay)
        repeat: false
        onTriggered: root.showToolTip()
    }

    Timer {
        id: toolTipTimeoutTimer
        interval: Math.max(1, root.toolTipTimeout)
        repeat: false
        onTriggered: root._toolTipShown = false
    }

    Rectangle {
        id: toolTip
        parent: Overlay.overlay
        visible: parent !== null
            && root._toolTipShown
            && root.hovered
            && !root.down
            && root.toolTipText !== ""
        enabled: false
        z: 100000
        width: parent
            ? Math.min(implicitWidth, Math.max(80, parent.width - root.toolTipOffset * 2))
            : implicitWidth
        implicitWidth: toolTipLabel.implicitWidth + Config.spacing.sm * 2
        implicitHeight: toolTipLabel.implicitHeight + Config.spacing.xs * 2
        color: Config.styling.bg2
        border.width: 1
        border.color: Config.styling.bg3
        radius: Config.styling.radius

        x: {
            if (!parent)
                return 0;
            const _ = [root.x, root.y, root.width, root.height, parent.width];
            const point = root.mapToItem(parent, 0, root.height + root.toolTipOffset);
            const centered = point.x + (root.width - width) / 2;
            return Math.max(root.toolTipOffset,
                Math.min(centered, parent.width - width - root.toolTipOffset));
        }

        y: {
            if (!parent)
                return 0;
            const _ = [root.x, root.y, root.width, root.height, parent.height];
            const below = root.mapToItem(parent, 0, root.height + root.toolTipOffset).y;
            if (below + height <= parent.height - root.toolTipOffset)
                return below;
            const above = root.mapToItem(parent, 0, -height - root.toolTipOffset).y;
            return Math.max(root.toolTipOffset, above);
        }

        Text {
            id: toolTipLabel
            anchors.fill: parent
            anchors.margins: Config.spacing.xs
            text: root.toolTipText
            color: Config.styling.text0
            font.pixelSize: 11
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
        }
    }

    function applyScale(target, targetScale) {
        if (!target)
            return;

        target.scale = targetScale;
    }

    function updateScale() {
        const hoverFactor = hovered ? hoveredScale : unhoveredScale;
        const targetScale = baseScale * hoverFactor;

        applyScale(scaleTarget, targetScale);

        if (scaleIcon && iconScaleTarget)
            applyScale(iconScaleTarget, targetScale);

        if (scaleText && textScaleTarget)
            applyScale(textScaleTarget, targetScale);
    }

    Item {
        id: defaultContent

        Animations.ScaleBehavior on scale {
            duration: root.scaleAnimationDuration
            easingType: root.scaleAnimationEasing
        }
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: root.cursorShape
    }

    onHoveredChanged: {
        root.updateScale();
        if (root.hovered)
            root.scheduleToolTip();
        else
            root.hideToolTip();
    }
    onDownChanged: {
        if (root.down)
            root.hideToolTip();
        else if (root.hovered)
            root.scheduleToolTip();
    }
    onToolTipTextChanged: root.scheduleToolTip()
    onBaseScaleChanged: updateScale()
    onHoveredScaleChanged: updateScale()
    onUnhoveredScaleChanged: updateScale()
    onScaleTargetChanged: updateScale()
    onIconScaleTargetChanged: updateScale()
    onTextScaleTargetChanged: updateScale()
    onScaleIconChanged: updateScale()
    onScaleTextChanged: updateScale()
    Component.onCompleted: updateScale()
}
