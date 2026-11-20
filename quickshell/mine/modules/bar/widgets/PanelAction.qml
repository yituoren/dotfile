pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services

AbstractButton {
    id: button
    property string symbol: ""
    property string imageUrl: ""
    property string trailingSymbol: ""
    property bool filled: true

    implicitHeight: 36
    hoverEnabled: true
    leftPadding: 12
    rightPadding: 12
    opacity: enabled ? 1 : 0.45

    background: Rectangle {
        radius: 12
        color: button.down ? Theme.colors.primary_container
             : button.hovered || button.visualFocus ? Theme.colors.surface_container_high
             : button.filled ? Theme.colors.surface_container : "transparent"
        border.width: button.visualFocus ? 1 : 0
        border.color: Theme.colors.primary
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    contentItem: RowLayout {
        spacing: 10
        Text {
            visible: button.symbol !== ""
            text: button.symbol
            font.family: "Material Symbols Rounded"
            font.pixelSize: 19
            color: Theme.colors.primary
        }
        Image {
            visible: button.imageUrl !== ""
            source: button.imageUrl
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            fillMode: Image.PreserveAspectFit
        }
        Text {
            Layout.fillWidth: true
            text: button.text
            textFormat: Text.PlainText
            font.family: "Maple Mono NF CN"
            font.styleName: "Bold"
            font.pixelSize: 13
            color: Theme.colors.on_surface
            elide: Text.ElideRight
        }
        Text {
            visible: button.trailingSymbol !== ""
            text: button.trailingSymbol
            font.family: "Material Symbols Rounded"
            font.pixelSize: 18
            color: Theme.colors.on_surface_variant
        }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
