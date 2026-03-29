import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: 12
    color: compact ? "#111923" : "#101923"
    border.color: expanded ? "#2c445e" : "#223244"

    property string moleculeTitle: "Molecule"
    property string smilesText: ""
    property string lookupNameQuery: ""
    property string lookupCasQuery: ""
    property bool compact: false
    property bool expanded: !compact
    property bool showStats: true
    property bool enablePubChem: true
    property var analysisResult: ({
        success: false,
        canonicalSmiles: "",
        formula: "",
        molarMass: "",
        inchiKey: "",
        iupacName: "",
        cid: "",
        synonyms: [],
        svgDataUri: "",
        message: "Use Preview, Draw, Edit, or PubChem tools to work with this field."
    })

    signal smilesAccepted(string canonicalSmiles)
    signal analysisAccepted(var resultObject)
    signal pubchemAccepted(var resultObject)

    function applyResult(resultObject, fromPubChem) {
        if (!resultObject)
            return
        analysisResult = resultObject
        var nextSmiles = resultObject.canonicalSmiles !== undefined ? String(resultObject.canonicalSmiles) : ""
        if ((!nextSmiles || nextSmiles.length === 0) && root.smilesText && String(root.smilesText).length > 0)
            nextSmiles = String(root.smilesText)
        if (nextSmiles.length > 0)
            root.smilesAccepted(nextSmiles)
        root.analysisAccepted(resultObject)
        if (fromPubChem)
            root.pubchemAccepted(resultObject)
    }

    implicitHeight: content.implicitHeight + 20

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: compact ? "SMILES tools" : "SMILES tools and preview"
                font.bold: true
                opacity: 0.92
            }

            Item { Layout.fillWidth: true }

            ToolButton {
                text: root.expanded ? "Hide" : "Show"
                onClicked: root.expanded = !root.expanded
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text: "Preview"
                highlighted: true
                enabled: root.smilesText.trim().length > 0
                onClicked: root.applyResult(appBridge.analyzeSmilesNamed(root.smilesText, root.moleculeTitle), false)
            }
            Button {
                text: "Draw"
                onClicked: root.applyResult(appBridge.drawSmilesInEditorNamed(root.moleculeTitle), false)
            }
            Button {
                text: "Edit"
                enabled: root.smilesText.trim().length > 0
                onClicked: root.applyResult(appBridge.editSmilesInEditorNamed(root.smilesText, root.moleculeTitle), false)
            }
            Button {
                visible: root.enablePubChem
                text: "PubChem ← SMILES"
                enabled: root.smilesText.trim().length > 0
                onClicked: root.applyResult(appBridge.lookupPubChemBySmilesNamed(root.smilesText, root.moleculeTitle), true)
            }
            Button {
                visible: root.enablePubChem
                text: "PubChem ← name"
                enabled: root.lookupNameQuery.trim().length > 0
                onClicked: root.applyResult(appBridge.lookupPubChemByNameNamed(root.lookupNameQuery, root.moleculeTitle), true)
            }
            Button {
                visible: root.enablePubChem
                text: "PubChem ← CAS"
                enabled: root.lookupCasQuery.trim().length > 0
                onClicked: root.applyResult(appBridge.lookupPubChemByCasNamed(root.lookupCasQuery, root.moleculeTitle), true)
            }
            Button {
                text: "Copy"
                enabled: root.smilesText.trim().length > 0
                onClicked: appBridge.copyText(root.smilesText)
            }
        }

        Label {
            Layout.fillWidth: true
            text: analysisResult.message || ""
            wrapMode: Text.Wrap
            color: analysisResult.success ? "#9ad28b" : "#ffd166"
            opacity: 0.95
            visible: text.length > 0
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.expanded
            spacing: 10

            ZoomableSvgPane {
                Layout.fillWidth: true
                Layout.preferredHeight: compact ? 260 : 340
                svgDataUri: analysisResult.svgDataUri || ""
                title: analysisResult.canonicalSmiles || root.moleculeTitle
                fallbackText: analysisResult.message || "No structure"
                baseWidth: compact ? 360 : 520
                baseHeight: compact ? 220 : 300
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: root.showStats

                StatCard {
                    Layout.fillWidth: true
                    title: "Formula"
                    value: analysisResult.formula || "—"
                }
                StatCard {
                    Layout.fillWidth: true
                    title: "Molar mass [g/mol]"
                    value: analysisResult.molarMass || "—"
                }
                StatCard {
                    Layout.fillWidth: true
                    title: "InChIKey"
                    value: analysisResult.inchiKey || "—"
                }
                StatCard {
                    Layout.fillWidth: true
                    title: "CAS"
                    value: analysisResult.casNumber || "—"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: !!analysisResult.cid || !!analysisResult.iupacName

                StatCard {
                    Layout.fillWidth: true
                    title: "PubChem CID"
                    value: analysisResult.cid || "—"
                }
                StatCard {
                    Layout.fillWidth: true
                    title: "IUPAC"
                    value: analysisResult.iupacName || "—"
                }
            }
        }
    }
}
