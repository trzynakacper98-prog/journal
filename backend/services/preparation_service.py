from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .reaction_service import ALL_COLUMNS, MAX_REAGENTS, ReactionService, TEXT_FIELDS


@dataclass
class SourceContext:
    source_kind: str
    source_label: str
    source_payload: dict[str, Any]
    template_name: str = ""


class PreparationService:
    def __init__(self, reaction_service: ReactionService):
        self._reaction_service = reaction_service
        self._rdkit_checked = False
        self._rdkit_available = False

    def compute_plan_from_reaction(
        self,
        row_id: int,
        target_substrate1_mol: Any = None,
        scaling_factor: Any = None,
        scale_solvent: bool = True,
    ) -> dict[str, Any]:
        reaction = self._reaction_service.get_reaction_details(int(row_id))
        if not reaction:
            return {"success": False, "message": "Select a saved reaction first."}
        label = str(reaction.get("reaction_id") or f"Reaction #{row_id}")
        source = self._normalize_source(reaction)
        return self._compute_plan(
            SourceContext(source_kind="reaction", source_label=label, source_payload=source, template_name=str(source.get("template_name") or "")),
            target_substrate1_mol=target_substrate1_mol,
            scaling_factor=scaling_factor,
            scale_solvent=scale_solvent,
        )

    def compute_plan_from_template(
        self,
        template: dict[str, Any] | None,
        target_substrate1_mol: Any = None,
        scaling_factor: Any = None,
        scale_solvent: bool = True,
    ) -> dict[str, Any]:
        if not template:
            return {"success": False, "message": "Select a template first."}
        payload = template.get("payload") or {}
        source = self._normalize_source(payload)
        return self._compute_plan(
            SourceContext(
                source_kind="template",
                source_label=str(template.get("name") or "Template"),
                source_payload=source,
                template_name=str(template.get("name") or source.get("template_name") or ""),
            ),
            target_substrate1_mol=target_substrate1_mol,
            scaling_factor=scaling_factor,
            scale_solvent=scale_solvent,
        )

    def build_scaled_draft(self, plan: dict[str, Any]) -> dict[str, Any]:
        if not plan or not plan.get("success"):
            raise ValueError("Preparation plan is missing or invalid.")
        source = self._normalize_source(plan.get("sourcePayload") or {})
        draft = self._reaction_service.blank_reaction()
        for key in ALL_COLUMNS:
            if key in source:
                draft[key] = source.get(key)

        draft["id"] = None
        draft["reaction_id"] = ""
        draft["date_started"] = ""
        draft["date_finished"] = ""
        draft["yield_percent"] = None
        draft["product_notes"] = ""

        for species in plan.get("species", []):
            prefix = species.get("prefix")
            if not prefix:
                continue
            draft[f"{prefix}_moles_mol"] = self._num_or_none(species.get("targetMoles"))
            draft[f"{prefix}_mass_g"] = self._num_or_none(species.get("targetMassG"))
            draft[f"{prefix}_volume_l"] = self._num_or_none(species.get("targetVolumeL"))
            if species.get("formula"):
                draft[f"{prefix}_formula"] = str(species.get("formula") or "")

        solvent = plan.get("solvent") or {}
        if solvent.get("scaleSolvent"):
            draft["solvent_volume_l"] = self._num_or_none(solvent.get("targetVolumeL"))

        scaling_factor = self._as_float(plan.get("scalingFactor"))
        source_label = str(plan.get("sourceLabel") or "source")
        note = f"Prepared from {source_label} with scale factor {self._format_number(scaling_factor, 4)}."
        other_conditions = str(draft.get("other_conditions") or "").strip()
        draft["other_conditions"] = f"{other_conditions}\n{note}".strip()
        if plan.get("sourceKind") == "template":
            draft["template_name"] = str(plan.get("templateName") or draft.get("template_name") or source_label)
        return draft

    def _compute_plan(
        self,
        ctx: SourceContext,
        target_substrate1_mol: Any = None,
        scaling_factor: Any = None,
        scale_solvent: bool = True,
    ) -> dict[str, Any]:
        warnings: list[str] = []
        source = ctx.source_payload
        sub1_coeff = self._positive_or_default(source.get("substrate_1_stoich_coeff"), 1.0)
        source_sub1_moles = self._resolve_species_moles("substrate_1", source)
        target_sub1 = self._as_float(target_substrate1_mol)
        factor = self._as_float(scaling_factor)

        if factor is None and target_sub1 is None:
            factor = 1.0
        elif factor is None:
            if source_sub1_moles and source_sub1_moles > 0:
                factor = target_sub1 / source_sub1_moles
            else:
                return {
                    "success": False,
                    "message": "Source reaction/template is missing quantified substrate 1 data. Enter a scaling factor instead.",
                }
        elif target_sub1 is None and source_sub1_moles not in (None, 0):
            target_sub1 = source_sub1_moles * factor

        if factor is None or factor <= 0:
            return {"success": False, "message": "Scaling factor must be greater than zero."}
        if target_sub1 is not None and target_sub1 <= 0:
            return {"success": False, "message": "Target substrate 1 amount must be greater than zero."}

        species: list[dict[str, Any]] = []
        for prefix, label in (("substrate_1", "Substrate 1"), ("substrate_2", "Substrate 2"), ("product", "Product")):
            coeff = self._positive_or_default(source.get(f"{prefix}_stoich_coeff"), 1.0)
            smiles = str(source.get(f"{prefix}_smiles") or "")
            formula = str(source.get(f"{prefix}_formula") or self._formula_from_smiles(smiles) or "")
            molar_mass = self._molar_mass_from_smiles(smiles)
            source_moles = self._resolve_species_moles(prefix, source)
            target_moles = None
            calc_method = ""
            if source_moles not in (None, 0):
                target_moles = source_moles * factor
                calc_method = "scaled from stored amount"
            elif target_sub1 is not None and sub1_coeff > 0:
                target_moles = target_sub1 * coeff / sub1_coeff
                calc_method = "derived from stoichiometry"
                if prefix != "substrate_1":
                    warnings.append(f"{label}: no stored amount, using stoichiometric ratio only.")

            source_mass = self._as_float(source.get(f"{prefix}_mass_g"))
            target_mass = source_mass * factor if source_mass not in (None, 0) else None
            if target_mass is None and target_moles not in (None, 0) and molar_mass not in (None, 0):
                target_mass = target_moles * molar_mass

            source_volume = self._as_float(source.get(f"{prefix}_volume_l"))
            concentration = self._as_float(source.get(f"{prefix}_concentration_M"))
            target_volume = source_volume * factor if source_volume not in (None, 0) else None
            if target_volume is None and target_moles not in (None, 0) and concentration not in (None, 0):
                target_volume = target_moles / concentration

            species.append(
                {
                    "prefix": prefix,
                    "label": label,
                    "id": str(source.get(f"{prefix}_id") or ""),
                    "smiles": smiles,
                    "formula": formula,
                    "molarMass": molar_mass,
                    "sourceMoles": source_moles,
                    "targetMoles": target_moles,
                    "sourceMassG": source_mass,
                    "targetMassG": target_mass,
                    "sourceVolumeL": source_volume,
                    "targetVolumeL": target_volume,
                    "concentrationM": concentration,
                    "stoichCoeff": coeff,
                    "calcMethod": calc_method,
                    "sourceMolesText": self._display_amount(source_moles, "mol", 6),
                    "targetMolesText": self._display_amount(target_moles, "mol", 6),
                    "sourceMassText": self._display_amount(source_mass, "g", 6),
                    "targetMassText": self._display_amount(target_mass, "g", 6),
                    "sourceVolumeText": self._display_amount(source_volume, "L", 6),
                    "targetVolumeText": self._display_amount(target_volume, "L", 6),
                    "molarMassText": self._display_amount(molar_mass, "g/mol", 4),
                }
            )

        reagents: list[dict[str, Any]] = []
        for idx in range(1, MAX_REAGENTS + 1):
            cls = str(source.get(f"reagent_{idx}_class") or "")
            name = str(source.get(f"reagent_{idx}_name") or source.get(f"reagent_{idx}_id") or "")
            smiles = str(source.get(f"reagent_{idx}_smiles") or "")
            equiv = self._as_float(source.get(f"reagent_{idx}_equiv"))
            if not cls and not name and equiv in (None, 0) and not smiles:
                continue
            target_moles = None
            if target_sub1 not in (None, 0) and equiv not in (None, 0) and sub1_coeff > 0:
                target_moles = target_sub1 * equiv / sub1_coeff
            elif source_sub1_moles not in (None, 0) and equiv not in (None, 0) and sub1_coeff > 0:
                target_moles = source_sub1_moles * factor * equiv / sub1_coeff
            molar_mass = self._molar_mass_from_smiles(smiles)
            target_mass = target_moles * molar_mass if target_moles not in (None, 0) and molar_mass not in (None, 0) else None
            reagents.append(
                {
                    "index": idx,
                    "class": cls,
                    "name": name,
                    "id": str(source.get(f"reagent_{idx}_id") or ""),
                    "equiv": equiv,
                    "smiles": smiles,
                    "molarMass": molar_mass,
                    "targetMoles": target_moles,
                    "targetMassG": target_mass,
                    "targetMolesText": self._display_amount(target_moles, "mol", 6),
                    "targetMassText": self._display_amount(target_mass, "g", 6),
                    "equivText": self._display_amount(equiv, "equiv", 4),
                }
            )

        solvent_name = str(source.get("solvent_name") or "")
        source_solvent_volume = self._as_float(source.get("solvent_volume_l"))
        target_solvent_volume = source_solvent_volume * factor if scale_solvent and source_solvent_volume not in (None, 0) else source_solvent_volume
        if scale_solvent and source_solvent_volume in (None, 0):
            warnings.append("No stored solvent volume found, so solvent was not scaled.")

        target_sub1_concentration = None
        if target_sub1 not in (None, 0) and target_solvent_volume not in (None, 0):
            target_sub1_concentration = target_sub1 / target_solvent_volume

        message = "Preparation plan ready."
        if warnings:
            message += " " + " ".join(warnings[:3])

        return {
            "success": True,
            "message": message,
            "sourceKind": ctx.source_kind,
            "sourceLabel": ctx.source_label,
            "sourcePayload": source,
            "templateName": ctx.template_name,
            "reactionType": str(source.get("reaction_type") or ""),
            "scalingFactor": factor,
            "targetSubstrate1Mol": target_sub1,
            "sourceSubstrate1Mol": source_sub1_moles,
            "scaleSolvent": bool(scale_solvent),
            "species": species,
            "reagents": reagents,
            "warnings": warnings,
            "solvent": {
                "name": solvent_name,
                "sourceVolumeL": source_solvent_volume,
                "targetVolumeL": target_solvent_volume,
                "sourceVolumeText": self._display_amount(source_solvent_volume, "L", 6),
                "targetVolumeText": self._display_amount(target_solvent_volume, "L", 6),
                "scaleSolvent": bool(scale_solvent),
                "targetSubstrate1ConcentrationM": target_sub1_concentration,
                "targetSubstrate1ConcentrationText": self._display_amount(target_sub1_concentration, "M", 6),
            },
            "conditions": {
                "temperatureC": self._as_float(source.get("temperature_c")),
                "timeH": self._as_float(source.get("time_h")),
                "otherConditions": str(source.get("other_conditions") or ""),
                "workUp": str(source.get("work_up") or ""),
                "tags": str(source.get("tags") or ""),
            },
        }

    def _normalize_source(self, data: dict[str, Any]) -> dict[str, Any]:
        source = self._reaction_service.blank_reaction()
        for key in ALL_COLUMNS:
            if key in data:
                source[key] = data.get(key)
        return source

    def _resolve_species_moles(self, prefix: str, data: dict[str, Any]) -> float | None:
        direct = self._as_float(data.get(f"{prefix}_moles_mol"))
        if direct not in (None, 0):
            return direct
        volume = self._as_float(data.get(f"{prefix}_volume_l"))
        concentration = self._as_float(data.get(f"{prefix}_concentration_M"))
        if volume not in (None, 0) and concentration not in (None, 0):
            return volume * concentration
        mass = self._as_float(data.get(f"{prefix}_mass_g"))
        smiles = str(data.get(f"{prefix}_smiles") or "")
        molar_mass = self._molar_mass_from_smiles(smiles)
        if mass not in (None, 0) and molar_mass not in (None, 0):
            return mass / molar_mass
        return None

    def _molar_mass_from_smiles(self, smiles: str | None) -> float | None:
        cleaned = str(smiles or "").strip()
        if not cleaned:
            return None
        try:
            from rdkit import Chem
            from rdkit.Chem import Descriptors
        except Exception:
            return None
        mol = Chem.MolFromSmiles(cleaned)
        if mol is None:
            return None
        try:
            return float(Descriptors.MolWt(mol))
        except Exception:
            return None

    def _formula_from_smiles(self, smiles: str | None) -> str:
        cleaned = str(smiles or "").strip()
        if not cleaned:
            return ""
        try:
            from rdkit import Chem
            from rdkit.Chem import rdMolDescriptors
        except Exception:
            return ""
        mol = Chem.MolFromSmiles(cleaned)
        if mol is None:
            return ""
        try:
            return str(rdMolDescriptors.CalcMolFormula(mol))
        except Exception:
            return ""

    @staticmethod
    def _positive_or_default(value: Any, default: float) -> float:
        numeric = PreparationService._as_float(value)
        if numeric is None or numeric <= 0:
            return float(default)
        return float(numeric)

    @staticmethod
    def _as_float(value: Any) -> float | None:
        if value in (None, ""):
            return None
        try:
            return float(value)
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _num_or_none(value: Any) -> float | None:
        if value in (None, ""):
            return None
        try:
            return float(value)
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _format_number(value: Any, precision: int = 6) -> str:
        if value in (None, ""):
            return ""
        try:
            return f"{float(value):.{precision}f}".rstrip("0").rstrip(".")
        except Exception:
            return str(value)

    @staticmethod
    def _display_amount(value: Any, unit: str, precision: int = 6) -> str:
        if value in (None, ""):
            return "—"
        formatted = PreparationService._format_number(value, precision)
        return f"{formatted} {unit}".strip()
