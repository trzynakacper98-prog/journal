from __future__ import annotations

import base64
import html
import shutil
import subprocess
import tempfile
import textwrap
from pathlib import Path
from typing import Any


class ChemService:
    def __init__(self) -> None:
        self._rdkit_error: str | None = None
        self._rdkit_checked = False
        self._rdeditor_error: str | None = None
        self._rdeditor_checked = False
        self._rdeditor_path: str | None = None

    @property
    def rdkit_available(self) -> bool:
        if not self._rdkit_checked:
            self._check_rdkit()
        return self._rdkit_error is None

    @property
    def rdkit_status(self) -> str:
        if self.rdkit_available:
            return "RDKit available"
        return self._rdkit_error or "RDKit unavailable"

    @property
    def rdeditor_available(self) -> bool:
        if not self._rdeditor_checked:
            self._check_rdeditor()
        return self._rdeditor_error is None

    @property
    def rdeditor_status(self) -> str:
        if self.rdeditor_available:
            return "rdEditor available"
        return self._rdeditor_error or "rdEditor unavailable"

    def _check_rdkit(self) -> None:
        if self._rdkit_checked:
            return
        self._rdkit_checked = True
        try:
            import rdkit  # noqa: F401
            self._rdkit_error = None
        except Exception as exc:  # pragma: no cover - depends on local env
            self._rdkit_error = f"RDKit not available: {exc}"

    def _check_rdeditor(self) -> None:
        if self._rdeditor_checked:
            return
        self._rdeditor_checked = True
        self._rdeditor_path = shutil.which("rdEditor") or shutil.which("rdeditor")
        if self._rdeditor_path:
            self._rdeditor_error = None
        else:  # pragma: no cover - depends on local env
            self._rdeditor_error = "rdEditor not found. Install with: pip install rdeditor"

    def smiles_to_svg_data_uri(self, smiles: str | None, title: str = "", width: int = 420, height: int = 280) -> str:
        svg = self.smiles_to_svg(smiles=smiles, title=title, width=width, height=height)
        return self.svg_to_data_uri(svg)

    def smiles_to_svg(self, smiles: str | None, title: str = "", width: int = 420, height: int = 280) -> str:
        smiles = (smiles or "").strip()
        if not smiles:
            return self._placeholder_svg(title or "No structure", "No SMILES")

        try:
            from rdkit import Chem
            from rdkit.Chem import rdDepictor
            from rdkit.Chem.Draw import rdMolDraw2D
        except Exception as exc:  # pragma: no cover - depends on local env
            self._rdkit_error = f"RDKit not available: {exc}"
            return self._placeholder_svg(title or "RDKit missing", "Install RDKit to render structures")

        mol = Chem.MolFromSmiles(smiles)
        if mol is None:
            return self._placeholder_svg(title or "Invalid structure", f"Cannot parse SMILES: {smiles}")

        try:
            rdDepictor.Compute2DCoords(mol)
            drawer = rdMolDraw2D.MolDraw2DSVG(width, height)
            options = drawer.drawOptions()
            options.legendFontSize = 18
            options.padding = 0.06
            options.fixedBondLength = 32.0
            options.clearBackground = False
            drawer.DrawMolecule(mol, legend=title or "")
            drawer.FinishDrawing()
            svg = drawer.GetDrawingText()
            return svg if svg else self._placeholder_svg(title or "No structure", smiles)
        except Exception as exc:  # pragma: no cover - depends on local env
            return self._placeholder_svg(title or "Render error", str(exc))

    @staticmethod
    def svg_to_data_uri(svg: str) -> str:
        encoded = base64.b64encode(svg.encode("utf-8")).decode("ascii")
        return f"data:image/svg+xml;base64,{encoded}"

    def analyze_smiles(self, smiles: str | None, title: str = "Molecule", width: int = 520, height: int = 360) -> dict[str, Any]:
        cleaned = (smiles or "").strip()
        if not cleaned:
            return {
                "success": False,
                "inputSmiles": "",
                "canonicalSmiles": "",
                "formula": "",
                "molarMass": "",
                "inchiKey": "",
                "casNumber": "",
                "svgDataUri": self.smiles_to_svg_data_uri("", title=title, width=width, height=height),
                "message": "Enter a SMILES string to preview a molecule.",
            }

        try:
            from rdkit import Chem
            from rdkit.Chem import Crippen, Descriptors, Lipinski, rdMolDescriptors
        except Exception as exc:  # pragma: no cover - depends on local env
            self._rdkit_error = f"RDKit not available: {exc}"
            return {
                "success": False,
                "inputSmiles": cleaned,
                "canonicalSmiles": cleaned,
                "formula": "",
                "molarMass": "",
                "exactMass": "",
                "inchiKey": "",
                "casNumber": "",
                "atomCount": "",
                "heavyAtomCount": "",
                "ringCount": "",
                "rotatableBonds": "",
                "hBondDonors": "",
                "hBondAcceptors": "",
                "tpsa": "",
                "logP": "",
                "formalCharge": "",
                "svgDataUri": self.smiles_to_svg_data_uri(cleaned, title=title, width=width, height=height),
                "message": self.rdkit_status,
                "propertySource": "RDKit unavailable",
            }

        mol = Chem.MolFromSmiles(cleaned)
        if mol is None:
            return {
                "success": False,
                "inputSmiles": cleaned,
                "canonicalSmiles": cleaned,
                "formula": "",
                "molarMass": "",
                "exactMass": "",
                "inchiKey": "",
                "casNumber": "",
                "atomCount": "",
                "heavyAtomCount": "",
                "ringCount": "",
                "rotatableBonds": "",
                "hBondDonors": "",
                "hBondAcceptors": "",
                "tpsa": "",
                "logP": "",
                "formalCharge": "",
                "svgDataUri": self.smiles_to_svg_data_uri(cleaned, title=title, width=width, height=height),
                "message": "Invalid SMILES. RDKit could not parse this structure.",
                "propertySource": "Invalid SMILES",
            }

        canonical = Chem.MolToSmiles(mol)
        formula = rdMolDescriptors.CalcMolFormula(mol)
        molar_mass = Descriptors.MolWt(mol)
        exact_mass = rdMolDescriptors.CalcExactMolWt(mol)
        atom_count = mol.GetNumAtoms()
        heavy_atom_count = rdMolDescriptors.CalcNumHeavyAtoms(mol)
        ring_count = rdMolDescriptors.CalcNumRings(mol)
        rotatable_bonds = Lipinski.NumRotatableBonds(mol)
        h_bond_donors = Lipinski.NumHDonors(mol)
        h_bond_acceptors = Lipinski.NumHAcceptors(mol)
        tpsa = rdMolDescriptors.CalcTPSA(mol)
        log_p = Crippen.MolLogP(mol)
        formal_charge = Chem.GetFormalCharge(mol)
        try:
            inchi_key = Chem.MolToInchiKey(mol)
        except Exception:
            inchi_key = ""

        return {
            "success": True,
            "inputSmiles": cleaned,
            "canonicalSmiles": canonical,
            "formula": formula,
            "molarMass": f"{molar_mass:.4f}",
            "exactMass": f"{exact_mass:.4f}",
            "casNumber": "",
            "inchiKey": inchi_key,
            "atomCount": str(atom_count),
            "heavyAtomCount": str(heavy_atom_count),
            "ringCount": str(ring_count),
            "rotatableBonds": str(rotatable_bonds),
            "hBondDonors": str(h_bond_donors),
            "hBondAcceptors": str(h_bond_acceptors),
            "tpsa": f"{tpsa:.2f}",
            "logP": f"{log_p:.2f}",
            "formalCharge": str(formal_charge),
            "svgDataUri": self.smiles_to_svg_data_uri(canonical, title=title, width=width, height=height),
            "message": "Structure parsed successfully. Basic properties calculated with RDKit.",
            "propertySource": "Calculated with RDKit",
        }

    def open_in_rdeditor(self, start_smiles: str | None = None, title: str = "Molecule") -> dict[str, Any]:
        try:
            smiles = self._run_rdeditor(start_smiles=start_smiles)
        except Exception as exc:
            fallback_smiles = (start_smiles or "").strip()
            return {
                "success": False,
                "inputSmiles": fallback_smiles,
                "canonicalSmiles": fallback_smiles,
                "formula": "",
                "molarMass": "",
                "inchiKey": "",
                "casNumber": "",
                "svgDataUri": self.smiles_to_svg_data_uri(fallback_smiles, title=title),
                "message": str(exc),
            }

        result = self.analyze_smiles(smiles, title=title)
        result["message"] = "Structure loaded from rdEditor."
        return result

    def _run_rdeditor(self, start_smiles: str | None = None) -> str:
        self._check_rdeditor()
        if not self._rdeditor_path:
            raise RuntimeError(self._rdeditor_error or "rdEditor not found")

        try:
            from rdkit import Chem
        except Exception as exc:  # pragma: no cover - depends on local env
            raise RuntimeError(f"RDKit is required for rdEditor integration: {exc}") from exc

        with tempfile.TemporaryDirectory() as tmpdir:
            mol_path = Path(tmpdir) / "edited_structure.mol"
            if (start_smiles or "").strip():
                mol = Chem.MolFromSmiles(str(start_smiles).strip())
                if mol is None:
                    raise RuntimeError("Cannot open the provided SMILES in rdEditor.")
                Chem.MolToMolFile(mol, str(mol_path))
            else:
                empty_mol = Chem.RWMol()
                Chem.MolToMolFile(empty_mol, str(mol_path))

            result = subprocess.run([self._rdeditor_path, str(mol_path)])
            if result.returncode != 0:
                raise RuntimeError("rdEditor exited with an error.")
            if not mol_path.exists() or mol_path.stat().st_size == 0:
                raise RuntimeError("No MOL file was saved by rdEditor.")

            mol = Chem.MolFromMolFile(str(mol_path), sanitize=True)
            if mol is None or mol.GetNumAtoms() == 0:
                raise RuntimeError("Could not read a molecule from rdEditor. Save the structure before closing the editor.")
            return Chem.MolToSmiles(mol)

    def enrich_reaction(self, reaction: dict[str, Any]) -> dict[str, Any]:
        if not reaction:
            return {}
        enriched = dict(reaction)
        for prefix, fallback_title in (("substrate_1", "Substrate 1"), ("substrate_2", "Substrate 2"), ("product", "Product")):
            title = str(reaction.get(f"{prefix}_id") or fallback_title)
            smiles = reaction.get(f"{prefix}_smiles")
            analysis = self.analyze_smiles(smiles, title=title) if smiles else {"success": False}
            if analysis.get("success"):
                if enriched.get(f"{prefix}_formula") in (None, ""):
                    enriched[f"{prefix}_formula"] = analysis.get("formula") or ""
                if enriched.get(f"{prefix}_molar_mass_g_mol") in (None, ""):
                    enriched[f"{prefix}_molar_mass_g_mol"] = analysis.get("molarMass") or ""
                if enriched.get(f"{prefix}_inchi_key") in (None, ""):
                    enriched[f"{prefix}_inchi_key"] = analysis.get("inchiKey") or ""
            enriched[f"{prefix}_svg_uri"] = self.smiles_to_svg_data_uri(smiles, title=title)
            enriched[f"{prefix}_summary_text"] = self._build_species_summary(prefix, enriched)
            enriched[f"{prefix}_meta_text"] = self._build_species_meta(prefix, enriched)

        for idx in range(1, 5):
            prefix = f"reagent_{idx}"
            title = str(reaction.get(f"{prefix}_name") or reaction.get(f"{prefix}_id") or f"Reagent {idx}")
            smiles = reaction.get(f"{prefix}_smiles")
            analysis = self.analyze_smiles(smiles, title=title) if smiles else {"success": False}
            if analysis.get("success"):
                if enriched.get(f"{prefix}_formula") in (None, ""):
                    enriched[f"{prefix}_formula"] = analysis.get("formula") or ""
                if enriched.get(f"{prefix}_molar_mass_g_mol") in (None, ""):
                    enriched[f"{prefix}_molar_mass_g_mol"] = analysis.get("molarMass") or ""
                if enriched.get(f"{prefix}_inchi_key") in (None, ""):
                    enriched[f"{prefix}_inchi_key"] = analysis.get("inchiKey") or ""
            enriched[f"{prefix}_summary_text"] = self._build_reagent_summary(prefix, enriched)
        enriched["reagents_summary_text"] = self._build_reagents_summary(enriched)
        enriched["conditions_summary_text"] = self._build_conditions_summary(reaction)
        enriched["notes_summary_text"] = self._build_notes_summary(reaction)
        enriched["rdkit_status"] = self.rdkit_status
        return enriched

    def _build_species_summary(self, prefix: str, reaction: dict[str, Any]) -> str:
        parts: list[str] = []
        moles = reaction.get(f"{prefix}_moles_mol")
        mass = reaction.get(f"{prefix}_mass_g")
        volume = reaction.get(f"{prefix}_volume_l")
        coeff = reaction.get(f"{prefix}_stoich_coeff")
        molar_mass = reaction.get(f"{prefix}_molar_mass_g_mol")
        if moles not in (None, ""):
            parts.append(f"{self._format_number(moles, 4)} mol")
        if mass not in (None, ""):
            parts.append(f"{self._format_number(mass, 4)} g")
        if volume not in (None, ""):
            parts.append(f"{self._format_number(volume, 4)} L")
        if molar_mass not in (None, ""):
            parts.append(f"MW {self._format_number(molar_mass, 4)} g/mol")
        if coeff not in (None, ""):
            parts.append(f"ν = {self._format_number(coeff, 3)}")
        return " • ".join(parts) if parts else "No quantified data"

    def _build_species_meta(self, prefix: str, reaction: dict[str, Any]) -> str:
        parts: list[str] = []
        formula = reaction.get(f"{prefix}_formula")
        molar_mass = reaction.get(f"{prefix}_molar_mass_g_mol")
        cas = reaction.get(f"{prefix}_cas")
        iupac = reaction.get(f"{prefix}_iupac_name")
        inchi_key = reaction.get(f"{prefix}_inchi_key")
        cid = reaction.get(f"{prefix}_pubchem_cid")
        smiles = reaction.get(f"{prefix}_smiles")
        if formula:
            parts.append(f"Formula: {formula}")
        if molar_mass not in (None, ""):
            parts.append(f"Molar mass: {self._format_number(molar_mass, 4)} g/mol")
        if cas:
            parts.append(f"CAS: {cas}")
        if iupac:
            parts.append(f"IUPAC: {iupac}")
        if cid:
            parts.append(f"PubChem CID: {cid}")
        if inchi_key:
            parts.append(f"InChIKey: {inchi_key}")
        if smiles:
            wrapped = "\n".join(textwrap.wrap(str(smiles), width=44))
            parts.append(f"SMILES:\n{wrapped}")
        return "\n".join(parts) if parts else "No metadata"

    def _build_reagent_summary(self, prefix: str, reaction: dict[str, Any]) -> str:
        parts: list[str] = []
        equiv = reaction.get(f"{prefix}_equiv")
        moles = reaction.get(f"{prefix}_moles_mol")
        mass = reaction.get(f"{prefix}_mass_g")
        molar_mass = reaction.get(f"{prefix}_molar_mass_g_mol")
        cas = reaction.get(f"{prefix}_cas")
        if equiv not in (None, ""):
            parts.append(f"{self._format_number(equiv, 3)} equiv")
        if moles not in (None, ""):
            parts.append(f"{self._format_number(moles, 6)} mol")
        if mass not in (None, ""):
            parts.append(f"{self._format_number(mass, 6)} g")
        if molar_mass not in (None, ""):
            parts.append(f"MW {self._format_number(molar_mass, 4)} g/mol")
        if cas:
            parts.append(f"CAS {cas}")
        return " • ".join(parts) if parts else "No reagent data"

    def _build_reagents_summary(self, reaction: dict[str, Any]) -> str:
        lines: list[str] = []
        for idx in range(1, 5):
            cls = str(reaction.get(f"reagent_{idx}_class") or "").strip()
            name = str(reaction.get(f"reagent_{idx}_name") or reaction.get(f"reagent_{idx}_id") or "").strip()
            equiv = reaction.get(f"reagent_{idx}_equiv")
            if not any([cls, name, equiv not in (None, "")]):
                continue
            label = f"{cls}: {name}" if cls and name else (name or cls)
            if equiv not in (None, ""):
                label += f" ({self._format_number(equiv, 3)} equiv)"
            lines.append(label)
        return "\n".join(lines) if lines else "No reagents recorded"

    def _build_conditions_summary(self, reaction: dict[str, Any]) -> str:
        lines: list[str] = []
        temperature = reaction.get("temperature_c")
        time_h = reaction.get("time_h")
        solvent = reaction.get("solvent_name")
        solvent_volume = reaction.get("solvent_volume_l")
        template = reaction.get("template_name")
        yield_percent = reaction.get("yield_percent")
        if temperature not in (None, ""):
            lines.append(f"Temperature: {self._format_number(temperature, 2)} °C")
        if time_h not in (None, ""):
            lines.append(f"Time: {self._format_number(time_h, 3)} h")
        if solvent:
            if solvent_volume not in (None, ""):
                lines.append(f"Solvent: {solvent} ({self._format_number(solvent_volume, 4)} L)")
            else:
                lines.append(f"Solvent: {solvent}")
        if template:
            lines.append(f"Template: {template}")
        if yield_percent not in (None, ""):
            lines.append(f"Yield: {self._format_number(yield_percent, 1)}%")
        return "\n".join(lines) if lines else "No conditions recorded"

    def _build_notes_summary(self, reaction: dict[str, Any]) -> str:
        chunks = [
            str(reaction.get("other_conditions") or "").strip(),
            str(reaction.get("work_up") or "").strip(),
            str(reaction.get("product_notes") or "").strip(),
            str(reaction.get("tags") or "").strip(),
        ]
        text = "\n\n".join([chunk for chunk in chunks if chunk])
        return text or "No notes"

    @staticmethod
    def _format_number(value: Any, precision: int = 4) -> str:
        try:
            return f"{float(value):.{precision}f}".rstrip("0").rstrip(".")
        except Exception:
            return str(value)

    @staticmethod
    def _placeholder_svg(title: str, subtitle: str) -> str:
        title = html.escape(title or "No structure")
        subtitle = html.escape(subtitle or "")
        return f"""<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 420 280'>
  <rect x='0' y='0' width='420' height='280' rx='18' fill='#f6f8fb'/>
  <rect x='10' y='10' width='400' height='260' rx='14' fill='white' stroke='#d4dce7' stroke-width='2'/>
  <text x='210' y='108' text-anchor='middle' font-family='Arial, Helvetica, sans-serif' font-size='22' fill='#304254'>{title}</text>
  <text x='210' y='144' text-anchor='middle' font-family='Arial, Helvetica, sans-serif' font-size='15' fill='#6c7d8f'>{subtitle}</text>
</svg>"""
