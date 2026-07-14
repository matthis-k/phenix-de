import QtQuick
import qs.animations as Animations
import qs.services

Item {
    id: root

    enum Side {
        Top,
        Right,
        Bottom,
        Left
    }

    enum AnimationMode {
        None = 0,
        GrowAlong = 1,
        GrowAcross = 2,
        GrowAll = 3
    }

    property bool active: true
    property bool bgActive: active

    property int side: ActiveIndicator.Side.Top
    property int animationMode: ActiveIndicator.AnimationMode.GrowAll

    property real duration: Config.motion.medium
    property real bgOpacity: 0.3
    property color color: Config.styling.activeIndicator

    readonly property bool horizontal: side === ActiveIndicator.Side.Top || side === ActiveIndicator.Side.Bottom
    readonly property bool vertical: !horizontal

    readonly property bool animateNormalAxis: (animationMode & ActiveIndicator.AnimationMode.GrowAlong) !== 0
    readonly property bool animateLengthAxis: (animationMode & ActiveIndicator.AnimationMode.GrowAcross) !== 0

    property real thickness: (horizontal ? height : width) * 0.1

    anchors.fill: parent
    clip: true

    Item {
        id: backgroundContent
        anchors.fill: parent

        property real t: bgActive ? 1 : 0

        Animations.NumberBehavior on t {
            duration: root.duration
            easingType: Easing.OutCubic
        }

        readonly property real normalScale: root.animateNormalAxis ? t : 1.0
        readonly property real lengthScale: root.animateLengthAxis ? t : 1.0

        transform: Scale {
            xScale: root.horizontal ? backgroundContent.lengthScale : backgroundContent.normalScale
            yScale: root.horizontal ? backgroundContent.normalScale : backgroundContent.lengthScale

            origin.x: root.horizontal ? backgroundContent.width / 2 : (side === ActiveIndicator.Side.Left ? 0 : backgroundContent.width)
            origin.y: root.horizontal ? (side === ActiveIndicator.Side.Top ? 0 : backgroundContent.height) : backgroundContent.height / 2
        }

        opacity: backgroundContent.t

        Rectangle {
            anchors.fill: parent
            color: root.color
            opacity: root.bgOpacity
        }
    }

    Item {
        id: content
        anchors.fill: parent

        property real t: active ? 1 : 0

        Animations.NumberBehavior on t {
            duration: root.duration
            easingType: Easing.OutCubic
        }

        readonly property real normalScale: root.animateNormalAxis ? t : 1.0
        readonly property real lengthScale: root.animateLengthAxis ? t : 1.0

        transform: Scale {
            id: mainScale

            xScale: root.horizontal ? content.lengthScale : content.normalScale
            yScale: root.horizontal ? content.normalScale : content.lengthScale

            origin.x: root.horizontal ? content.width / 2 : (side === ActiveIndicator.Side.Left ? 0 : content.width)
            origin.y: root.horizontal ? (side === ActiveIndicator.Side.Top ? 0 : content.height) : content.height / 2
        }

        opacity: content.t

        Rectangle {
            id: indicator
            color: root.color

            anchors {
                top: side === ActiveIndicator.Side.Top ? parent.top : undefined
                right: side === ActiveIndicator.Side.Right ? parent.right : undefined
                bottom: side === ActiveIndicator.Side.Bottom ? parent.bottom : undefined
                left: side === ActiveIndicator.Side.Left ? parent.left : undefined
            }

            implicitHeight: root.horizontal ? root.thickness : parent.height
            implicitWidth: root.vertical ? root.thickness : parent.width
        }
    }
}
