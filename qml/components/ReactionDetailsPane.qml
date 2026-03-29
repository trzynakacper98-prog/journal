import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: root
    contentWidth: width
    clip: true

    required property var reaction

    Rectangle {
        width: root.width
        implicitHeight: detailsColumn.implicitHeight + 34
        color: "#10151d"

        ColumnLayout {
            id: detailsColumn
            width: parent.width - 32
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 16
            spacing: 16

            Rectangle {
                Layout.fillWidth: true
                radius: 24
                color: "#141d27"
                border.color: "#253549"
                implicitHeight: heroColumn.implicitHeight + 28

                ColumnLayout {
                    id: heroColumn
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 8

                    Label {
                        text: reaction.reaction_id || "Select a reaction"
                        font.pixelSize: 30
                        font.bold: true
                    }

                    Label {
                        visible: !!reaction.reaction_type
                        text: reaction.reaction_type || ""
                        font.pixelSize: 16
                        opacity: 0.76
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                StatCard {
                    Layout.fillWidth: true
                    title: "Date"
                    value: reaction.date_started || "—"
                }
                StatCard {
                    Layout.fillWidth: true
                    title: "Template"
                    value: reaction.template_name || "—"
                }
                StatCard {
                    Layout.fillWidth: true
                    title: "Yield"
                    value: reaction.yield_percent !== undefined && reaction.yield_percent !== null && reaction.yield_percent !== "" ? (Number(reaction.yield_percent).toFixed(1) + "%") : "—"
                }
                StatCard {
                    Layout.fillWidth: true
                    title: "Renderer"
                    value: reaction.rdkit_status || "RDKit status unknown"
                }
            }

            ReactionSchemeView {
                Layout.fillWidth: true
                reaction: root.reaction
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                InfoPanel {
                    Layout.fillWidth: true
                    title: "Conditions"
                    body: reaction.conditions_summary_text || "No conditions recorded"
                }
                InfoPanel {
                    Layout.fillWidth: true
                    title: "Reagents over arrow"
                    body: reaction.reagents_summary_text || "No reagents recorded"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                InfoPanel {
                    Layout.fillWidth: true
                    title: "Tags"
                    body: reaction.tags || "No tags"
                }
                InfoPanel {
                    Layout.fillWidth: true
                    title: "Dates"
                    body: ((reaction.date_started ? ("Started: " + reaction.date_started) : "")
                           + (reaction.date_started && reaction.date_finished ? "\n" : "")
                           + (reaction.date_finished ? ("Finished: " + reaction.date_finished) : "")) || "No dates"
                }
            }

            InfoPanel {
                Layout.fillWidth: true
                title: "Other conditions / notes"
                body: reaction.notes_summary_text || "No notes"
            }
        }
    }
}
