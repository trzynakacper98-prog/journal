from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

from ..database import Database


class PubChemService:
    BASE_URL = "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound"

    def __init__(self, db_path: Path):
        self.db = Database(db_path)
        self.ensure_cache_schema()

    def ensure_cache_schema(self) -> None:
        with self.db.connect() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS pubchem_cache (
                    cache_key TEXT PRIMARY KEY,
                    payload_json TEXT NOT NULL,
                    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
            conn.commit()

    def lookup_by_smiles(self, smiles: str) -> dict[str, Any]:
        cleaned = (smiles or "").strip()
        if not cleaned:
            raise ValueError("Enter a SMILES string first.")
        cache_key = f"smiles::{cleaned}"
        cached = self._get_cache(cache_key)
        if cached:
            return cached
        cid = self._get_cid_from_identifier("smiles", cleaned)
        payload = self._lookup_by_cid(cid)
        self._set_cache(cache_key, payload)
        self._set_cache(f"cid::{cid}", payload)
        return payload

    def lookup_by_name(self, query: str) -> dict[str, Any]:
        cleaned = (query or "").strip()
        if not cleaned:
            raise ValueError("Enter a compound name, synonym, CAS number, or CID first.")
        cache_key = f"name::{cleaned.lower()}"
        cached = self._get_cache(cache_key)
        if cached:
            return cached
        cid = self._get_cid_from_identifier("name", cleaned)
        payload = self._lookup_by_cid(cid)
        self._set_cache(cache_key, payload)
        self._set_cache(f"cid::{cid}", payload)
        return payload

    def lookup_by_cas(self, cas_number: str) -> dict[str, Any]:
        cleaned = (cas_number or "").strip()
        if not cleaned:
            raise ValueError("Enter a CAS number first.")
        cache_key = f"cas::{cleaned}"
        cached = self._get_cache(cache_key)
        if cached:
            return cached
        cid = self._get_cid_from_identifier("name", cleaned)
        payload = self._lookup_by_cid(cid)
        self._set_cache(cache_key, payload)
        self._set_cache(f"cid::{cid}", payload)
        return payload

    def _lookup_by_cid(self, cid: int) -> dict[str, Any]:
        cached = self._get_cache(f"cid::{cid}")
        if cached:
            return cached
        props = self._request_json(
            f"{self.BASE_URL}/cid/{cid}/property/CanonicalSMILES,IsomericSMILES,MolecularFormula,MolecularWeight,IUPACName,InChIKey/JSON"
        )
        synonyms_json = self._request_json(f"{self.BASE_URL}/cid/{cid}/synonyms/JSON")
        properties = (((props or {}).get("PropertyTable") or {}).get("Properties") or [])
        if not properties:
            raise ValueError("PubChem returned no properties for this CID.")
        row = properties[0]
        all_synonyms = ((((synonyms_json or {}).get("InformationList") or {}).get("Information") or [{}])[0].get("Synonym") or [])
        cas_number = self._extract_cas_number(all_synonyms)
        synonyms = all_synonyms[:20]
        payload = {
            "success": True,
            "cid": str(cid),
            "canonicalSmiles": row.get("CanonicalSMILES") or "",
            "isomericSmiles": row.get("IsomericSMILES") or "",
            "formula": row.get("MolecularFormula") or "",
            "molarMass": f"{float(row.get('MolecularWeight')):.4f}" if row.get("MolecularWeight") not in (None, "") else "",
            "iupacName": row.get("IUPACName") or "",
            "inchiKey": row.get("InChIKey") or "",
            "casNumber": cas_number,
            "synonyms": synonyms,
            "message": f"Loaded metadata from PubChem (CID {cid}).",
        }
        self._set_cache(f"cid::{cid}", payload)
        return payload

    def _get_cid_from_identifier(self, kind: str, identifier: str) -> int:
        endpoint = f"{self.BASE_URL}/{kind}/{quote(identifier)}/cids/JSON"
        data = self._request_json(endpoint)
        cids = (((data or {}).get("IdentifierList") or {}).get("CID") or [])
        if not cids:
            raise ValueError("PubChem returned no matching compound for this query.")
        return int(cids[0])

    def _request_json(self, url: str) -> dict[str, Any]:
        req = Request(url, headers={"User-Agent": "MiniELN/1.0"})
        try:
            with urlopen(req, timeout=20) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except HTTPError as exc:
            try:
                detail = exc.read().decode("utf-8", errors="replace")
            except Exception:
                detail = exc.reason
            raise ValueError(f"PubChem HTTP {exc.code}: {detail}") from exc
        except URLError as exc:
            raise ValueError(f"Could not connect to PubChem: {exc.reason}") from exc
        except json.JSONDecodeError as exc:
            raise ValueError("PubChem returned invalid JSON.") from exc

    def _get_cache(self, cache_key: str) -> dict[str, Any] | None:
        with self.db.connect() as conn:
            row = conn.execute("SELECT payload_json FROM pubchem_cache WHERE cache_key = ?", (cache_key,)).fetchone()
            if not row:
                return None
            try:
                payload = json.loads(row["payload_json"])
            except Exception:
                return None
        return payload if isinstance(payload, dict) else None

    def _set_cache(self, cache_key: str, payload: dict[str, Any]) -> None:
        with self.db.connect() as conn:
            conn.execute(
                "INSERT OR REPLACE INTO pubchem_cache (cache_key, payload_json, updated_at) VALUES (?, ?, CURRENT_TIMESTAMP)",
                (cache_key, json.dumps(payload, ensure_ascii=False)),
            )
            conn.commit()
