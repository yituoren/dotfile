pragma ComponentBehavior: Bound

// Display the time in HH:mm format.
// Keep the detailed date and seconds in the calendar panel.

import QtQuick
import qs.services

Text {
    text: DateTime.hhmm
    color: Theme.colors.on_surface
    font.family: "Maple Mono NF CN"
    font.pixelSize: 15
    font.styleName: "ExtraBold"
}
