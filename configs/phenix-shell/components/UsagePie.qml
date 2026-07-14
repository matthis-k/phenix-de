import QtQuick
import qs.services

Canvas {
    id: root

    property real percent: 0
    property color fillColor: Config.colors.base

    implicitWidth: 12
    implicitHeight: 12
    width: 12
    height: 12

    onPercentChanged: requestPaint()
    onFillColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const size = Math.min(width, height);
        const cx = width / 2;
        const cy = height / 2;
        const r = (size / 2) - 1;
        const value = Math.max(0, Math.min(100, percent || 0)) / 100;

        ctx.reset();
        ctx.clearRect(0, 0, width, height);
        ctx.globalAlpha = 0.3;
        ctx.fillStyle = fillColor;
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, Math.PI * 2);
        ctx.fill();

        ctx.globalAlpha = 1;
        ctx.fillStyle = fillColor;
        ctx.beginPath();
        ctx.moveTo(cx, cy);
        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + (Math.PI * 2 * value), false);
        ctx.closePath();
        ctx.fill();
    }
}
