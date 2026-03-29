import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: 14
    color: "#16202b"
    border.color: "#253445"

    property string title: ""
    property string prefix: "substrate_1"
    property var formData: ({})
    property var updateField: null
    property var commitField: null

    function fieldValue(fieldName) {
        var key = prefix + "_" + fieldName
        var value = formData ? formData[key] : ""
        return value === undefined || value === null ? "" : String(value)
    }

    function toNumber(value) {
        var s = String(value === undefined || value === null ? "" : value).trim().replace(",", ".")
        if (!s.length)
            return NaN
        return Number(s)
    }

    function formatNumber(value, decimals) {
        if (value === undefined || value === null || isNaN(value))
            return ""
        return Number(value).toFixed(decimals)
    }

    function calculateQuantities() {
        var smiles = root.fieldValue("smiles")
        var molarMass = toNumber(root.fieldValue("molar_mass_g_mol"))
        if (isNaN(molarMass) && smiles.length > 0) {
            var analyzed = appBridge.analyzeSmilesNamed(smiles, root.title)
            root.applyAnalysis(analyzed)
            molarMass = toNumber(analyzed.molarMass)
        }

        var mass = toNumber(root.fieldValue("mass_g"))
        var moles = toNumber(root.fieldValue("moles_mol"))
        var volume = toNumber(root.fieldValue("volume_l"))
        var concentration = toNumber(root.fieldValue("concentration_M"))

        if (!isNaN(mass) && !isNaN(molarMass) && molarMass > 0) {
            moles = mass / molarMass
            root.updateField(prefix + "_moles_mol", formatNumber(moles, 6))
        } else if (!isNaN(volume) && !isNaN(concentration) && concentration > 0) {
            moles = volume * concentration
            root.updateField(prefix + "_moles_mol", formatNumber(moles, 6))
        }

        if (!isNaN(moles) && !isNaN(molarMass) && molarMass > 0 && (isNaN(mass) || mass <= 0))
            root.updateField(prefix + "_mass_g", formatNumber(moles * molarMass, 6))
        if (!isNaN(moles) && !isNaN(concentration) && concentration > 0 && (isNaN(volume) || volume <= 0))
            root.updateField(prefix + "_volume_l", formatNumber(moles / concentration, 6))
    }

    function triggerGlobalRecalc() {
        if (!root.commitField)
            return
        var candidates = ["moles_mol", "mass_g", "volume_l", "stoich_coeff", "molar_mass_g_mol", "concentration_M"]
        for (var i = 0; i < candidates.length; ++i) {
            var candidate = candidates[i]
            var value = root.fieldValue(candidate)
            if (String(value).trim().length > 0) {
                root.commitField(prefix + "_" + candidate, value)
                return
            }
        }
        root.commitField(prefix + "_stoich_coeff", root.fieldValue("stoich_coeff") || "1")
    }

    function applyAnalysis(resultObject) {
        if (!resultObject || !resultObject.success)
            return
        if (resultObject.canonicalSmiles !== undefined && String(resultObject.canonicalSmiles).length > 0)
            root.updateField(prefix + "_smiles", resultObject.canonicalSmiles)
        if (resultObject.formula !== undefined)
            root.updateField(prefix + "_formula", resultObject.formula)
        if (resultObject.molarMass !== undefined && String(resultObject.molarMass).length > 0)
            root.updateField(prefix + "_molar_mass_g_mol", resultObject.molarMass)
        if (resultObject.inchiKey !== undefined)
            root.updateField(prefix + "_inchi_key", resultObject.inchiKey)
    }

    function applyPubChem(resultObject) {
        if (!resultObject || !resultObject.success)
            return
        root.applyAnalysis(resultObject)
        if (resultObject.cid !== undefined)
            root.updateField(prefix + "_pubchem_cid", resultObject.cid)
        if (resultObject.casNumber !== undefined && String(resultObject.casNumber).length > 0)
            root.updateField(prefix + "_cas", resultObject.casNumber)
        if (resultObject.iupacName !== undefined)
            root.updateField(prefix + "_iupac_name", resultObject.iupacName)
        if (resultObject.synonyms !== undefined)
            root.updateField(prefix + "_pubchem_synonyms", (resultObject.synonyms || []).join(", "))
    }

    function fetchFromSmiles() {
        var smiles = root.fieldValue("smiles").trim()
        if (!smiles.length)
            return
        var enriched = appBridge.enrichFromSmilesNamed(smiles, root.fieldValue("id") || root.title)
        if (enriched)
            root.applyPubChem(enriched)
        root.calculateQuantities()
        root.triggerGlobalRecalc()
    }

    function fetchFromCas() {
        var cas = root.fieldValue("cas").trim()
        if (!cas.length)
            return
        var enriched = appBridge.lookupPubChemByCasNamed(cas, root.fieldValue("id") || root.title)
        if (enriched && enriched.success)
            root.applyPubChem(enriched)
        root.calculateQuantities()
        root.triggerGlobalRecalc()
    }

    implicitHeight: content.implicitHeight + 24

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Label {
            text: root.title
            font.pixelSize: 18
            font.bold: true
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 10
            rowSpacing: 8

            Label { text: "ID / name" }
            TextField {
                Layout.fillWidth: true
                Layout.columnSpan: 3
                text: root.fieldValue("id")
                onTextEdited: root.updateField(prefix + "_id", text)
            }

            Label { text: "SMILES" }
            TextField {
                Layout.fillWidth: true
                Layout.columnSpan: 3
                text: root.fieldValue("smiles")
                placeholderText: "Paste SMILES or use Draw / Edit below"
                onTextEdited: root.updateField(prefix + "_smiles", text)
                onEditingFinished: root.fetchFromSmiles()
            }

            Label { text: "Moles [mol]" }
            TextField {
                Layout.fillWidth: true
                text: root.fieldValue("moles_mol")
                onTextEdited: root.updateField(prefix + "_moles_mol", text)
                onEditingFinished: if (root.commitField) root.commitField(prefix + "_moles_mol", text)
            }

            Label { text: "Mass [g]" }
            TextField {
                Layout.fillWidth: true
                text: root.fieldValue("mass_g")
                onTextEdited: root.updateField(prefix + "_mass_g", text)
                onEditingFinished: if (root.commitField) root.commitField(prefix + "_mass_g", text)
            }

            Label { text: "Volume [L]" }
            TextField {
                Layout.fillWidth: true
                text: root.fieldValue("volume_l")
                onTextEdited: root.updateField(prefix + "_volume_l", text)
                onEditingFinished: if (root.commitField) root.commitField(prefix + "_volume_l", text)
            }

            Label { text: "Conc. [M]" }
            TextField {
                Layout.fillWidth: true
                text: root.fieldValue("concentration_M")
                onTextEdited: root.updateField(prefix + "_concentration_M", text)
                onEditingFinished: if (root.commitField) root.commitField(prefix + "_concentration_M", text)
            }

            Label { text: "Stoich. coeff." }
            TextField {
                Layout.fillWidth: true
                text: root.fieldValue("stoich_coeff")
                onTextEdited: root.updateField(prefix + "_stoich_coeff", text)
                onEditingFinished: if (root.commitField) root.commitField(prefix + "_stoich_coeff", text)
            }

            Label { text: "Molar mass [g/mol]" }
            TextField {
                Layout.fillWidth: true
                text: root.fieldValue("molar_mass_g_mol")
                onTextEdited: root.updateField(prefix + "_molar_mass_g_mol", text)
                onEditingFinished: if (root.commitField) root.commitField(prefix + "_molar_mass_g_mol", text)
            }

            Label { text: "CAS" }
            TextField {
                Layout.fillWidth: true
                text: root.fieldValue("cas")
                placeholderText: "Auto-filled from PubChem or enter CAS"
                onTextEdited: root.updateField(prefix + "_cas", text)
                onEditingFinished: root.fetchFromCas()
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
                Layout.preferredHeight: 64
                wrapMode: TextEdit.Wrap
                text: root.fieldValue("pubchem_synonyms")
                onTextChanged: if (activeFocus) root.updateField(prefix + "_pubchem_synonyms", text)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: "Calculate"
                highlighted: true
                onClicked: {
                    root.calculateQuantities()
                    root.triggerGlobalRecalc()
                }
            }
            Label {
                Layout.fillWidth: true
                text: "Reference amount comes from Substrate 1. Stoichiometry updates other substrates and reagents automatically after you commit a value."
                opacity: 0.68
                wrapMode: Text.Wrap
            }
        }

        InlineSmilesTools {
            Layout.fillWidth: true
            moleculeTitle: root.fieldValue("id") || root.title
            smilesText: root.fieldValue("smiles")
            lookupNameQuery: root.fieldValue("id")
            lookupCasQuery: root.fieldValue("cas")
            compact: false
            onSmilesAccepted: function(canonicalSmiles) {
                root.updateField(prefix + "_smiles", canonicalSmiles)
            }
            onAnalysisAccepted: function(resultObject) {
                root.applyAnalysis(resultObject)
            }
            onPubchemAccepted: function(resultObject) {
                root.applyPubChem(resultObject)
                root.triggerGlobalRecalc()
            }
        }
    }
}
