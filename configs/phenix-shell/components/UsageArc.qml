import QtQuick
import qs.services

Canvas {
    id: root

    property real percent: 0
    property color accentColor: Config.styling.primaryAccent
    property color trackColor: Config.styling.bg4
    property real strokeWidth: Math.max(2, Math.min(width, height) * 0.09)
    property real startAngleDegrees: 135
    property real sweepAngleDegrees: 270

    implicitWidth: 12
    implicitHeight: 12

    onPercentChanged: requestPaint()
    onAccentColorChanged: requestPaint()
    onTrackColorChanged: requestPaint()
    onStrokeWidthChanged: requestPaint()
    onStartAngleDegreesChanged: requestPaint()
    onSweepAngleDegreesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const size = Math.min(width, height);
        const lineWidth = Math.max(1, Math.min(root.strokeWidth, size / 2));
        const radius = Math.max(0, (size - lineWidth) / 2);
        const centerX = width / 2;
        const centerY = height / 2;
        const start = root.startAngleDegrees * Math.PI / 180;
        const sweep = root.sweepAngleDegrees * Math.PI / 180;
        const value = Math.max(0, Math.min(100, Number(root.percent || 0))) / 100;

        ctx.reset();
        ctx.clearRect(0, 0, width, height);
        ctx.lineWidth = lineWidth;
        ctx.lineCap = "round";

        ctx.strokeStyle = root.trackColor;
        ctx.beginPath();
        ctx.arc(centerX, centerY, radius, start, start + sweep, false);
        ctx.stroke();

        if (value <= 0)
            return;

        ctx.strokeStyle = root.accentColor;
        ctx.beginPath();
        ctx.arc(centerX, centerY, radius, start, start + sweep * value, false);
        ctx.stroke();
    }
}
