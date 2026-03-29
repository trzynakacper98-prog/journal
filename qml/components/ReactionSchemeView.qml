import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: 22
    color: "#141d27"
    border.color: "#253549"

    required property var reaction

    implicitHeight: contentColumn.implicitHeight + 30

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 18
        spacing: 16

        Label {
            text: "Reaction scheme"
            font.pixelSize: 18
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MoleculeCard {
                Layout.fillWidth: true
                title: reaction.substrate_1_id || "Substrate 1"
                subtitle: reaction.substrate_1_smiles || "No SMILES"
                amountText: reaction.substrate_1_summary_text || ""
                metaText: reaction.substrate_1_meta_text || ""
                svgDataUri: reaction.substrate_1_svg_uri || ""
            }

            Label {
                text: "+"
                font.pixelSize: 34
                opacity: hasSecondSubstrate ? 0.66 : 0.0
                visible: hasSecondSubstrate
                Layout.alignment: Qt.AlignVCenter
            }

            MoleculeCard {
                visible: hasSecondSubstrate
                Layout.fillWidth: true
                title: reaction.substrate_2_id || "Substrate 2"
                subtitle: reaction.substrate_2_smiles || "No SMILES"
                amountText: reaction.substrate_2_summary_text || ""
                metaText: reaction.substrate_2_meta_text || ""
                svgDataUri: reaction.substrate_2_svg_uri || ""
            }

            Rectangle {
                Layout.preferredWidth: 270
                Layout.fillHeight: true
                radius: 18
                color: "#18232e"
                border.color: "#27394b"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Label {
                        Layout.fillWidth: true
                        text: reaction.reagents_summary_text || "No reagents recorded"
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        opacity: 0.84
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "⟶"
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 52
                    }

                    Label {
                        Layout.fillWidth: true
                        text: reaction.conditions_summary_text || "No conditions"
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        opacity: 0.74
                    }
                }
            }

            MoleculeCard {
                Layout.fillWidth: true
                title: reaction.product_id || "Product"
                subtitle: reaction.product_smiles || "No SMILES"
                amountText: reaction.product_summary_text || ""
                metaText: reaction.product_meta_text || ""
                svgDataUri: reaction.product_svg_uri || ""
            }
        }
    }

    readonly property bool hasSecondSubstrate: !!(reaction.substrate_2_smiles || reaction.substrate_2_id)
}
