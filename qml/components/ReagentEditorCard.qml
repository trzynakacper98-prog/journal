import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: 14
    color: "#16202b"
    border.color: "#253445"

    property int reagentIndex: 1
    property var formData: ({})
    property var updateField: null
    property var commitField: null

    readonly property string prefix: "reagent_" + reagentIndex

    function fieldValue(fieldName) {
        var key = prefix + "_" + fieldName
        var value = formData ? formData[key] : ""
        return value === undefined || value === null ? "" : String(value)
    }

    function applyPubChem(resultObject) {
        if (!resultObject || !resultObject.success)
            return
        if (resultObject.canonicalSmiles !== undefined && String(resultObject.canonicalSmiles).length > 0)
            root.updateField(prefix + "_smiles", resultObject.canonicalSmiles)
        if (resultObject.casNumber !== undefined && String(resultObject.casNumber).length > 0)
            root.updateField(prefix + "_cas", resultObject.casNumber)
        if (resultObject.molarMass !== undefined && String(resultObject.molarMass).length > 0)
            root.updateField(prefix + "_molar_mass_g_mol", resultObject.molarMass)
        if (resultObject.formula !== undefined)
            root.updateField(prefix + "_formula", resultObject.formula)
        if (resultObject.inchiKey !== undefined)
            root.updateField(prefix + "_inchi_key", resultObject.inchiKey)
        if (resultObject.cid !== undefined)
            root.updateField(prefix + "_pubchem_cid", resultObject.cid)
        if (resultObject.iupacName !== undefined && String(resultObject.iupacName).length > 0)
            root.updateField(prefix + "_iupac_name", resultObject.iupacName)
        if (resultObject.synonyms !== undefined)
            root.updateField(prefix + "_pubchem_synonyms", (resultObject.synonyms || []).join(", "))
        if ((!root.fieldValue("name") || root.fieldValue("name").length === 0) && resultObject.iupacName !== undefined && String(resultObject.iupacName).length > 0)
            root.updateField(prefix + "_name", resultObject.iupacName)
    }

    function fetchFromSmiles() {
        var smiles = root.fieldValue("smiles").trim()
        if (!smiles.length)
            return
        var enriched = appBridge.enrichFromSmilesNamed(smiles, root.fieldValue("name") || root.fieldValue("id") || ("Reagent " + reagentIndex))
        if (enriched)
            root.applyPubChem(enriched)
        if (root.commitField)
            root.commitField(prefix + "_equiv", root.fieldValue("equiv") || "")
    }

    function fetchFromCas() {
        var cas = root.fieldValue("cas").trim()
        if (!cas.length)
            return
        var enriched = appBridge.lookupPubChemByCasNamed(cas, root.fieldValue("name") || root.fieldValue("id") || ("Reagent " + reagentIndex))
        if (enriched && enriched.success)
            root.applyPubChem(enriched)
        if (root.commitField)
            root.commitField(prefix + "_equiv", root.fieldValue("equiv") || "")
    }

    implicitHeight: content.implicitHeight + 24

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Label {
            text: "Reagent " + reagentIndex
            font.pixelSize: 16
            font.bold: true
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 10
            rowSpacing: 8

            Label { text: "Class" }
            TextField {
                Layout.fillWidth: true
                text: root.fieldValue("class")
                onTextEdited: root.updateField(prefix + "_class", text)
            }

            Label { text: "Equiv" }
            TextField {
                Layout.fillWidth: true
                text: root.fieldValue("equiv")
                onTextEdited: root.updateField(prefix + "_equiv", text)
                onEditingFinished: if (root.commitField) root.commitField(prefix + "_equiv", text)
            }

            Label { text: "Moles [mol]" }
            TextField {
                Layout.fillWidth: true
                readOnly: true
                text: root.fieldValue("moles_mol")
            }

            Label { text: "Mass [g]" }
            TextField {
                Layout.fillWidth: true
                readOnly: true
                text: root.fieldValue("mass_g")
            }

            Label { text: "Name" }
            TextField {
                Layout.fillWidth: true
                Layout.columnSpan: 3
                text: root.fieldValue("name")
                onTextEdited: root.updateField(prefix + "_name", text)
            }

            Label { text: "ID" }
            TextField {
                Layout.fillWidth: true
                text: root.fieldValue("id")
                onTextEdited: root.updateField(prefix + "_id", text)
            }

            Label { text: "CAS" }
            TextField {
                Layout.fillWidth: true
                text: root.fieldValue("cas")
                onTextEdited: root.updateField(prefix + "_cas", text)
                onEditingFinished: root.fetchFromCas()
            }

            Label { text: "SMILES" }
            TextField {
                Layout.fillWidth: true
                Layout.columnSpan: 3
                text: root.fieldValue("smiles")
                placeholderText: "Optional reagent SMILES"
                onTextEdited: root.updateField(prefix + "_smiles", text)
                onEditingFinished: root.fetchFromSmiles()
            }

            Label { text: "Molar mass [g/mol]" }
            TextField {
                Layout.fillWidth: true
                text: root.fieldValue("molar_mass_g_mol")
                onTextEdited: root.updateField(prefix + "_molar_mass_g_mol", text)
                onEditingFinished: if (root.commitField) root.commitField(prefix + "_equiv", root.fieldValue("equiv") || "")
            }

            Label { text: "Formula" }
            TextField {
                Layout.fillWidth: true
                text: root.fieldValue("formula")
                onTextEdited: root.updateField(prefix + "_formula", text)
            }

            Label { text: "InChIKey" }
            TextField {
                Layout.fillWidth: true
                text: root.fieldValue("inchi_key")
                onTextEdited: root.updateField(prefix + "_inchi_key", text)
            }

            Label { text: "PubChem CID" }
            TextField {
                Layout.fillWidth: true
                text: root.fieldValue("pubchem_cid")
                onTextEdited: root.updateField(prefix + "_pubchem_cid", text)
            }

            Label { text: "IUPAC" }
            TextField {
                Layout.fillWidth: true
                Layout.columnSpan: 3
                text: root.fieldValue("iupac_name")
                onTextEdited: root.updateField(prefix + "_iupac_name", text)
            }

            Label { text: "Synonyms" }
            TextArea {
                Layout.fillWidth: true
                Layout.columnSpan: 3
                Layout.preferredHeight: 54
                wrapMode: TextEdit.Wrap
                text: root.fieldValue("pubchem_synonyms")
                onTextChanged: if (activeFocus) root.updateField(prefix + "_pubchem_synonyms", text)
            }
        }

        InlineSmilesTools {
            Layout.fillWidth: true
            moleculeTitle: root.fieldValue("name") || root.fieldValue("id") || ("Reagent " + reagentIndex)
            smilesText: root.fieldValue("smiles")
            lookupNameQuery: root.fieldValue("name") || root.fieldValue("id")
            lookupCasQuery: root.fieldValue("cas")
            compact: true
            onSmilesAccepted: function(canonicalSmiles) {
                root.updateField(prefix + "_smiles", canonicalSmiles)
            }
            onPubchemAccepted: function(resultObject) {
                root.applyPubChem(resultObject)
                if (root.commitField)
                    root.commitField(prefix + "_equiv", root.fieldValue("equiv") || "")
            }
        }
    }
}
