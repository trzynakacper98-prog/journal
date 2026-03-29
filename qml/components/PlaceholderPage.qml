import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property string title: ""
    property string subtitle: ""

    Rectangle {
        anchors.fill: parent
        color: "#10151d"

        Rectangle {
            anchors.centerIn: parent
            width: 680
            radius: 28
            color: "#141d27"
            border.color: "#253549"
            implicitHeight: heroColumn.implicitHeight + 44

            ColumnLayout {
                id: heroColumn
                anchors.fill: parent
                anchors.margins: 22
                spacing: 12

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.title
                    font.pixelSize: 34
                    font.bold: true
                }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    opacity: 0.8
                    text: root.subtitle
                }
            }
        }
    }
}
