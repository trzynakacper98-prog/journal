import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: 18
    color: "#16212c"
    border.color: "#27394b"

    property string title: ""
    property string subtitle: ""
    property string amountText: ""
    property string metaText: ""
    property string svgDataUri: ""

    implicitHeight: cardColumn.implicitHeight + 26

    ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        ZoomableSvgPane {
            Layout.fillWidth: true
            svgDataUri: root.svgDataUri
            title: root.title
            fallbackText: root.subtitle || "No structure"
            baseWidth: 320
            baseHeight: 220
        }

        Label {
            Layout.fillWidth: true
            text: title
            font.pixelSize: 16
            font.bold: true
            elide: Text.ElideRight
        }

        Label {
            Layout.fillWidth: true
            text: amountText
            wrapMode: Text.Wrap
            opacity: 0.84
        }

        Label {
            Layout.fillWidth: true
            text: metaText
            wrapMode: Text.WrapAnywhere
            opacity: 0.66
            visible: !!text
            font.pixelSize: 12
        }
    }
}
