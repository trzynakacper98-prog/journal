import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property string svgDataUri: ""
    property string title: ""
    property string fallbackText: ""
    property real zoom: 1.0

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: view.width
        contentHeight: view.height

        Rectangle {
            id: view
            width: Math.max(parent.width, 900 * root.zoom)
            height: Math.max(parent.height, 700 * root.zoom)
            color: "white"
            radius: 14
            border.color: "#d9e1ec"

            Image {
                id: dialogImage
                anchors.centerIn: parent
                width: 900 * root.zoom
                height: 700 * root.zoom
                source: root.svgDataUri
                fillMode: Image.PreserveAspectFit
                smooth: true
                cache: false
                visible: !!root.svgDataUri
            }

            Label {
                anchors.centerIn: parent
                visible: !dialogImage.visible
                text: root.fallbackText || "No structure"
                color: "#4b5c6d"
            }
        }
    }
}
