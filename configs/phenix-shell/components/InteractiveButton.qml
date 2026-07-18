import QtQuick
import QtQuick.Controls.Basic
import qs.animations as Animations

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
    property int scaleAnimationDuration: 150
    property int scaleAnimationEasing: Easing.OutCubic
    property int cursorShape: Qt.PointingHandCursor

    hoverEnabled: true
    focusPolicy: Qt.TabFocus | Qt.ClickFocus
    background: null
    contentItem: defaultContent

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName || root.text
    Accessible.description: root.accessibleDescription

    ToolTip {
        id: toolTip

        visible: root.hovered && !root.down && root.toolTipText !== ""
        text: root.toolTipText
        delay: root.toolTipDelay
        timeout: root.toolTipTimeout

        // Keep the popup clear of the pointer target. Popup margins allow Qt to
        // constrain the tooltip to the surrounding window near screen edges.
        x: Math.round((root.width - implicitWidth) / 2)
        y: root.height + root.toolTipOffset
        margins: root.toolTipOffset
        modal: false
        focus: false
        closePolicy: Popup.NoAutoClose
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

    onHoveredChanged: updateScale()
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
