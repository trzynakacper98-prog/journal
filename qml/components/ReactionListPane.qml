import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#0f141b"
    border.color: "#1a2633"
    radius: 22

    required property var model
    property int currentRow: -1
    signal reactionActivated(int row)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        Rectangle {
            Layout.fillWidth: true
            radius: 20
            color: "#131b25"
            border.color: "#223244"
            implicitHeight: headerColumn.implicitHeight + 24

            ColumnLayout {
                id: headerColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        spacing: 2
                        Label {
                            text: "Reaction library"
                            font.pixelSize: 24
                            font.bold: true
                        }
                        Label {
                            text: model.count + " visible reaction" + (model.count === 1 ? "" : "s")
                            opacity: 0.7
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "New"
                        highlighted: true
                        onClicked: appBridge.startBlankDraftInEditor()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ComboBox {
                        id: reactionTypeCombo
                        Layout.fillWidth: true
                        model: ["All reaction types"].concat(appBridge.availableReactionTypes)
                        currentIndex: {
                            var idx = model.indexOf(appBridge.reactionTypeFilter)
                            return idx >= 0 ? idx : 0
                        }
                        onActivated: appBridge.setReactionTypeFilter(currentIndex <= 0 ? "" : currentText)
                    }

                    ComboBox {
                        id: templateCombo
                        Layout.fillWidth: true
                        model: ["All templates"].concat(appBridge.availableTemplateNames)
                        currentIndex: {
                            var idx = model.indexOf(appBridge.templateFilter)
                            return idx >= 0 ? idx : 0
                        }
                        onActivated: appBridge.setTemplateFilter(currentIndex <= 0 ? "" : currentText)
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !!appBridge.activeTag || !!appBridge.reactionTypeFilter || !!appBridge.templateFilter

                    Rectangle {
                        visible: !!appBridge.activeTag
                        radius: 12
                        color: "#173247"
                        border.color: "#55c1ff"
                        implicitWidth: activeTagLabel.implicitWidth + 18
                        implicitHeight: activeTagLabel.implicitHeight + 10
                        Label {
                            id: activeTagLabel
                            anchors.centerIn: parent
                            text: "Tag: " + appBridge.activeTag
                            font.pixelSize: 12
                        }
                    }
                    Rectangle {
                        visible: !!appBridge.reactionTypeFilter
                        radius: 12
                        color: "#1a2835"
                        border.color: "#31485f"
                        implicitWidth: typeLabel.implicitWidth + 18
                        implicitHeight: typeLabel.implicitHeight + 10
                        Label {
                            id: typeLabel
                            anchors.centerIn: parent
                            text: "Type: " + appBridge.reactionTypeFilter
                            font.pixelSize: 12
                        }
                    }
                    Rectangle {
                        visible: !!appBridge.templateFilter
                        radius: 12
                        color: "#1a2835"
                        border.color: "#31485f"
                        implicitWidth: templateLabel.implicitWidth + 18
                        implicitHeight: templateLabel.implicitHeight + 10
                        Label {
                            id: templateLabel
                            anchors.centerIn: parent
                            text: "Template: " + appBridge.templateFilter
                            font.pixelSize: 12
                        }
                    }
                }

                Label {
                    text: appBridge.activeTag ? ("Tag filter: " + appBridge.activeTag) : "Popular tags"
                    opacity: 0.78
                    font.bold: true
                }

                Connections {
                    target: appBridge
                    function onFiltersChanged() {
                        var typeIndex = reactionTypeCombo.model.indexOf(appBridge.reactionTypeFilter)
                        reactionTypeCombo.currentIndex = typeIndex >= 0 ? typeIndex : 0
                        var templateIndex = templateCombo.model.indexOf(appBridge.templateFilter)
                        templateCombo.currentIndex = templateIndex >= 0 ? templateIndex : 0
                    }
                    function onAvailableFiltersChanged() {
                        var typeIndex = reactionTypeCombo.model.indexOf(appBridge.reactionTypeFilter)
                        reactionTypeCombo.currentIndex = typeIndex >= 0 ? typeIndex : 0
                        var templateIndex = templateCombo.model.indexOf(appBridge.templateFilter)
                        templateCombo.currentIndex = templateIndex >= 0 ? templateIndex : 0
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: contentHeight > 0 ? Math.min(contentHeight, 74) : 34
                    orientation: ListView.Horizontal
                    spacing: 8
                    clip: true
                    model: appBridge.availableTags

                    delegate: Rectangle {
                        radius: 14
                        color: appBridge.activeTag === modelData.tag ? "#173247" : "#101820"
                        border.color: appBridge.activeTag === modelData.tag ? "#55c1ff" : "#314352"
                        implicitHeight: 34
                        implicitWidth: chipLabel.implicitWidth + 18

                        Label {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: modelData.tag + " (" + modelData.count + ")"
                            font.pixelSize: 12
                            font.bold: appBridge.activeTag === modelData.tag
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: appBridge.setActiveTag(appBridge.activeTag === modelData.tag ? "" : modelData.tag)
                        }
                    }

                    footer: appBridge.availableTags.length === 0 ? noTags : null

                    Component {
                        id: noTags
                        Label {
                            text: "No tags recorded yet"
                            opacity: 0.6
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    ScrollBar.horizontal: ScrollBar { }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 20
            color: "#131b25"
            border.color: "#223244"

            ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                spacing: 10
                model: root.model
                currentIndex: root.currentRow
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && currentIndex !== root.currentRow)
                        root.reactionActivated(currentIndex)
                }

                delegate: ItemDelegate {
                    id: delegateRoot
                    required property int index
                    required property string reactionId
                    required property string reactionType
                    required property string substrate1Id
                    required property string substrate2Id
                    required property string productId
                    required property string dateStarted
                    required property string templateName
                    required property string yieldPercent
                    required property string tags

                    width: ListView.view.width
                    height: 138
                    hoverEnabled: true
                    onClicked: {
                        listView.currentIndex = index
                        root.reactionActivated(index)
                    }

                    background: Rectangle {
                        radius: 16
                        color: delegateRoot.ListView.isCurrentItem ? "#1b3448" : (delegateRoot.hovered ? "#1a2531" : "#16202b")
                        border.color: delegateRoot.ListView.isCurrentItem ? "#6bc7ff" : (delegateRoot.down ? "#3ea6ff" : "#233141")
                        border.width: delegateRoot.ListView.isCurrentItem ? 2 : 1
                    }

                    contentItem: ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            Label {
                                text: reactionId || "(no id)"
                                font.pixelSize: 18
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                visible: !!yieldPercent
                                radius: 11
                                color: delegateRoot.ListView.isCurrentItem ? "#244862" : "#20344a"
                                implicitHeight: chipText.implicitHeight + 8
                                implicitWidth: chipText.implicitWidth + 18

                                Label {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: yieldPercent || ""
                                    opacity: 0.92
                                    font.bold: true
                                }
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: reactionType || "No reaction type"
                            font.pixelSize: 14
                            opacity: 0.82
                            elide: Text.ElideRight
                        }

                        Label {
                            Layout.fillWidth: true
                            text: [substrate1Id, substrate2Id, productId].filter(Boolean).join("  →  ")
                            opacity: 0.72
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Label {
                                text: dateStarted || ""
                                opacity: 0.62
                            }
                            Label {
                                text: templateName ? ("Template: " + templateName) : ""
                                opacity: 0.62
                            }
                            Item { Layout.fillWidth: true }
                            Label {
                                text: tags || ""
                                opacity: 0.62
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar { }
                footer: root.model.count === 0 ? emptyState : null
            }

            Component {
                id: emptyState
                Column {
                    width: listView.width
                    spacing: 8
                    topPadding: 40

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No matching reactions"
                        font.pixelSize: 20
                        font.bold: true
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Change the search text or clear filters."
                        opacity: 0.7
                    }
                }
            }
        }
    }
}
