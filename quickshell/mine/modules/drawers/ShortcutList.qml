import QtQuick

ListView {
    signal searchRequested()
    clip: true
    activeFocusOnTab: true
    keyNavigationEnabled: true
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: 0
    Keys.onUpPressed: event => {
        if (currentIndex <= 0) searchRequested()
        else event.accepted = false
    }
    function enter(): void {
        if (!count) return
        if (currentIndex < 0) currentIndex = 0
        forceActiveFocus()
        positionViewAtIndex(currentIndex, ListView.Contain)
    }
}
