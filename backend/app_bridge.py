from __future__ import annotations

from typing import Any

from PySide6.QtCore import Property, QObject, Signal, Slot
from PySide6.QtGui import QGuiApplication

from .models import ReactionListModel
from .services.chem_service import ChemService
from .services.preparation_service import PreparationService
from .services.pubchem_service import PubChemService
from .services.reaction_service import ReactionService


class AppBridge(QObject):
    selectedReactionChanged = Signal()
    selectedRowChanged = Signal()
    currentPageChanged = Signal()
    statsChanged = Signal()
    statusTextChanged = Signal()
    capabilitiesChanged = Signal()
    templatesChanged = Signal()
    editorDraftChanged = Signal()
    journalTabRequested = Signal(int)
    filtersChanged = Signal()
    availableFiltersChanged = Signal()

    def __init__(
        self,
        reaction_service: ReactionService,
        reaction_model: ReactionListModel,
        chem_service: ChemService,
        pubchem_service: PubChemService,
    ):
        super().__init__()
        self._reaction_service = reaction_service
        self._reaction_model = reaction_model
        self._chem_service = chem_service
        self._pubchem_service = pubchem_service
        self._preparation_service = PreparationService(reaction_service)
        self._selected_reaction: dict[str, Any] = {}
        self._selected_row = -1
        self._current_page = "journal"
        self._status_text = "Ready"
        self._stats: dict[str, Any] = {"count": 0, "templateCount": 0, "db_path": str(reaction_service.db.db_path)}
        self._templates: list[dict[str, Any]] = []
        self._editor_draft: dict[str, Any] = reaction_service.blank_reaction()
        self._search_query = ""
        self._active_tag = ""
        self._reaction_type_filter = ""
        self._template_filter = ""
        self._available_tags: list[dict[str, Any]] = []
        self._available_reaction_types: list[str] = []
        self._available_template_names: list[str] = []
        self._capabilities = {
            "rdkitAvailable": chem_service.rdkit_available,
            "rdkitStatus": chem_service.rdkit_status,
            "rdeditorAvailable": chem_service.rdeditor_available,
            "rdeditorStatus": chem_service.rdeditor_status,
            "pubchemStatus": "PubChem online lookup enabled",
            "dbPath": str(reaction_service.db.db_path),
        }

    def bootstrap(self) -> None:
        self._refresh_reactions_from_state(preserve_selection=False)
        self.refreshTemplates()
        if self._reaction_model.rowCount() > 0:
            self.selectReaction(0)
        self._stats = self._reaction_service.stats()
        self.statsChanged.emit()
        self.capabilitiesChanged.emit()

    @Property("QVariantMap", notify=selectedReactionChanged)
    def selectedReaction(self) -> dict[str, Any]:
        return self._selected_reaction

    @Property(int, notify=selectedRowChanged)
    def selectedRow(self) -> int:
        return self._selected_row

    @Property(str, notify=currentPageChanged)
    def currentPage(self) -> str:
        return self._current_page

    @Property("QVariantMap", notify=statsChanged)
    def stats(self) -> dict[str, Any]:
        return self._stats

    @Property(str, notify=statusTextChanged)
    def statusText(self) -> str:
        return self._status_text

    @Property("QVariantMap", notify=capabilitiesChanged)
    def capabilities(self) -> dict[str, Any]:
        return self._capabilities

    @Property("QVariantList", notify=templatesChanged)
    def templates(self) -> list[dict[str, Any]]:
        return self._templates

    @Property("QVariantMap", notify=editorDraftChanged)
    def editorDraft(self) -> dict[str, Any]:
        return self._editor_draft

    @Property(str, notify=filtersChanged)
    def searchQuery(self) -> str:
        return self._search_query

    @Property(str, notify=filtersChanged)
    def activeTag(self) -> str:
        return self._active_tag

    @Property(str, notify=filtersChanged)
    def reactionTypeFilter(self) -> str:
        return self._reaction_type_filter

    @Property(str, notify=filtersChanged)
    def templateFilter(self) -> str:
        return self._template_filter

    @Property("QVariantList", notify=availableFiltersChanged)
    def availableTags(self) -> list[dict[str, Any]]:
        return self._available_tags

    @Property("QVariantList", notify=availableFiltersChanged)
    def availableReactionTypes(self) -> list[str]:
        return self._available_reaction_types

    @Property("QVariantList", notify=availableFiltersChanged)
    def availableTemplateNames(self) -> list[str]:
        return self._available_template_names

    @Slot(str)
    def setCurrentPage(self, page_name: str) -> None:
        if page_name != self._current_page:
            self._current_page = page_name
            self.currentPageChanged.emit()
            self._set_status(f"Page: {page_name}")

    @Slot(str)
    def setSearchQuery(self, query: str) -> None:
        query = str(query or "")
        if query != self._search_query:
            self._search_query = query
            self.filtersChanged.emit()
        self._refresh_reactions_from_state(preserve_selection=True)

    @Slot(str)
    def setActiveTag(self, tag: str) -> None:
        tag = str(tag or "")
        if tag != self._active_tag:
            self._active_tag = tag
            self.filtersChanged.emit()
        self._refresh_reactions_from_state(preserve_selection=True)

    @Slot(str)
    def setReactionTypeFilter(self, reaction_type: str) -> None:
        reaction_type = str(reaction_type or "")
        if reaction_type != self._reaction_type_filter:
            self._reaction_type_filter = reaction_type
            self.filtersChanged.emit()
        self._refresh_reactions_from_state(preserve_selection=True)

    @Slot(str)
    def setTemplateFilter(self, template_name: str) -> None:
        template_name = str(template_name or "")
        if template_name != self._template_filter:
            self._template_filter = template_name
            self.filtersChanged.emit()
        self._refresh_reactions_from_state(preserve_selection=True)

    @Slot()
    def clearFilters(self) -> None:
        self._search_query = ""
        self._active_tag = ""
        self._reaction_type_filter = ""
        self._template_filter = ""
        self.filtersChanged.emit()
        self._refresh_reactions_from_state(preserve_selection=False)

    @Slot(str)
    def refresh_reactions(self, query: str = "") -> None:
        if str(query or "") != self._search_query:
            self._search_query = str(query or "")
            self.filtersChanged.emit()
        self._refresh_reactions_from_state(preserve_selection=True)

    @Slot()
    def refreshTemplates(self) -> None:
        self._templates = self._reaction_service.list_templates()
        self.templatesChanged.emit()
        self._stats = self._reaction_service.stats()
        self.statsChanged.emit()

    @Slot(int)
    def selectReaction(self, row: int) -> None:
        item = self._reaction_model.item(row)
        if not item:
            self._selected_reaction = {}
            self._selected_row = -1
            self.selectedReactionChanged.emit()
            self.selectedRowChanged.emit()
            return

        row_id = item.get("id")
        if row_id is None:
            return

        self._selected_row = row
        self.selectedRowChanged.emit()
        self._load_selected_reaction(int(row_id))

    @Slot(result="QVariantMap")
    def blankReactionDraft(self) -> dict[str, Any]:
        draft = self._reaction_service.blank_reaction()
        self._editor_draft = draft
        self.editorDraftChanged.emit()
        return draft

    @Slot()
    def startBlankDraftInEditor(self) -> None:
        self._editor_draft = self._reaction_service.blank_reaction()
        self.editorDraftChanged.emit()
        self.setCurrentPage("journal")
        self.journalTabRequested.emit(1)
        self._set_status("Started a blank reaction draft")

    @Slot("QVariantMap", result=bool)
    def saveReaction(self, payload: dict[str, Any]) -> bool:
        try:
            row_id = self._reaction_service.save_reaction(payload)
        except Exception as exc:
            self._set_status(f"Save failed: {exc}")
            return False
        self._refresh_reactions_from_state(preserve_selection=False)
        self._selected_row = self._reaction_model.row_for_db_id(int(row_id))
        self.selectedRowChanged.emit()
        self._load_selected_reaction(int(row_id))
        self._editor_draft = dict(self._selected_reaction)
        self.editorDraftChanged.emit()
        reaction_id = self._selected_reaction.get("reaction_id") or "(no id)"
        self._set_status(f"Saved: {reaction_id}")
        return True

    @Slot(result=bool)
    def deleteSelectedReaction(self) -> bool:
        row_id = self._selected_reaction.get("id")
        if row_id in (None, ""):
            self._set_status("Delete failed: no selected reaction")
            return False
        try:
            deleted = self._reaction_service.delete_reaction(int(row_id))
        except Exception as exc:
            self._set_status(f"Delete failed: {exc}")
            return False
        if not deleted:
            self._set_status("Delete failed: reaction not found")
            return False
        self._refresh_reactions_from_state(preserve_selection=False)
        if self._reaction_model.rowCount() > 0:
            self.selectReaction(0)
        else:
            self._selected_reaction = {}
            self._selected_row = -1
            self.selectedReactionChanged.emit()
            self.selectedRowChanged.emit()
            self._editor_draft = self._reaction_service.blank_reaction()
            self.editorDraftChanged.emit()
        self._set_status("Reaction deleted")
        return True

    @Slot(result=bool)
    def duplicateSelectedReaction(self) -> bool:
        row_id = self._selected_reaction.get("id")
        if row_id in (None, ""):
            self._set_status("Duplicate failed: no selected reaction")
            return False
        try:
            new_row_id = self._reaction_service.duplicate_reaction(int(row_id))
        except Exception as exc:
            self._set_status(f"Duplicate failed: {exc}")
            return False
        self._refresh_reactions_from_state(preserve_selection=False)
        self._selected_row = self._reaction_model.row_for_db_id(int(new_row_id))
        self.selectedRowChanged.emit()
        self._load_selected_reaction(int(new_row_id))
        reaction_id = self._selected_reaction.get("reaction_id") or "(no id)"
        self._set_status(f"Duplicated: {reaction_id}")
        return True

    @Slot(str, str, result=bool)
    def createTemplateFromSelectedReaction(self, name: str, description: str) -> bool:
        row_id = self._selected_reaction.get("id")
        if row_id in (None, ""):
            self._set_status("Template failed: select a saved reaction first")
            return False
        try:
            template_id = self._reaction_service.create_template_from_reaction(int(row_id), name, description)
        except Exception as exc:
            self._set_status(f"Template failed: {exc}")
            return False
        self.refreshTemplates()
        template = self._reaction_service.get_template(int(template_id))
        template_name = template.get("name") if template else name
        self._set_status(f"Template saved: {template_name}")
        return True

    @Slot(int, result=bool)
    def applyTemplateToEditor(self, template_id: int) -> bool:
        try:
            draft = self._reaction_service.instantiate_template(int(template_id))
        except Exception as exc:
            self._set_status(f"Template apply failed: {exc}")
            return False
        self._editor_draft = draft
        self.editorDraftChanged.emit()
        self.setCurrentPage("journal")
        self.journalTabRequested.emit(1)
        self._set_status(f"Loaded template into editor: {draft.get('template_name') or '(template)'}")
        return True

    @Slot(int, result=bool)
    def deleteTemplate(self, template_id: int) -> bool:
        try:
            deleted = self._reaction_service.delete_template(int(template_id))
        except Exception as exc:
            self._set_status(f"Delete template failed: {exc}")
            return False
        if not deleted:
            self._set_status("Delete template failed: template not found")
            return False
        self.refreshTemplates()
        self._set_status("Template deleted")
        return True

    @Slot(str, result="QVariantMap")
    def analyzeSmiles(self, smiles: str) -> dict[str, Any]:
        result = self._chem_service.analyze_smiles(smiles, title="SMILES Generator")
        self._set_status(result.get("message") or "SMILES analyzed")
        return result

    @Slot(str, str, result="QVariantMap")
    def analyzeSmilesNamed(self, smiles: str, title: str) -> dict[str, Any]:
        result = self._chem_service.analyze_smiles(smiles, title=title or "Molecule")
        self._set_status(result.get("message") or "SMILES analyzed")
        return result

    @Slot(str, str, result="QVariantMap")
    def enrichFromSmilesNamed(self, smiles: str, title: str) -> dict[str, Any]:
        analyzed = self._chem_service.analyze_smiles(smiles, title=title or "Molecule")
        if not analyzed.get("success"):
            self._set_status(analyzed.get("message") or "SMILES analysis failed")
            return analyzed
        query_smiles = str(analyzed.get("canonicalSmiles") or smiles or "")
        try:
            payload = self._pubchem_service.lookup_by_smiles(query_smiles)
        except Exception as exc:
            analyzed = dict(analyzed)
            analyzed["message"] = f"{analyzed.get('message') or 'RDKit analysis complete.'} PubChem metadata unavailable: {exc}"
            self._set_status(analyzed.get("message") or "RDKit analysis complete")
            return analyzed
        merged = self._merge_pubchem_payload(payload, title=title)
        if not merged.get("canonicalSmiles"):
            merged["canonicalSmiles"] = query_smiles
        self._set_status(merged.get("message") or "PubChem enrichment complete")
        return merged

    @Slot(result="QVariantMap")
    def drawSmilesInEditor(self) -> dict[str, Any]:
        result = self._chem_service.open_in_rdeditor(None, title="SMILES Generator")
        self._set_status(result.get("message") or "rdEditor finished")
        self.capabilitiesChanged.emit()
        return result

    @Slot(str, result="QVariantMap")
    def drawSmilesInEditorNamed(self, title: str) -> dict[str, Any]:
        result = self._chem_service.open_in_rdeditor(None, title=title or "Molecule")
        self._set_status(result.get("message") or "rdEditor finished")
        self.capabilitiesChanged.emit()
        return result

    @Slot(str, result="QVariantMap")
    def editSmilesInEditor(self, smiles: str) -> dict[str, Any]:
        result = self._chem_service.open_in_rdeditor(smiles, title="SMILES Generator")
        self._set_status(result.get("message") or "rdEditor finished")
        self.capabilitiesChanged.emit()
        return result

    @Slot(str, str, result="QVariantMap")
    def editSmilesInEditorNamed(self, smiles: str, title: str) -> dict[str, Any]:
        result = self._chem_service.open_in_rdeditor(smiles, title=title or "Molecule")
        self._set_status(result.get("message") or "rdEditor finished")
        self.capabilitiesChanged.emit()
        return result

    @Slot(str, result="QVariantMap")
    def lookupPubChemBySmiles(self, smiles: str) -> dict[str, Any]:
        return self.lookupPubChemBySmilesNamed(smiles, "SMILES Generator")

    @Slot(str, str, result="QVariantMap")
    def lookupPubChemBySmilesNamed(self, smiles: str, title: str) -> dict[str, Any]:
        try:
            payload = self._pubchem_service.lookup_by_smiles(smiles)
        except Exception as exc:
            self._set_status(f"PubChem lookup failed: {exc}")
            return {
                "success": False,
                "inputSmiles": str(smiles or ""),
                "canonicalSmiles": str(smiles or ""),
                "formula": "",
                "molarMass": "",
                "inchiKey": "",
                "iupacName": "",
                "cid": "",
                "casNumber": "",
                "synonyms": [],
                "svgDataUri": self._chem_service.smiles_to_svg_data_uri(smiles or "", title=title or "Molecule"),
                "message": str(exc),
            }
        merged = self._merge_pubchem_payload(payload, title=title)
        self._set_status(merged.get("message") or "PubChem lookup complete")
        return merged

    @Slot(str, result="QVariantMap")
    def lookupPubChemByName(self, query: str) -> dict[str, Any]:
        return self.lookupPubChemByNameNamed(query, "SMILES Generator")

    @Slot(str, str, result="QVariantMap")
    def lookupPubChemByNameNamed(self, query: str, title: str) -> dict[str, Any]:
        try:
            payload = self._pubchem_service.lookup_by_name(query)
        except Exception as exc:
            self._set_status(f"PubChem lookup failed: {exc}")
            return {
                "success": False,
                "inputSmiles": "",
                "canonicalSmiles": "",
                "formula": "",
                "molarMass": "",
                "inchiKey": "",
                "iupacName": "",
                "cid": "",
                "casNumber": "",
                "synonyms": [],
                "svgDataUri": self._chem_service.smiles_to_svg_data_uri("", title=title or "Molecule"),
                "message": str(exc),
            }
        merged = self._merge_pubchem_payload(payload, title=title)
        self._set_status(merged.get("message") or "PubChem lookup complete")
        return merged

    @Slot(str, result="QVariantMap")
    def lookupPubChemByCas(self, cas_number: str) -> dict[str, Any]:
        return self.lookupPubChemByCasNamed(cas_number, "SMILES Generator")

    @Slot(str, str, result="QVariantMap")
    def lookupPubChemByCasNamed(self, cas_number: str, title: str) -> dict[str, Any]:
        try:
            payload = self._pubchem_service.lookup_by_cas(cas_number)
        except Exception as exc:
            self._set_status(f"PubChem lookup failed: {exc}")
            return {
                "success": False,
                "inputSmiles": "",
                "canonicalSmiles": "",
                "formula": "",
                "molarMass": "",
                "inchiKey": "",
                "iupacName": "",
                "cid": "",
                "casNumber": str(cas_number or ""),
                "synonyms": [],
                "svgDataUri": self._chem_service.smiles_to_svg_data_uri("", title=title or "Molecule"),
                "message": str(exc),
            }
        merged = self._merge_pubchem_payload(payload, title=title)
        if not merged.get("casNumber"):
            merged["casNumber"] = str(cas_number or "")
        self._set_status(merged.get("message") or "PubChem lookup complete")
        return merged

    @Slot(str, int, str, str, bool, result="QVariantMap")
    def computePreparationPlan(self, source_kind: str, template_id: int, target_substrate1_mol: str, scaling_factor: str, scale_solvent: bool) -> dict[str, Any]:
        try:
            if source_kind == "template":
                template = self._reaction_service.get_template(int(template_id)) if int(template_id) > 0 else None
                plan = self._preparation_service.compute_plan_from_template(
                    template,
                    target_substrate1_mol=target_substrate1_mol,
                    scaling_factor=scaling_factor,
                    scale_solvent=scale_solvent,
                )
            else:
                row_id = self._selected_reaction.get("id")
                if row_id in (None, ""):
                    plan = {"success": False, "message": "Select a saved reaction first."}
                else:
                    plan = self._preparation_service.compute_plan_from_reaction(
                        int(row_id),
                        target_substrate1_mol=target_substrate1_mol,
                        scaling_factor=scaling_factor,
                        scale_solvent=scale_solvent,
                    )
        except Exception as exc:
            plan = {"success": False, "message": f"Preparation failed: {exc}"}
        self._set_status(str(plan.get("message") or "Preparation updated"))
        return plan

    @Slot(str, int, str, str, bool, result=bool)
    def loadPreparationDraftIntoEditor(self, source_kind: str, template_id: int, target_substrate1_mol: str, scaling_factor: str, scale_solvent: bool) -> bool:
        plan = self.computePreparationPlan(source_kind, template_id, target_substrate1_mol, scaling_factor, scale_solvent)
        if not plan.get("success"):
            return False
        try:
            draft = self._preparation_service.build_scaled_draft(plan)
        except Exception as exc:
            self._set_status(f"Cannot load scaled draft: {exc}")
            return False
        self._editor_draft = draft
        self.editorDraftChanged.emit()
        self.setCurrentPage("journal")
        self.journalTabRequested.emit(1)
        self._set_status(f"Loaded scaled draft from {plan.get('sourceLabel') or 'source'}")
        return True

    @Slot(str)
    def copyText(self, text: str) -> None:
        clipboard = QGuiApplication.clipboard()
        clipboard.setText(text or "")
        self._set_status("Copied to clipboard")

    def _refresh_reactions_from_state(self, preserve_selection: bool = True) -> None:
        selected_id = self._selected_reaction.get("id") if preserve_selection else None
        self._reaction_model.refresh(
            query=self._search_query,
            tag=self._active_tag,
            reaction_type=self._reaction_type_filter,
            template_name=self._template_filter,
        )
        self._refresh_filter_options()
        self._stats = self._reaction_service.stats()
        self.statsChanged.emit()
        self._set_status(f"Loaded {self._stats.get('count', 0)} reactions")
        if selected_id not in (None, ""):
            row = self._reaction_model.row_for_db_id(int(selected_id))
            if row >= 0:
                self._selected_row = row
                self.selectedRowChanged.emit()
                self._load_selected_reaction(int(selected_id))
                return
        if self._reaction_model.rowCount() > 0:
            self._selected_row = 0
            self.selectedRowChanged.emit()
            first_item = self._reaction_model.item(0) or {}
            first_id = first_item.get("id")
            if first_id not in (None, ""):
                self._load_selected_reaction(int(first_id))
            return
        self._selected_row = -1
        self.selectedRowChanged.emit()
        self._selected_reaction = {}
        self.selectedReactionChanged.emit()

    def _refresh_filter_options(self) -> None:
        self._available_tags = self._reaction_service.list_available_tags()
        self._available_reaction_types = self._reaction_service.list_available_reaction_types()
        self._available_template_names = self._reaction_service.list_available_template_names()
        self.availableFiltersChanged.emit()

    def _merge_pubchem_payload(self, payload: dict[str, Any], title: str) -> dict[str, Any]:
        canonical = str(payload.get("canonicalSmiles") or payload.get("isomericSmiles") or "")
        analyzed = self._chem_service.analyze_smiles(canonical, title=title or "Molecule")
        result = dict(analyzed)
        result.update(
            {
                "success": bool(payload.get("success", True)),
                "cid": str(payload.get("cid") or ""),
                "iupacName": str(payload.get("iupacName") or ""),
                "casNumber": str(payload.get("casNumber") or ""),
                "synonyms": payload.get("synonyms") or [],
                "canonicalSmiles": canonical or result.get("canonicalSmiles") or "",
                "propertySource": "RDKit + PubChem metadata",
            }
        )
        if payload.get("formula"):
            result["formula"] = payload.get("formula")
        if payload.get("molarMass"):
            result["molarMass"] = payload.get("molarMass")
        if payload.get("inchiKey"):
            result["inchiKey"] = payload.get("inchiKey")
        result["message"] = str(payload.get("message") or result.get("message") or "PubChem lookup complete")
        return result

    def _load_selected_reaction(self, row_id: int) -> None:
        details = self._reaction_service.get_reaction_details(row_id)
        self._selected_reaction = self._chem_service.enrich_reaction(details)
        self.selectedReactionChanged.emit()

    def _set_status(self, text: str) -> None:
        if text != self._status_text:
            self._status_text = text
            self.statusTextChanged.emit()
