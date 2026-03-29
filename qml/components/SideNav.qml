import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: 28
    color: "#0d131a"
    border.color: "#1c2b38"

    property string currentPage: "journal"
    signal pageSelected(string pageName)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        Rectangle {
            Layout.fillWidth: true
            radius: 22
            color: "#121b24"
            border.color: "#233345"
            implicitHeight: brandColumn.implicitHeight + 28

            ColumnLayout {
                id: brandColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                Label {
                    text: "Mini ELN"
                    font.pixelSize: 24
                    font.bold: true
                }
                Label {
                    Layout.fillWidth: true
                    text: "A compact desktop chemistry workspace for reaction planning, documentation, and reuse."
                    wrapMode: Text.Wrap
                    opacity: 0.74
                }
            }
        }

        Label {
            text: "Workspace"
            font.pixelSize: 12
            font.bold: true
            opacity: 0.58
            leftPadding: 4
        }

        Repeater {
            model: [
                { key: "journal", label: "Journal", hint: "Browse, filter, and edit reactions" },
                { key: "generator", label: "SMILES / Molecules", hint: "Draw, verify, and inspect structures" },
                { key: "settings", label: "Settings", hint: "Preferences and tooling" }
            ]

            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                radius: 18
                color: root.currentPage === modelData.key ? "#173247" : (navMouse.containsMouse ? "#16212c" : "#101820")
                border.color: root.currentPage === modelData.key ? "#55c1ff" : "#223142"
                border.width: root.currentPage === modelData.key ? 2 : 1
                implicitHeight: 70

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 10
                        Layout.preferredHeight: 10
                        radius: 5
                        color: root.currentPage === modelData.key ? "#7addff" : "#4a5d70"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: modelData.label
                            font.pixelSize: 15
                            font.bold: true
                        }
                        Label {
                            text: modelData.hint
                            opacity: 0.64
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: navMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.pageSelected(modelData.key)
                }
            }
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            radius: 20
            color: "#121b24"
            border.color: "#233345"
            implicitHeight: infoColumn.implicitHeight + 26

            ColumnLayout {
                id: infoColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                Label {
                    text: "Current build"
                    font.bold: true
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    opacity: 0.78
                    text: "Reaction journal, editor, search, and molecule tools are wired in. This layout focuses on clear hierarchy and readability for everyday lab documentation."
                }
            }
        }
    }
}
