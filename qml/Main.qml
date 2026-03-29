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
    property string journalMode: "empty" // empty, preview, editorNew, editorSelected

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
                        journalMode = "editorNew"
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
            journalMode = index === 1 ? "editorSelected" : "preview"
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
                            journalMode = "preview"
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
                                        text: {
                                            switch (journalMode) {
                                            case "editorNew": return "New reaction editor"
                                            case "editorSelected": return "Edit selected reaction"
                                            case "preview": return "Reaction preview"
                                            default: return "Reaction library details"
                                            }
                                        }
                                        font.bold: true
                                        opacity: 0.9
                                    }

                                    Item { Layout.fillWidth: true }

                                    Button {
                                        text: "Library view"
                                        enabled: journalMode !== "empty"
                                        onClicked: journalMode = appBridge.selectedReaction && appBridge.selectedReaction.id ? "preview" : "empty"
                                    }

                                    Button {
                                        text: "Edit selected"
                                        enabled: !!appBridge.selectedReaction && !!appBridge.selectedReaction.id
                                        onClicked: journalMode = "editorSelected"
                                    }

                                    Button {
                                        text: "New reaction window"
                                        highlighted: true
                                        onClicked: {
                                            appBridge.startBlankDraftInEditor()
                                            journalMode = "editorNew"
                                        }
                                    }
                                }
                            }

                            Loader {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                sourceComponent: {
                                    if (journalMode === "editorNew")
                                        return newReactionEditor
                                    if (journalMode === "editorSelected" && !!appBridge.selectedReaction && !!appBridge.selectedReaction.id)
                                        return selectedReactionEditor
                                    if (journalMode === "preview" && !!appBridge.selectedReaction && !!appBridge.selectedReaction.id)
                                        return selectedReactionPreview
                                    return emptyLibraryState
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

    Component {
        id: emptyLibraryState
        Rectangle {
            radius: 18
            color: "#0e141b"
            border.color: "#1f2d3b"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10

                Label {
                    text: "Select a reaction from Reaction Library"
                    font.pixelSize: 21
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
                Label {
                    text: "Preview appears only after selecting an item on the left."
                    opacity: 0.72
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Component {
        id: selectedReactionPreview
        ReactionDetailsPane {
            reaction: appBridge.selectedReaction
        }
    }

    Component {
        id: selectedReactionEditor
        ReactionEditorPane {
            reaction: appBridge.selectedReaction
        }
    }

    Component {
        id: newReactionEditor
        ReactionEditorPane {
            reaction: appBridge.editorDraft
        }
    }
}
