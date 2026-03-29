import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: 20
    color: "#141d27"
    border.color: "#253549"

    property string title: ""
    property string body: ""

    implicitHeight: panelColumn.implicitHeight + 28

    ColumnLayout {
        id: panelColumn
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        Label {
            text: root.title
            font.pixelSize: 15
            font.bold: true
            opacity: 0.9
        }
        Label {
            Layout.fillWidth: true
            text: root.body
            wrapMode: Text.Wrap
            opacity: 0.8
            lineHeight: 1.15
        }
    }
}
