import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#10151d"

    property var analysisResult: ({
        success: false,
        inputSmiles: "",
        canonicalSmiles: "",
        formula: "",
        molarMass: "",
        inchiKey: "",
        iupacName: "",
        cid: "",
        casNumber: "",
        exactMass: "",
        atomCount: "",
        heavyAtomCount: "",
        ringCount: "",
        rotatableBonds: "",
        hBondDonors: "",
        hBondAcceptors: "",
        tpsa: "",
        logP: "",
        formalCharge: "",
        propertySource: "",
        synonyms: [],
        svgDataUri: "",
        message: "Use the generator to draw, edit, preview, or inspect a molecule."
    })

    function applyResult(resultObject, overwriteField) {
        if (!resultObject)
            return
        analysisResult = resultObject
        if (overwriteField && resultObject.canonicalSmiles !== undefined)
            smilesInput.text = resultObject.canonicalSmiles
    }

    function previewCurrent() {
        applyResult(appBridge.analyzeSmiles(smilesInput.text), true)
    }

    function loadSelectedSmiles(fieldName) {
        var reaction = appBridge.selectedReaction || ({})
        var value = reaction[fieldName]
        smilesInput.text = value ? String(value) : ""
        previewCurrent()
    }

    Rectangle {
        width: root.width
        implicitHeight: generatorColumn.implicitHeight + 32
        color: "#10151d"

        ColumnLayout {
            id: generatorColumn
            width: parent.width - 32
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 16
            spacing: 16

            Label {
                text: "SMILES / Molecule Generator"
                font.pixelSize: 28
                font.bold: true
            }

            Label {
                Layout.fillWidth: true
                text: "Draw a structure in rdEditor, edit an existing SMILES, preview it instantly, or inspect a molecule with RDKit and PubChem-backed properties."
                wrapMode: Text.Wrap
                opacity: 0.82
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                StatCard {
                    Layout.fillWidth: true
                    title: "RDKit"
                    value: appBridge.capabilities.rdkitStatus || "Unknown"
                }
                StatCard {
                    Layout.fillWidth: true
                    title: "rdEditor"
                    value: appBridge.capabilities.rdeditorStatus || "Unknown"
                }
                StatCard {
                    Layout.fillWidth: true
                    title: "Selected reaction"
                    value: appBridge.selectedReaction.reaction_id || "None"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 760
                    radius: 14
                    color: "#131b25"
                    border.color: "#223244"
                    implicitHeight: editorColumn.implicitHeight + 28

                    ColumnLayout {
                        id: editorColumn
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        Label {
                            text: "SMILES input"
                            font.pixelSize: 18
                            font.bold: true
                        }

                        TextArea {
                            id: smilesInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: 140
                            wrapMode: TextEdit.WrapAnywhere
                            selectByMouse: true
                            placeholderText: "Paste a SMILES here or use rdEditor to draw / edit a molecule"
                            font.family: "Monospace"
                            color: "#ecf2f8"
                        }

                        TextField {
                            id: nameLookupInput
                            Layout.fillWidth: true
                            placeholderText: "Optional PubChem name / synonym / CID lookup"
                        }

                        TextField {
                            id: casLookupInput
                            Layout.fillWidth: true
                            placeholderText: "Optional CAS lookup"
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 10

                            Button {
                                text: "Preview"
                                highlighted: true
                                onClicked: root.previewCurrent()
                            }
                            Button {
                                text: "Draw new in rdEditor"
                                onClicked: root.applyResult(appBridge.drawSmilesInEditor(), true)
                            }
                            Button {
                                text: "Edit current in rdEditor"
                                enabled: smilesInput.text.trim().length > 0
                                onClicked: root.applyResult(appBridge.editSmilesInEditor(smilesInput.text), true)
                            }
                            Button {
                                text: "PubChem ← SMILES"
                                enabled: smilesInput.text.trim().length > 0
                                onClicked: root.applyResult(appBridge.lookupPubChemBySmiles(smilesInput.text), true)
                            }
                            Button {
                                text: "PubChem ← name"
                                enabled: nameLookupInput.text.trim().length > 0
                                onClicked: root.applyResult(appBridge.lookupPubChemByName(nameLookupInput.text), true)
                            }
                            Button {
                                text: "PubChem ← CAS"
                                enabled: casLookupInput.text.trim().length > 0
                                onClicked: root.applyResult(appBridge.lookupPubChemByCas(casLookupInput.text), true)
                            }
                            Button {
                                text: "Copy"
                                enabled: smilesInput.text.trim().length > 0
                                onClicked: appBridge.copyText(smilesInput.text)
                            }
                            Button {
                                text: "Clear"
                                onClicked: {
                                    smilesInput.text = ""
                                    nameLookupInput.text = ""
                                    casLookupInput.text = ""
                                    root.previewCurrent()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            radius: 12
                            color: "#0f1620"
                            border.color: "#203141"
                            implicitHeight: loadRow.implicitHeight + 20

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Label {
                                    text: "Load structure from selected reaction"
                                    font.bold: true
                                }

                                RowLayout {
                                    id: loadRow
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Button {
                                        text: "Substrate 1"
                                        enabled: !!appBridge.selectedReaction.substrate_1_smiles
                                        onClicked: root.loadSelectedSmiles("substrate_1_smiles")
                                    }
                                    Button {
                                        text: "Substrate 2"
                                        enabled: !!appBridge.selectedReaction.substrate_2_smiles
                                        onClicked: root.loadSelectedSmiles("substrate_2_smiles")
                                    }
                                    Button {
                                        text: "Product"
                                        enabled: !!appBridge.selectedReaction.product_smiles
                                        onClicked: root.loadSelectedSmiles("product_smiles")
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: analysisResult.message || ""
                            wrapMode: Text.Wrap
                            color: analysisResult.success ? "#9ad28b" : "#ffd166"
                            opacity: 0.95
                        }

                        Label {
                            Layout.fillWidth: true
                            text: analysisResult.propertySource ? ("Property source: " + analysisResult.propertySource) : "Property source: —"
                            wrapMode: Text.Wrap
                            opacity: 0.72
                        }

                        Label {
                            Layout.fillWidth: true
                            text: analysisResult.canonicalSmiles ? ("Canonical SMILES: " + analysisResult.canonicalSmiles) : "Canonical SMILES: —"
                            wrapMode: Text.WrapAnywhere
                            opacity: 0.82
                        }
                        Label {
                            Layout.fillWidth: true
                            text: analysisResult.casNumber ? ("CAS: " + analysisResult.casNumber) : "CAS: —"
                            wrapMode: Text.WrapAnywhere
                            opacity: 0.82
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 720
                    radius: 14
                    color: "#131b25"
                    border.color: "#223244"
                    implicitHeight: previewColumn.implicitHeight + 28

                    ColumnLayout {
                        id: previewColumn
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        Label {
                            text: "Structure preview"
                            font.pixelSize: 18
                            font.bold: true
                        }

                        ZoomableSvgPane {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 460
                            svgDataUri: analysisResult.svgDataUri || ""
                            title: analysisResult.canonicalSmiles || "SMILES Generator"
                            fallbackText: analysisResult.message || "No structure"
                            baseWidth: 600
                            baseHeight: 420
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 14
                color: "#131b25"
                border.color: "#223244"
                implicitHeight: rdkitColumn.implicitHeight + 22

                ColumnLayout {
                    id: rdkitColumn
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Label {
                        text: "Basic properties"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "Calculated with RDKit when possible, then enriched with PubChem identifiers when you use SMILES, name, or CAS lookup."
                        wrapMode: Text.Wrap
                        opacity: 0.72
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: 12
                        rowSpacing: 12

                        StatCard { Layout.fillWidth: true; title: "Formula"; value: analysisResult.formula || "—" }
                        StatCard { Layout.fillWidth: true; title: "Molar mass [g/mol]"; value: analysisResult.molarMass || "—" }
                        StatCard { Layout.fillWidth: true; title: "Exact mass"; value: analysisResult.exactMass || "—" }
                        StatCard { Layout.fillWidth: true; title: "Atoms"; value: analysisResult.atomCount || "—" }
                        StatCard { Layout.fillWidth: true; title: "Heavy atoms"; value: analysisResult.heavyAtomCount || "—" }
                        StatCard { Layout.fillWidth: true; title: "Formal charge"; value: analysisResult.formalCharge || "—" }
                        StatCard { Layout.fillWidth: true; title: "Rings"; value: analysisResult.ringCount || "—" }
                        StatCard { Layout.fillWidth: true; title: "Rotatable bonds"; value: analysisResult.rotatableBonds || "—" }
                        StatCard { Layout.fillWidth: true; title: "TPSA"; value: analysisResult.tpsa || "—" }
                        StatCard { Layout.fillWidth: true; title: "H-bond donors"; value: analysisResult.hBondDonors || "—" }
                        StatCard { Layout.fillWidth: true; title: "H-bond acceptors"; value: analysisResult.hBondAcceptors || "—" }
                        StatCard { Layout.fillWidth: true; title: "logP"; value: analysisResult.logP || "—" }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 14
                color: "#131b25"
                border.color: "#223244"
                implicitHeight: identifiersColumn.implicitHeight + 22

                ColumnLayout {
                    id: identifiersColumn
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Label {
                        text: "Identifiers and external metadata"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        StatCard { Layout.fillWidth: true; title: "PubChem CID"; value: analysisResult.cid || "—" }
                        StatCard { Layout.fillWidth: true; title: "CAS"; value: analysisResult.casNumber || "—" }
                        StatCard { Layout.fillWidth: true; title: "InChIKey"; value: analysisResult.inchiKey || "—" }
                    }

                    StatCard {
                        Layout.fillWidth: true
                        title: "IUPAC"
                        value: analysisResult.iupacName || "—"
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 14
                color: "#131b25"
                border.color: "#223244"
                implicitHeight: synonymsColumn.implicitHeight + 22
                visible: (analysisResult.synonyms || []).length > 0

                ColumnLayout {
                    id: synonymsColumn
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Label {
                        text: "PubChem synonyms"
                        font.bold: true
                    }

                    TextArea {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 90
                        readOnly: true
                        wrapMode: TextEdit.Wrap
                        text: (analysisResult.synonyms || []).join(", ")
                    }
                }
            }
        }
    }
}
