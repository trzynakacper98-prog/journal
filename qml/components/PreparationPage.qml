import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#10151d"

    property string sourceKind: "selectedReaction"
    property int selectedTemplateId: 0
    property var plan: ({})

    function refreshPlan() {
        plan = appBridge.computePreparationPlan(
                    sourceKind,
                    selectedTemplateId,
                    targetSub1Field.text,
                    scalingFactorField.text,
                    solventCheck.checked)
    }

    function selectedTemplateName() {
        if (!appBridge.templates || appBridge.templates.length === 0)
            return ""
        for (var i = 0; i < appBridge.templates.length; ++i) {
            if ((appBridge.templates[i].id || 0) === selectedTemplateId)
                return appBridge.templates[i].name || ""
        }
        return ""
    }

    Component.onCompleted: {
        if (appBridge.templates && appBridge.templates.length > 0)
            selectedTemplateId = appBridge.templates[0].id || 0
        refreshPlan()
    }

    Connections {
        target: appBridge
        function onSelectedReactionChanged() {
            if (root.sourceKind === "selectedReaction")
                root.refreshPlan()
        }
        function onTemplatesChanged() {
            if (appBridge.templates && appBridge.templates.length > 0 && root.selectedTemplateId === 0)
                root.selectedTemplateId = appBridge.templates[0].id || 0
            if (root.sourceKind === "template")
                root.refreshPlan()
        }
    }

    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal

        ScrollView {
            SplitView.preferredWidth: 430
            SplitView.minimumWidth: 360
            clip: true

            ColumnLayout {
                width: Math.max(parent.width - 22, 340)
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 10
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    radius: 18
                    color: "#131b25"
                    border.color: "#223244"
                    implicitHeight: controlsColumn.implicitHeight + 26

                    ColumnLayout {
                        id: controlsColumn
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Label {
                            text: "Preparation / Scaling"
                            font.pixelSize: 24
                            font.bold: true
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            opacity: 0.82
                            text: "Choose a source, set the target amount of substrate 1 or enter a scale factor directly, and generate a weighing / volume plan. You can then load the scaled version into the editor as a new draft with one click."
                        }

                        Label { text: "Source" }
                        ComboBox {
                            Layout.fillWidth: true
                            model: [
                                { value: "selectedReaction", label: "Selected reaction" },
                                { value: "template", label: "Template" }
                            ]
                            textRole: "label"
                            onActivated: function(index) {
                                root.sourceKind = model[index].value
                                root.refreshPlan()
                            }
                            Component.onCompleted: currentIndex = 0
                        }

                        Label {
                            visible: root.sourceKind === "selectedReaction"
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: appBridge.selectedReaction && appBridge.selectedReaction.reaction_id ?
                                  ("Selected reaction: " + appBridge.selectedReaction.reaction_id + " — " + (appBridge.selectedReaction.reaction_type || "")) :
                                  "Select a saved reaction in Journal first."
                            opacity: 0.82
                        }

                        ColumnLayout {
                            visible: root.sourceKind === "template"
                            Layout.fillWidth: true
                            spacing: 6

                            Label { text: "Template" }
                            ComboBox {
                                id: templateCombo
                                Layout.fillWidth: true
                                model: appBridge.templates
                                textRole: "name"
                                onActivated: function(index) {
                                    var item = appBridge.templates[index]
                                    root.selectedTemplateId = item ? (item.id || 0) : 0
                                    root.refreshPlan()
                                }
                                onCurrentIndexChanged: {
                                    var item = appBridge.templates[currentIndex]
                                    if (item)
                                        root.selectedTemplateId = item.id || 0
                                }
                                Component.onCompleted: {
                                    if (appBridge.templates && appBridge.templates.length > 0) {
                                        currentIndex = 0
                                        root.selectedTemplateId = appBridge.templates[0].id || 0
                                    }
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                opacity: 0.82
                                text: root.selectedTemplateName() ? ("Selected template: " + root.selectedTemplateName()) : "No template selected"
                            }
                        }

                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: "#223244" }

                        Label { text: "Target substrate 1 [mol]" }
                        TextField {
                            id: targetSub1Field
                            Layout.fillWidth: true
                            placeholderText: "e.g. 0.0025"
                            onEditingFinished: root.refreshPlan()
                        }

                        Label { text: "Scale factor" }
                        TextField {
                            id: scalingFactorField
                            Layout.fillWidth: true
                            placeholderText: "Leave blank to derive from target substrate 1"
                            text: "1"
                            onEditingFinished: root.refreshPlan()
                        }

                        CheckBox {
                            id: solventCheck
                            text: "Scale solvent volume linearly"
                            checked: true
                            onToggled: root.refreshPlan()
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Button {
                                text: "Update plan"
                                highlighted: true
                                onClicked: root.refreshPlan()
                            }
                            Button {
                                text: "Load scaled draft into editor"
                                enabled: !!root.plan && !!root.plan.success
                                onClicked: appBridge.loadPreparationDraftIntoEditor(root.sourceKind, root.selectedTemplateId, targetSub1Field.text, scalingFactorField.text, solventCheck.checked)
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: 18
                    color: "#131b25"
                    border.color: "#223244"
                    implicitHeight: metaColumn.implicitHeight + 26

                    ColumnLayout {
                        id: metaColumn
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        Label { text: "Plan summary"; font.pixelSize: 18; font.bold: true }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: root.plan && root.plan.message ? root.plan.message : "No plan yet."
                            color: root.plan && root.plan.success ? "#9ad28b" : "#ffd166"
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 10
                            rowSpacing: 6

                            Label { text: "Source" }
                            Label { text: root.plan && root.plan.sourceLabel ? root.plan.sourceLabel : "—" }
                            Label { text: "Scale factor" }
                            Label { text: root.plan && root.plan.scalingFactor ? Number(root.plan.scalingFactor).toFixed(4) : "—" }
                            Label { text: "Target sub1" }
                            Label { text: root.plan && root.plan.targetSubstrate1Mol ? (Number(root.plan.targetSubstrate1Mol).toFixed(6) + " mol") : "—" }
                            Label { text: "Reaction type" }
                            Label { text: root.plan && root.plan.reactionType ? root.plan.reactionType : "—" }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: root.plan && root.plan.warnings && root.plan.warnings.length > 0
                    radius: 18
                    color: "#2a1f12"
                    border.color: "#69452a"
                    implicitHeight: warningColumn.implicitHeight + 26

                    ColumnLayout {
                        id: warningColumn
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 6
                        Label { text: "Warnings"; font.bold: true }
                        Repeater {
                            model: root.plan && root.plan.warnings ? root.plan.warnings : []
                            delegate: Label {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                text: "• " + modelData
                                color: "#ffd166"
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
                width: Math.max(parent.width - 20, 600)
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 10
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    radius: 18
                    color: "#131b25"
                    border.color: "#223244"
                    implicitHeight: speciesColumn.implicitHeight + 26

                    ColumnLayout {
                        id: speciesColumn
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Label { text: "Species scaling"; font.pixelSize: 20; font.bold: true }

                        Repeater {
                            model: root.plan && root.plan.species ? root.plan.species : []
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                radius: 14
                                color: "#16202b"
                                border.color: "#253445"
                                implicitHeight: speciesGrid.implicitHeight + 22

                                GridLayout {
                                    id: speciesGrid
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    columns: 4
                                    columnSpacing: 10
                                    rowSpacing: 6

                                    Label {
                                        text: (modelData.label || "Species") + (modelData.id ? (" — " + modelData.id) : "")
                                        font.bold: true
                                        Layout.columnSpan: 4
                                    }
                                    Label { text: "Stoich." }
                                    Label { text: modelData.stoichCoeff !== undefined && modelData.stoichCoeff !== null ? Number(modelData.stoichCoeff).toFixed(3) : "—" }
                                    Label { text: "Formula" }
                                    Label { text: modelData.formula || "—" }

                                    Label { text: "Source moles" }
                                    Label { text: modelData.sourceMolesText || "—" }
                                    Label { text: "Target moles" }
                                    Label { text: modelData.targetMolesText || "—" }

                                    Label { text: "Source mass" }
                                    Label { text: modelData.sourceMassText || "—" }
                                    Label { text: "Target mass" }
                                    Label { text: modelData.targetMassText || "—" }

                                    Label { text: "Source volume" }
                                    Label { text: modelData.sourceVolumeText || "—" }
                                    Label { text: "Target volume" }
                                    Label { text: modelData.targetVolumeText || "—" }

                                    Label { text: "Molar mass" }
                                    Label { text: modelData.molarMassText || "—" }
                                    Label { text: "Method" }
                                    Label { text: modelData.calcMethod || "—" }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: 18
                    color: "#131b25"
                    border.color: "#223244"
                    implicitHeight: reagentColumn.implicitHeight + 26

                    ColumnLayout {
                        id: reagentColumn
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Label { text: "Reagents"; font.pixelSize: 20; font.bold: true }
                        Repeater {
                            model: root.plan && root.plan.reagents ? root.plan.reagents : []
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                radius: 14
                                color: "#16202b"
                                border.color: "#253445"
                                implicitHeight: reagentGrid.implicitHeight + 20

                                GridLayout {
                                    id: reagentGrid
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    columns: 4
                                    columnSpacing: 10
                                    rowSpacing: 6

                                    Label {
                                        text: (modelData.class || "reagent") + (modelData.name ? (": " + modelData.name) : "")
                                        font.bold: true
                                        Layout.columnSpan: 4
                                    }
                                    Label { text: "Equiv" }
                                    Label { text: modelData.equivText || "—" }
                                    Label { text: "Target moles" }
                                    Label { text: modelData.targetMolesText || "—" }
                                    Label { text: "ID" }
                                    Label { text: modelData.id || "—" }
                                    Label { text: "Target mass" }
                                    Label { text: modelData.targetMassText || "—" }
                                }
                            }
                        }
                        Label {
                            visible: !(root.plan && root.plan.reagents && root.plan.reagents.length > 0)
                            text: "No reagent definitions stored in this source."
                            opacity: 0.72
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: 18
                    color: "#131b25"
                    border.color: "#223244"
                    implicitHeight: solventColumn.implicitHeight + 26

                    ColumnLayout {
                        id: solventColumn
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        Label { text: "Solvent and conditions"; font.pixelSize: 20; font.bold: true }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 10
                            rowSpacing: 6

                            Label { text: "Solvent" }
                            Label { text: root.plan && root.plan.solvent ? (root.plan.solvent.name || "—") : "—" }
                            Label { text: "Source solvent volume" }
                            Label { text: root.plan && root.plan.solvent ? (root.plan.solvent.sourceVolumeText || "—") : "—" }
                            Label { text: "Target solvent volume" }
                            Label { text: root.plan && root.plan.solvent ? (root.plan.solvent.targetVolumeText || "—") : "—" }
                            Label { text: "Target [Sub1]" }
                            Label { text: root.plan && root.plan.solvent ? (root.plan.solvent.targetSubstrate1ConcentrationText || "—") : "—" }
                            Label { text: "Temperature" }
                            Label { text: root.plan && root.plan.conditions && root.plan.conditions.temperatureC !== null && root.plan.conditions.temperatureC !== undefined ? (Number(root.plan.conditions.temperatureC).toFixed(1) + " °C") : "—" }
                            Label { text: "Time" }
                            Label { text: root.plan && root.plan.conditions && root.plan.conditions.timeH !== null && root.plan.conditions.timeH !== undefined ? (Number(root.plan.conditions.timeH).toFixed(2) + " h") : "—" }
                            Label { text: "Tags" }
                            Label { text: root.plan && root.plan.conditions ? (root.plan.conditions.tags || "—") : "—" }
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: root.plan && root.plan.conditions ? (root.plan.conditions.otherConditions || "") : ""
                            visible: !!text
                            opacity: 0.86
                        }
                    }
                }
            }
        }
    }
}
