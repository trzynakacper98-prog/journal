import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#10151d"

    property int selectedTemplateIndex: templateList.currentIndex
    property var selectedTemplate: (selectedTemplateIndex >= 0 && selectedTemplateIndex < appBridge.templates.length) ? appBridge.templates[selectedTemplateIndex] : null

    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal

        Rectangle {
            SplitView.preferredWidth: 450
            SplitView.minimumWidth: 350
            radius: 22
            color: "#0f141c"
            border.color: "#1c2a38"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    radius: 20
                    color: "#131b25"
                    border.color: "#223244"
                    implicitHeight: introColumn.implicitHeight + 24

                    ColumnLayout {
                        id: introColumn
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Label {
                            text: "Reaction templates"
                            font.pixelSize: 24
                            font.bold: true
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            opacity: 0.78
                            text: "Built-in templates help you start quickly. You can also create your own templates from completed reactions, which makes it easy to repeat something like a Sonogashira run with different substrates without rewriting all conditions and reagents."
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Button {
                                text: "Refresh"
                                onClicked: appBridge.refreshTemplates()
                            }
                            Button {
                                text: "Use selected"
                                enabled: !!root.selectedTemplate
                                highlighted: true
                                onClicked: {
                                    if (root.selectedTemplate)
                                        appBridge.applyTemplateToEditor(root.selectedTemplate.id)
                                }
                            }
                            Button {
                                text: "Delete"
                                enabled: !!root.selectedTemplate && root.selectedTemplate.kind !== "builtin"
                                onClicked: deleteDialog.open()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: 18
                    color: "#131b25"
                    border.color: "#223244"
                    implicitHeight: createColumn.implicitHeight + 22

                    ColumnLayout {
                        id: createColumn
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Label {
                            text: "Create template from selected reaction"
                            font.pixelSize: 18
                            font.bold: true
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            opacity: 0.82
                            text: appBridge.selectedReaction && appBridge.selectedReaction.reaction_id ?
                                  "Selected reaction: " + appBridge.selectedReaction.reaction_id + " — the template will keep conditions, stoichiometry, and reagents, but clear substrates, product fields, masses, and yield." :
                                  "Select a saved reaction in Journal first."
                        }
                        TextField {
                            id: templateNameField
                            Layout.fillWidth: true
                            placeholderText: appBridge.selectedReaction && appBridge.selectedReaction.reaction_id ?
                                             (appBridge.selectedReaction.reaction_id + " repeat template") : "Template name"
                        }
                        TextArea {
                            id: templateDescriptionField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 76
                            wrapMode: TextEdit.Wrap
                            placeholderText: "Optional description, for example: default setup for repeated Sonogashira reactions"
                        }
                        Button {
                            text: "Create from selected reaction"
                            enabled: appBridge.selectedReaction && appBridge.selectedReaction.id
                            highlighted: true
                            onClicked: {
                                var name = templateNameField.text.trim()
                                if (!name && appBridge.selectedReaction && appBridge.selectedReaction.reaction_id)
                                    name = appBridge.selectedReaction.reaction_id + " repeat template"
                                if (appBridge.createTemplateFromSelectedReaction(name, templateDescriptionField.text)) {
                                    templateNameField.text = ""
                                    templateDescriptionField.text = ""
                                }
                            }
                        }
                    }
                }

                Label {
                    text: "Templates"
                    font.pixelSize: 18
                    font.bold: true
                }

                ListView {
                    id: templateList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: appBridge.templates
                    currentIndex: count > 0 && currentIndex < 0 ? 0 : currentIndex

                    delegate: ItemDelegate {
                        id: templateDelegate
                        width: ListView.view.width
                        height: 112
                        highlighted: ListView.isCurrentItem
                        hoverEnabled: true
                        onClicked: templateList.currentIndex = index

                        background: Rectangle {
                            radius: 16
                            color: ListView.isCurrentItem ? "#1b3448" : (templateDelegate.hovered ? "#1a2531" : "#16202b")
                            border.color: ListView.isCurrentItem ? "#6bc7ff" : "#233141"
                            border.width: ListView.isCurrentItem ? 2 : 1
                        }

                        contentItem: ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4
                            Label {
                                text: modelData.name || "(unnamed template)"
                                font.bold: true
                                elide: Label.ElideRight
                            }
                            Label {
                                text: (modelData.kind === "builtin" ? "Built-in" : "Custom") + (modelData.category ? " • " + modelData.category : "")
                                opacity: 0.68
                                elide: Label.ElideRight
                            }
                            Label {
                                Layout.fillWidth: true
                                text: modelData.description || modelData.preview_text || ""
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                opacity: 0.82
                            }
                        }
                    }
                }
            }
        }

        ScrollView {
            SplitView.fillWidth: true
            clip: true

            ColumnLayout {
                width: Math.max(parent.width - 20, 460)
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 10
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    radius: 22
                    color: "#131b25"
                    border.color: "#223244"
                    implicitHeight: detailsColumn.implicitHeight + 26

                    ColumnLayout {
                        id: detailsColumn
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Label {
                            text: root.selectedTemplate ? root.selectedTemplate.name : "Select a template"
                            font.pixelSize: 24
                            font.bold: true
                        }

                        Label {
                            visible: !!root.selectedTemplate
                            text: root.selectedTemplate ? ((root.selectedTemplate.kind === "builtin" ? "Built-in" : "Custom") + (root.selectedTemplate.category ? " • " + root.selectedTemplate.category : "")) : ""
                            opacity: 0.75
                        }

                        Label {
                            Layout.fillWidth: true
                            visible: !!root.selectedTemplate
                            wrapMode: Text.Wrap
                            text: root.selectedTemplate ? (root.selectedTemplate.description || "No template description.") : ""
                            opacity: 0.88
                        }

                        GridLayout {
                            visible: !!root.selectedTemplate
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 10
                            rowSpacing: 8

                            Label { text: "Source reaction" }
                            Label { text: root.selectedTemplate && root.selectedTemplate.source_reaction_id ? root.selectedTemplate.source_reaction_id : "—" }
                            Label { text: "Reaction type" }
                            Label { text: root.selectedTemplate && root.selectedTemplate.reaction_type ? root.selectedTemplate.reaction_type : "—" }
                            Label { text: "Stored template label" }
                            Label { text: root.selectedTemplate && root.selectedTemplate.template_name_preview ? root.selectedTemplate.template_name_preview : "—" }
                            Label { text: "Database kind" }
                            Label { text: root.selectedTemplate ? root.selectedTemplate.kind : "—" }
                        }
                    }
                }

                InfoPanel {
                    Layout.fillWidth: true
                    title: "What gets copied when you build a template from a finished reaction"
                    body: "The app keeps the reaction type, template name, stoichiometry, reagents, solvent, temperature, time, and process notes. It clears substrates, product fields, identifiers, SMILES, masses, moles, and yield so the new entry is ready for a repeat run on a different substrate set."
                }

                InfoPanel {
                    Layout.fillWidth: true
                    title: "Stored preview"
                    body: root.selectedTemplate ? (root.selectedTemplate.preview_text || "No preview") : "Select a template to preview stored conditions."
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        text: "Open in editor"
                        enabled: !!root.selectedTemplate
                        highlighted: true
                        onClicked: {
                            if (root.selectedTemplate)
                                appBridge.applyTemplateToEditor(root.selectedTemplate.id)
                        }
                    }
                    Button {
                        text: "Start blank reaction"
                        onClicked: appBridge.startBlankDraftInEditor()
                    }
                }
            }
        }
    }

    Dialog {
        id: deleteDialog
        title: "Delete template"
        standardButtons: Dialog.Ok | Dialog.Cancel
        modal: true
        onAccepted: {
            if (root.selectedTemplate)
                appBridge.deleteTemplate(root.selectedTemplate.id)
        }
        contentItem: Label {
            text: root.selectedTemplate ? ("Delete template ‘" + root.selectedTemplate.name + "’?") : "Delete selected template?"
            wrapMode: Text.Wrap
        }
    }
}
