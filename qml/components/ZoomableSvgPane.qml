import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: 14
    color: "#f4f7fb"
    border.color: "#d8e0ea"

    property string svgDataUri: ""
    property string title: ""
    property string fallbackText: ""
    property real zoom: 1.0
    property int baseWidth: 420
    property int baseHeight: 280

    implicitHeight: 278

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            radius: 10
            color: "#edf3f9"
            border.color: "#d8e0ea"
            implicitHeight: 42

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 6

                Label {
                    text: root.title
                    color: "#223344"
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                ToolButton {
                    text: "−"
                    onClicked: root.zoom = Math.max(0.4, root.zoom - 0.15)
                }
                ToolButton {
                    text: "100%"
                    onClicked: root.zoom = 1.0
                }
                ToolButton {
                    text: "+"
                    onClicked: root.zoom = Math.min(4.0, root.zoom + 0.15)
                }
                ToolButton {
                    text: "Open"
                    onClicked: viewerDialog.open()
                }
            }
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: imageContainer.width
            contentHeight: imageContainer.height

            Rectangle {
                id: imageContainer
                width: Math.max(flick.width, root.baseWidth * root.zoom)
                height: Math.max(flick.height, root.baseHeight * root.zoom)
                color: "white"
                radius: 10
                border.color: "#d8e0ea"

                Image {
                    id: moleculeImage
                    anchors.centerIn: parent
                    width: root.baseWidth * root.zoom
                    height: root.baseHeight * root.zoom
                    source: root.svgDataUri
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    cache: false
                    visible: !!root.svgDataUri
                }

                Label {
                    anchors.centerIn: parent
                    visible: !moleculeImage.visible
                    color: "#4b5c6d"
                    text: root.fallbackText || "No structure"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    width: parent.width - 30
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onDoubleClicked: viewerDialog.open()
                }
            }
        }
    }

    Dialog {
        id: viewerDialog
        modal: true
        width: 1100
        height: 840
        title: root.title || "Molecule viewer"
        standardButtons: Dialog.Close

        contentItem: Rectangle {
            color: "#10151d"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: root.title
                        font.pixelSize: 18
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    ToolButton {
                        text: "−"
                        onClicked: dialogZoom.zoom = Math.max(0.4, dialogZoom.zoom - 0.2)
                    }
                    ToolButton {
                        text: "100%"
                        onClicked: dialogZoom.zoom = 1.0
                    }
                    ToolButton {
                        text: "+"
                        onClicked: dialogZoom.zoom = Math.min(5.0, dialogZoom.zoom + 0.2)
                    }
                }

                ZoomProxy {
                    id: dialogZoom
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    svgDataUri: root.svgDataUri
                    title: root.title
                    fallbackText: root.fallbackText
                }
            }
        }
    }
}
