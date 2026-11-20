pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Shapes
import "PasswordShapes.js" as Shapes

TextField {
    id: field
    required property color accent
    required property real textSize

    echoMode: TextInput.Password
    passwordCharacter: " "
    passwordMaskDelay: 0
    inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
    selectionColor: Qt.alpha(accent, 0.26)
    font.family: blank.font.family
    font.pixelSize: length ? blank.font.pixelSize : Math.round(textSize * 1.15)
    readonly property int cellWidth: Math.round(textSize * 4 / 3)
    font.letterSpacing: length ? cellWidth - blank.advanceWidth : 0
    horizontalAlignment: TextInput.AlignLeft
    verticalAlignment: TextInput.AlignVCenter
    Accessible.name: "Password"

    TextMetrics {
        id: blank
        font.family: "Maple Mono NF CN"
        font.pixelSize: Math.round(field.textSize * 1.4)
        text: field.passwordCharacter
    }

    // Keep delegates and their animations alive when a neighbouring character changes.
    // The model contains empty rows only. Password text stays in the native editor.
    ListModel { id: positions }
    function syncPositions(): void {
        const delta = length - positions.count
        marks.followAppend = delta === 1 && cursorPosition === length && activeFocus
        if (delta > 0) {
            const start = Math.max(0, Math.min(positions.count, cursorPosition - delta))
            positions.insert(start, Array.from({length: delta}, () => ({})))
        } else if (delta < 0) {
            positions.remove(Math.min(cursorPosition, length), -delta)
        }
    }
    onLengthChanged: syncPositions()
    Component.onCompleted: syncPositions()

    ListView {
        id: marks
        x: field.leftPadding
        y: field.cursorRectangle.y
        width: Math.max(0, field.width - field.leftPadding - field.rightPadding)
        height: field.cursorRectangle.height
        clip: true
        orientation: ListView.Horizontal
        interactive: false
        currentIndex: -1
        readonly property int advance: field.cellWidth
        readonly property real scrollOffset: field.cursorPosition * advance - (field.cursorRectangle.x - x)
        property bool followAppend: false
        function alignToCaret(): void {
            forceLayout()
            const dest = originX + scrollOffset
            if (followAppend && field.cursorPosition === field.length && dest > contentX && dest - contentX <= 2 * advance) {
                slide.stop()
                slide.to = dest
                slide.start()
            } else if (!slide.running || slide.to !== dest) {
                slide.stop()
                contentX = dest
            }
            followAppend = false
        }
        NumberAnimation {
            id: slide
            target: marks; property: "contentX"; duration: 400
            easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
        }
        onScrollOffsetChanged: Qt.callLater(alignToCaret)
        onOriginXChanged: Qt.callLater(alignToCaret)
        model: positions

        delegate: Item {
            id: slot
            required property int index
            width: marks.advance
            height: marks.height
            ListView.onAdd: if (field.activeFocus) appear.start()

            Shape {
                id: mark
                anchors.centerIn: parent
                width: 100
                height: 100
                property real growth: 1
                property real zoom: 1
                scale: field.textSize * 1.2 * growth * zoom / 100
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    id: outline
                    strokeWidth: -1
                    fillColor: field.accent
                    PathSvg { path: Shapes.paths[Math.max(slot.index, 0) % Shapes.paths.length] }
                }
            }
            ParallelAnimation {
                id: appear
                readonly property list<real> spatial: [0.42, 1.67, 0.21, 0.90, 1, 1]
                readonly property list<real> effects: [0.34, 0.80, 0.34, 1, 1, 1]
                NumberAnimation {
                    target: mark; property: "opacity"; from: 0; to: 1; duration: 50
                    easing.type: Easing.BezierSpline; easing.bezierCurve: appear.effects
                }
                NumberAnimation {
                    target: mark; property: "zoom"; from: 0.5; to: 1; duration: 200
                    easing.type: Easing.BezierSpline; easing.bezierCurve: appear.spatial
                }
                NumberAnimation {
                    target: mark; property: "growth"; from: 0; to: 1; duration: 250
                    easing.type: Easing.BezierSpline; easing.bezierCurve: appear.spatial
                }
                ColorAnimation {
                    target: outline; property: "fillColor"
                    from: Qt.tint(field.accent, Qt.alpha(field.color, 0.55))
                    to: field.accent; duration: 1000
                    easing.type: Easing.BezierSpline; easing.bezierCurve: appear.effects
                }
            }
        }
    }
}
