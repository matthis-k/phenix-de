pragma Singleton
import QtQml

QtObject {
    id: root

    property var _startTime: Date.now()

    function nowUs() {
        return (Date.now() - root._startTime) * 1000
    }

    function reset() {
        root._startTime = Date.now()
    }
}
