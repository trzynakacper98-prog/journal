import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#10151d"

    required property var reaction

    property var formData: ({})
    property bool dirty: false
    property int reagentCount: 0

    function cloneMap(obj) {
        if (!obj)
            return ({})
        return JSON.parse(JSON.stringify(obj))
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

    function isPositive(value) {
        return !(isNaN(value) || value <= 0)
    }

    function assignCalculated(copy, key, value, decimals, overwrite) {
        if (!isPositive(value))
            return
        if (!overwrite) {
            var current = toNumber(copy[key])
            if (isPositive(current))
                return
        }
        copy[key] = formatNumber(value, decimals)
    }

    function inferReagentCount(data) {
        var explicitCount = toNumber(data ? data["reagent_count"] : "")
        if (!isNaN(explicitCount) && explicitCount > 0)
            return Math.max(0, Math.min(4, Math.round(explicitCount)))
        var inferred = 0
        for (var idx = 1; idx <= 4; ++idx) {
            var prefix = "reagent_" + idx
            var keys = ["name", "id", "class", "cas", "smiles", "equiv", "formula", "mass_g", "moles_mol"]
            for (var i = 0; i < keys.length; ++i) {
                var value = data ? data[prefix + "_" + keys[i]] : ""
                if (value !== undefined && value !== null && String(value).trim().length > 0) {
                    inferred = idx
                    break
                }
            }
        }
        return inferred
    }

    function syncReagentCount(copy) {
        copy["reagent_count"] = reagentCount
        return copy
    }

    function clearReagentSlot(index) {
        var copy = cloneMap(formData)
        var prefix = "reagent_" + index
        var fields = ["class", "name", "id", "equiv", "moles_mol", "mass_g", "molar_mass_g_mol", "formula", "cas", "iupac_name", "inchi_key", "pubchem_cid", "pubchem_synonyms", "smiles"]
        for (var i = 0; i < fields.length; ++i) {
            var key = prefix + "_" + fields[i]
            copy[key] = (fields[i] === "equiv" || fields[i] === "moles_mol" || fields[i] === "mass_g" || fields[i] === "molar_mass_g_mol") ? "" : ""
        }
        formData = syncReagentCount(copy)
        dirty = true
    }

    function addReagent() {
        if (reagentCount >= 4)
            return
        reagentCount += 1
        var copy = cloneMap(formData)
        formData = syncReagentCount(copy)
        dirty = true
    }

    function removeLastReagent() {
        if (reagentCount <= 0)
            return
        clearReagentSlot(reagentCount)
        reagentCount = Math.max(0, reagentCount - 1)
        var copy = cloneMap(formData)
        formData = syncReagentCount(copy)
        dirty = true
    }

    function updateField(fieldName, value) {
        var copy = cloneMap(formData)
        copy[fieldName] = value
        if (fieldName.indexOf("reagent_") === 0) {
            var parts = fieldName.split("_")
            var idx = Number(parts[1])
            if (!isNaN(idx) && String(value).trim().length > 0)
                reagentCount = Math.max(reagentCount, idx)
        }
        formData = syncReagentCount(copy)
        dirty = true
    }

    function commitField(fieldName, value) {
        var copy = cloneMap(formData)
        copy[fieldName] = value
        if (fieldName.indexOf("reagent_") === 0) {
            var parts = fieldName.split("_")
            var idx = Number(parts[1])
            if (!isNaN(idx) && String(value).trim().length > 0)
                reagentCount = Math.max(reagentCount, idx)
        }
        copy = recalculateStoichiometry(copy)
        formData = syncReagentCount(copy)
        dirty = true
    }

    function recalculateStoichiometry(data) {
        var copy = cloneMap(data)

        var mw1 = toNumber(copy["substrate_1_molar_mass_g_mol"])
        var mass1 = toNumber(copy["substrate_1_mass_g"])
        var moles1 = toNumber(copy["substrate_1_moles_mol"])
        var vol1 = toNumber(copy["substrate_1_volume_l"])
        var conc1 = toNumber(copy["substrate_1_concentration_M"])
        var coeff1 = toNumber(copy["substrate_1_stoich_coeff"])
        if (!isPositive(coeff1))
            coeff1 = 1.0
        copy["substrate_1_stoich_coeff"] = formatNumber(coeff1, 3)

        if (!isPositive(moles1)) {
            if (isPositive(mass1) && isPositive(mw1))
                moles1 = mass1 / mw1
            else if (isPositive(vol1) && isPositive(conc1))
                moles1 = vol1 * conc1
        }
        if (isPositive(moles1)) {
            copy["substrate_1_moles_mol"] = formatNumber(moles1, 6)
            if (!isPositive(mass1) && isPositive(mw1))
                copy["substrate_1_mass_g"] = formatNumber(moles1 * mw1, 6)
            if (!isPositive(vol1) && isPositive(conc1))
                copy["substrate_1_volume_l"] = formatNumber(moles1 / conc1, 6)
        }

        var referenceMoles = isPositive(moles1) ? (moles1 / coeff1) : NaN
        if (!isPositive(referenceMoles))
            return copy

        function applySpecies(prefix, overwrite) {
            var coeff = toNumber(copy[prefix + "_stoich_coeff"])
            if (!isPositive(coeff))
                coeff = 1.0
            copy[prefix + "_stoich_coeff"] = formatNumber(coeff, 3)
            var targetMoles = referenceMoles * coeff
            assignCalculated(copy, prefix + "_moles_mol", targetMoles, 6, overwrite)
            var mw = toNumber(copy[prefix + "_molar_mass_g_mol"])
            if (isPositive(mw))
                assignCalculated(copy, prefix + "_mass_g", targetMoles * mw, 6, overwrite)
            var concentration = toNumber(copy[prefix + "_concentration_M"])
            if (isPositive(concentration))
                assignCalculated(copy, prefix + "_volume_l", targetMoles / concentration, 6, overwrite)
        }

        applySpecies("substrate_2", true)
        applySpecies("product", false)

        for (var idx = 1; idx <= 4; ++idx) {
            var prefix = "reagent_" + idx
            var equiv = toNumber(copy[prefix + "_equiv"])
            if (!isPositive(equiv))
                continue
            var reagentMoles = referenceMoles * equiv
            copy[prefix + "_moles_mol"] = formatNumber(reagentMoles, 6)
            var reagentMw = toNumber(copy[prefix + "_molar_mass_g_mol"])
            if (isPositive(reagentMw))
                copy[prefix + "_mass_g"] = formatNumber(reagentMoles * reagentMw, 6)
        }

        return copy
    }

    function fieldValue(fieldName) {
        var value = formData ? formData[fieldName] : ""
        return value === undefined || value === null ? "" : String(value)
    }

    function loadReaction(reactionObj) {
        if (reactionObj && Object.keys(reactionObj).length > 0)
            formData = cloneMap(reactionObj)
        else
            formData = appBridge.blankReactionDraft()
        reagentCount = inferReagentCount(formData)
        formData = syncReagentCount(cloneMap(formData))
        dirty = false
    }

    function startNewReaction() {
        formData = appBridge.blankReactionDraft()
        reagentCount = 0
        formData = syncReagentCount(cloneMap(formData))
        dirty = false
    }

    Component.onCompleted: loadReaction(reaction)
    onReactionChanged: loadReaction(reaction)

    Connections {
        target: appBridge
        function onEditorDraftChanged() {
            root.loadReaction(appBridge.editorDraft)
        }
    }

    ScrollView {
        anchors.fill: parent
        clip: true

        ColumnLayout {
            width: root.width - 28
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.top: parent.top
            anchors.topMargin: 14
            spacing: 14

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: formData.id ? ("Editing: " + (fieldValue("reaction_id") || "(no id)")) : "New reaction draft"
                    font.pixelSize: 24
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "New"
                    onClicked: startNewReaction()
                }
                Button {
                    text: "Reload selected"
                    enabled: !!reaction && !!reaction.id
                    onClicked: loadReaction(reaction)
                }
                Button {
                    text: "Use template"
                    onClicked: appBridge.setCurrentPage("templates")
                }
                Button {
                    text: "Duplicate selected"
                    enabled: !!reaction && !!reaction.id
                    onClicked: appBridge.duplicateSelectedReaction()
                }
                Button {
                    text: "Delete selected"
                    enabled: !!reaction && !!reaction.id
                    onClicked: deleteDialog.open()
                }
                Button {
                    text: formData.id ? "Save changes" : "Create reaction"
                    highlighted: true
                    onClicked: {
                        formData = syncReagentCount(cloneMap(formData))
                        if (appBridge.saveReaction(formData))
                            dirty = false
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                text: dirty ? "Unsaved changes" : "Saved / synced with selected reaction"
                color: dirty ? "#ffd166" : "#9ad28b"
                opacity: 0.9
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 14
                color: "#131b25"
                border.color: "#223244"
                implicitHeight: generalGrid.implicitHeight + 28

                GridLayout {
                    id: generalGrid
                    anchors.fill: parent
                    anchors.margins: 14
                    columns: 4
                    columnSpacing: 10
                    rowSpacing: 8

                    Label { text: "Reaction ID" }
                    TextField {
                        Layout.fillWidth: true
                        text: root.fieldValue("reaction_id")
                        onTextEdited: root.updateField("reaction_id", text)
                    }
                    Label { text: "Type" }
                    TextField {
                        Layout.fillWidth: true
                        text: root.fieldValue("reaction_type")
                        onTextEdited: root.updateField("reaction_type", text)
                    }

                    Label { text: "Started" }
                    TextField {
                        Layout.fillWidth: true
                        placeholderText: "YYYY-MM-DD"
                        text: root.fieldValue("date_started")
                        onTextEdited: root.updateField("date_started", text)
                    }
                    Label { text: "Finished" }
                    TextField {
                        Layout.fillWidth: true
                        placeholderText: "YYYY-MM-DD"
                        text: root.fieldValue("date_finished")
                        onTextEdited: root.updateField("date_finished", text)
                    }

                    Label { text: "Template" }
                    TextField {
                        Layout.fillWidth: true
                        text: root.fieldValue("template_name")
                        onTextEdited: root.updateField("template_name", text)
                    }
                    Label { text: "Tags" }
                    TextField {
                        Layout.fillWidth: true
                        text: root.fieldValue("tags")
                        placeholderText: "#sonogashira #screening"
                        onTextEdited: root.updateField("tags", text)
                    }

                    Label { text: "Yield [%]" }
                    TextField {
                        Layout.fillWidth: true
                        text: root.fieldValue("yield_percent")
                        onTextEdited: root.updateField("yield_percent", text)
                    }
                    Label { text: "Temperature [°C]" }
                    TextField {
                        Layout.fillWidth: true
                        text: root.fieldValue("temperature_c")
                        onTextEdited: root.updateField("temperature_c", text)
                    }

                    Label { text: "Time [h]" }
                    TextField {
                        Layout.fillWidth: true
                        text: root.fieldValue("time_h")
                        onTextEdited: root.updateField("time_h", text)
                    }
                    Label { text: "Solvent" }
                    TextField {
                        Layout.fillWidth: true
                        text: root.fieldValue("solvent_name")
                        onTextEdited: root.updateField("solvent_name", text)
                    }

                    Label { text: "Solvent vol. [L]" }
                    TextField {
                        Layout.fillWidth: true
                        text: root.fieldValue("solvent_volume_l")
                        onTextEdited: root.updateField("solvent_volume_l", text)
                    }
                }
            }

            SpeciesEditorCard {
                Layout.fillWidth: true
                title: "Substrate 1"
                prefix: "substrate_1"
                formData: root.formData
                updateField: root.updateField
                commitField: root.commitField
            }

            SpeciesEditorCard {
                Layout.fillWidth: true
                title: "Substrate 2"
                prefix: "substrate_2"
                formData: root.formData
                updateField: root.updateField
                commitField: root.commitField
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 14
                color: "#131b25"
                border.color: "#223244"
                implicitHeight: reagentHeader.implicitHeight + 28

                ColumnLayout {
                    id: reagentHeader
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Reagents"
                            font.pixelSize: 18
                            font.bold: true
                        }
                        Label {
                            text: reagentCount > 0 ? (reagentCount + " saved in this reaction") : "No reagents added yet"
                            opacity: 0.68
                            Layout.fillWidth: true
                        }
                        Button {
                            text: "Add reagent"
                            enabled: reagentCount < 4
                            onClicked: root.addReagent()
                        }
                        Button {
                            text: "Remove last"
                            enabled: reagentCount > 0
                            onClicked: root.removeLastReagent()
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "Use reagent cards for bases, acids, catalysts, additives, or named reagents like Et3N. Reagent data are saved with the reaction, and CAS lookup fills properties whenever PubChem can resolve them."
                        wrapMode: Text.Wrap
                        opacity: 0.72
                    }
                }
            }

            Repeater {
                model: root.reagentCount
                delegate: ReagentEditorCard {
                    Layout.fillWidth: true
                    reagentIndex: index + 1
                    formData: root.formData
                    updateField: root.updateField
                    commitField: root.commitField
                }
            }

            SpeciesEditorCard {
                Layout.fillWidth: true
                title: "Product (optional)"
                prefix: "product"
                formData: root.formData
                updateField: root.updateField
                commitField: root.commitField
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 14
                color: "#131b25"
                border.color: "#223244"
                implicitHeight: notesColumn.implicitHeight + 28

                ColumnLayout {
                    id: notesColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Label {
                        text: "Conditions and notes"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Label { text: "Other conditions" }
                    TextArea {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 90
                        wrapMode: TextEdit.Wrap
                        text: root.fieldValue("other_conditions")
                        onTextChanged: if (activeFocus) root.updateField("other_conditions", text)
                    }

                    Label { text: "Work-up" }
                    TextArea {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 90
                        wrapMode: TextEdit.Wrap
                        text: root.fieldValue("work_up")
                        onTextChanged: if (activeFocus) root.updateField("work_up", text)
                    }

                    Label { text: "Product notes" }
                    TextArea {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 90
                        wrapMode: TextEdit.Wrap
                        text: root.fieldValue("product_notes")
                        onTextChanged: if (activeFocus) root.updateField("product_notes", text)
                    }
                }
            }
        }
    }

    Dialog {
        id: deleteDialog
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        title: "Delete reaction"
        onAccepted: appBridge.deleteSelectedReaction()

        contentItem: Label {
            text: "Delete the currently selected reaction?"
            wrapMode: Text.Wrap
        }
    }
}
