import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import "components"

ApplicationWindow {
    id: window
    width: 1680
    height: 980
    minimumWidth: 1280
    minimumHeight: 820
    visible: true
    title: "Mini ELN — Reaction Journal"
    color: "#0b1016"

    Material.theme: Material.Dark
    Material.accent: Material.Teal
    Material.primary: Material.BlueGrey
    property bool previewUnlocked: false
    property bool newReactionMode: false

    function pageTitle(pageName) {
        switch (pageName) {
        case "journal": return "Reaction journal"
        case "generator": return "SMILES and molecule tools"
        case "settings": return "Settings"
        default: return "Mini ELN"
        }
    }

    function pageSubtitle(pageName) {
        switch (pageName) {
        case "journal": return "Browse, review, and edit reactions in one clear workspace."
        case "generator": return "Draw, inspect, look up, and reuse structures without leaving the app."
        case "settings": return "Theme and external-tool preferences will live here later."
        default: return "Desktop chemistry workspace"
        }
    }

    header: Rectangle {
        color: "#0b1016"
        implicitHeight: 104

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 14
            anchors.bottomMargin: 10
            radius: 24
            color: "#121a23"
            border.color: "#223143"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                anchors.topMargin: 16
                anchors.bottomMargin: 16
                spacing: 18

                ColumnLayout {
                    Layout.preferredWidth: 420
                    spacing: 4

                    Label {
                        text: pageTitle(appBridge.currentPage)
                        font.pixelSize: 28
                        font.bold: true
                    }
                    Label {
                        text: pageSubtitle(appBridge.currentPage)
                        opacity: 0.82
                        wrapMode: Text.Wrap
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 430
                    Layout.preferredHeight: 52
                    radius: 16
                    color: "#0d141c"
                    border.color: "#27384b"

                    TextField {
                        id: searchField
                        anchors.fill: parent
                        anchors.margins: 4
                        placeholderText: "Search: ID, type, product, or tags"
                        text: appBridge.searchQuery
                        leftPadding: 16
                        rightPadding: 16
                        background: Rectangle {
                            radius: 12
                            color: "transparent"
                            border.width: 0
                        }
                        onTextEdited: appBridge.setSearchQuery(text)

                        Connections {
                            target: appBridge
                            function onFiltersChanged() {
                                if (searchField.text !== appBridge.searchQuery)
                                    searchField.text = appBridge.searchQuery
                            }
                        }
                    }
                }

                Button {
                    text: "New reaction"
                    highlighted: true
                    onClicked: {
                        appBridge.startBlankDraftInEditor()
                        newReactionMode = true
                        previewUnlocked = false
                        mainStack.currentIndex = 0
                        appBridge.setCurrentPage("journal")
                    }
                }

                Button {
                    text: "Clear filters"
                    enabled: !!appBridge.searchQuery || !!appBridge.activeTag || !!appBridge.reactionTypeFilter || !!appBridge.templateFilter
                    onClicked: appBridge.clearFilters()
                }
            }
        }
    }

    footer: Rectangle {
        color: "#0b1016"
        implicitHeight: 46

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 0
            anchors.bottomMargin: 12
            radius: 18
            color: "#121a23"
            border.color: "#223143"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 16

                Label {
                    text: appBridge.statusText
                    opacity: 0.82
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: appBridge.capabilities.rdkitStatus || "RDKit status unknown"
                    opacity: 0.68
                }
                Label {
                    text: appBridge.capabilities.rdeditorStatus || "rdEditor status unknown"
                    opacity: 0.68
                }
                Label {
                    text: appBridge.capabilities.pubchemStatus || "PubChem status unknown"
                    opacity: 0.68
                }
                Label {
                    text: "Total reactions: " + (appBridge.stats.count ?? 0)
                    opacity: 0.82
                    font.bold: true
                }
            }
        }
    }

    Connections {
        target: appBridge
        function onJournalTabRequested(index) {
            newReactionMode = false
            previewUnlocked = true
            detailsTabs.currentIndex = index
            mainStack.currentIndex = 0
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.bottomMargin: 12
        spacing: 16

        SideNav {
            Layout.preferredWidth: 272
            Layout.fillHeight: true
            currentPage: appBridge.currentPage
            onPageSelected: appBridge.setCurrentPage(pageName)
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 28
            color: "#0f151d"
            border.color: "#1e2b3a"

            StackLayout {
                id: mainStack
                anchors.fill: parent
                anchors.margins: 10
                currentIndex: {
                    switch (appBridge.currentPage) {
                    case "journal": return 0
                    case "generator": return 1
                    case "settings": return 2
                    default: return 0
                    }
                }

                SplitView {
                    id: journalPage
                    anchors.fill: parent
                    orientation: Qt.Horizontal

                    ReactionListPane {
                        SplitView.preferredWidth: 580
                        SplitView.minimumWidth: 430
                        model: reactionModel
                        currentRow: appBridge.selectedRow
                        onReactionActivated: function(row) {
                            appBridge.selectReaction(row)
                            newReactionMode = false
                            previewUnlocked = true
                            detailsTabs.currentIndex = 0
                        }
                    }

                    Rectangle {
                        SplitView.fillWidth: true
                        radius: 22
                        color: "#0c1218"
                        border.color: "#1a2632"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 18
                                color: "#121a23"
                                border.color: "#223143"
                                implicitHeight: 62

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    Label {
                                        text: newReactionMode ? "New reaction editor" : "Reaction library details"
                                        font.bold: true
                                        opacity: 0.9
                                    }

                                    Item { Layout.fillWidth: true }

                                    Button {
                                        text: "Library view"
                                        enabled: newReactionMode
                                        onClicked: newReactionMode = false
                                    }

                                    Button {
                                        text: "New reaction window"
                                        highlighted: true
                                        onClicked: {
                                            appBridge.startBlankDraftInEditor()
                                            newReactionMode = true
                                            previewUnlocked = false
                                        }
                                    }
                                }
                            }

                            StackLayout {
                                id: editorModeStack
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                currentIndex: newReactionMode ? 0 : 1

                                ReactionEditorPane {
                                    reaction: appBridge.editorDraft
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 10

                                    Rectangle {
                                        Layout.fillWidth: true
                                        radius: 16
                                        color: "#121a23"
                                        border.color: "#223143"
                                        implicitHeight: 58

                                        TabBar {
                                            id: detailsTabs
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            spacing: 8
                                            background: Item {}
                                            visible: previewUnlocked && !!appBridge.selectedReaction && !!appBridge.selectedReaction.id

                                            TabButton { text: "Preview" }
                                            TabButton { text: "Edit" }
                                        }

                                        Label {
                                            anchors.centerIn: parent
                                            visible: !detailsTabs.visible
                                            text: "Select a reaction from the library to open preview."
                                            opacity: 0.74
                                        }
                                    }

                                    StackLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        visible: detailsTabs.visible
                                        currentIndex: detailsTabs.currentIndex

                                        ReactionDetailsPane {
                                            reaction: appBridge.selectedReaction
                                        }

                                        ReactionEditorPane {
                                            reaction: appBridge.selectedReaction
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                SmilesGeneratorPane { }

                PlaceholderPage {
                    title: "Settings"
                    subtitle: "Theme preferences, external tool paths, and optional defaults will live here later."
                }
            }
        }
    }
}
