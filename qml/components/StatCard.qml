import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: 18
    color: "#141d27"
    border.color: "#253549"

    property string title: ""
    property string value: ""

    implicitHeight: 102

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        Label {
            text: root.title
            opacity: 0.66
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
        }
        Label {
            text: root.value
            font.pixelSize: 22
            font.bold: true
            elide: Text.ElideRight
        }
    }
}
