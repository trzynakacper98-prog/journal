from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any

from ..database import Database

MAX_REAGENTS = 4

SCHEMA_COLUMNS: list[tuple[str, str]] = [
    ("reaction_id", "TEXT"),
    ("date_started", "TEXT"),
    ("date_finished", "TEXT"),
    ("reaction_type", "TEXT"),
    ("template_name", "TEXT"),
    ("temperature_c", "REAL"),
    ("time_h", "REAL"),
    ("solvent_name", "TEXT"),
    ("solvent_volume_l", "REAL"),
    ("other_conditions", "TEXT"),
    ("work_up", "TEXT"),
    ("yield_percent", "REAL"),
    ("tags", "TEXT"),
    ("product_notes", "TEXT"),
    ("reagent_count", "REAL"),
]

for prefix in ("substrate_1", "substrate_2", "product"):
    SCHEMA_COLUMNS.extend(
        [
            (f"{prefix}_id", "TEXT"),
            (f"{prefix}_smiles", "TEXT"),
            (f"{prefix}_moles_mol", "REAL"),
            (f"{prefix}_mass_g", "REAL"),
            (f"{prefix}_volume_l", "REAL"),
            (f"{prefix}_concentration_M", "REAL"),
            (f"{prefix}_stoich_coeff", "REAL"),
            (f"{prefix}_molar_mass_g_mol", "REAL"),
            (f"{prefix}_formula", "TEXT"),
            (f"{prefix}_cas", "TEXT"),
            (f"{prefix}_iupac_name", "TEXT"),
            (f"{prefix}_inchi_key", "TEXT"),
            (f"{prefix}_pubchem_cid", "TEXT"),
            (f"{prefix}_pubchem_synonyms", "TEXT"),
        ]
    )

for idx in range(1, MAX_REAGENTS + 1):
    prefix = f"reagent_{idx}"
    SCHEMA_COLUMNS.extend(
        [
            (f"{prefix}_class", "TEXT"),
            (f"{prefix}_name", "TEXT"),
            (f"{prefix}_id", "TEXT"),
            (f"{prefix}_equiv", "REAL"),
            (f"{prefix}_moles_mol", "REAL"),
            (f"{prefix}_mass_g", "REAL"),
            (f"{prefix}_molar_mass_g_mol", "REAL"),
            (f"{prefix}_formula", "TEXT"),
            (f"{prefix}_cas", "TEXT"),
            (f"{prefix}_iupac_name", "TEXT"),
            (f"{prefix}_inchi_key", "TEXT"),
            (f"{prefix}_pubchem_cid", "TEXT"),
            (f"{prefix}_pubchem_synonyms", "TEXT"),
            (f"{prefix}_smiles", "TEXT"),
        ]
    )

ALL_COLUMNS = [name for name, _ in SCHEMA_COLUMNS]

BASE_LIST_COLUMNS = [
    "id",
    "reaction_id",
    "date_started",
    "reaction_type",
    "template_name",
    "substrate_1_id",
    "substrate_2_id",
    "product_id",
    "yield_percent",
    "tags",
]

BASE_DETAIL_COLUMNS = ["id"] + ALL_COLUMNS

TEXT_FIELDS = {
    "reaction_id",
    "date_started",
    "date_finished",
    "reaction_type",
    "template_name",
    "solvent_name",
    "other_conditions",
    "work_up",
    "tags",
    "product_notes",
}
for prefix in ("substrate_1", "substrate_2", "product"):
    TEXT_FIELDS.update(
        {
            f"{prefix}_id",
            f"{prefix}_cas",
            f"{prefix}_smiles",
            f"{prefix}_formula",
            f"{prefix}_iupac_name",
            f"{prefix}_inchi_key",
            f"{prefix}_pubchem_cid",
            f"{prefix}_pubchem_synonyms",
        }
    )
for idx in range(1, MAX_REAGENTS + 1):
    prefix = f"reagent_{idx}"
    TEXT_FIELDS.update(
        {
            f"{prefix}_class",
            f"{prefix}_name",
            f"{prefix}_id",
            f"{prefix}_formula",
            f"{prefix}_cas",
            f"{prefix}_iupac_name",
            f"{prefix}_inchi_key",
            f"{prefix}_pubchem_cid",
            f"{prefix}_pubchem_synonyms",
            f"{prefix}_smiles",
        }
    )

FLOAT_FIELDS = set(ALL_COLUMNS) - TEXT_FIELDS

REPEATED_REACTION_KEEP_FIELDS = {
    "reaction_type",
    "temperature_c",
    "time_h",
    "solvent_name",
    "solvent_volume_l",
    "other_conditions",
    "work_up",
    "tags",
    "substrate_1_stoich_coeff",
    "substrate_2_stoich_coeff",
    "product_stoich_coeff",
    "reagent_count",
}
for idx in range(1, MAX_REAGENTS + 1):
    prefix = f"reagent_{idx}"
    REPEATED_REACTION_KEEP_FIELDS.update(
        {
            f"{prefix}_class",
            f"{prefix}_name",
            f"{prefix}_id",
            f"{prefix}_equiv",
            f"{prefix}_cas",
            f"{prefix}_smiles",
        }
    )

BUILTIN_TEMPLATES: list[dict[str, Any]] = [
    {
        "name": "Blank reaction",
        "description": "An empty reaction draft with no preset conditions.",
        "category": "General",
        "payload": {},
    },
    {
        "name": "Sonogashira",
        "description": "A typical Sonogashira starting point: Pd + CuI + base under mild heating.",
        "category": "Cross-coupling",
        "payload": {
            "reaction_type": "Sonogashira coupling",
            "template_name": "Sonogashira",
            "tags": "#sonogashira #crosscoupling",
            "substrate_1_stoich_coeff": 1.0,
            "substrate_2_stoich_coeff": 1.2,
            "product_stoich_coeff": 1.0,
            "reagent_count": 4.0,
            "reagent_1_class": "catalyst",
            "reagent_1_name": "Pd(PPh3)2Cl2",
            "reagent_1_equiv": 0.03,
            "reagent_2_class": "cocatalyst",
            "reagent_2_name": "CuI",
            "reagent_2_equiv": 0.05,
            "reagent_3_class": "base",
            "reagent_3_name": "Et3N",
            "reagent_3_equiv": 2.0,
            "reagent_4_class": "solvent/additive",
            "reagent_4_name": "DMF",
            "solvent_name": "DMF",
            "temperature_c": 60.0,
            "time_h": 16.0,
        },
    },
    {
        "name": "Suzuki",
        "description": "A standard Suzuki-Miyaura setup with an inorganic base.",
        "category": "Cross-coupling",
        "payload": {
            "reaction_type": "Suzuki coupling",
            "template_name": "Suzuki",
            "tags": "#suzuki #crosscoupling",
            "substrate_1_stoich_coeff": 1.0,
            "substrate_2_stoich_coeff": 1.3,
            "product_stoich_coeff": 1.0,
            "reagent_count": 2.0,
            "reagent_1_class": "catalyst",
            "reagent_1_name": "Pd(dppf)Cl2",
            "reagent_1_equiv": 0.03,
            "reagent_2_class": "base",
            "reagent_2_name": "K2CO3",
            "reagent_2_equiv": 2.0,
            "solvent_name": "1,4-dioxane / H2O",
            "temperature_c": 85.0,
            "time_h": 12.0,
        },
    },
    {
        "name": "Buchwald-Hartwig",
        "description": "A Buchwald-Hartwig amination setup with palladium and a strong base.",
        "category": "C-N coupling",
        "payload": {
            "reaction_type": "Buchwald-Hartwig amination",
            "template_name": "Buchwald-Hartwig",
            "tags": "#buchwaldhartwig #amination",
            "substrate_1_stoich_coeff": 1.0,
            "substrate_2_stoich_coeff": 1.2,
            "product_stoich_coeff": 1.0,
            "reagent_count": 2.0,
            "reagent_1_class": "catalyst",
            "reagent_1_name": "Pd2(dba)3 / ligand",
            "reagent_1_equiv": 0.02,
            "reagent_2_class": "base",
            "reagent_2_name": "NaOtBu",
            "reagent_2_equiv": 1.8,
            "solvent_name": "toluene",
            "temperature_c": 90.0,
            "time_h": 16.0,
        },
    },
    {
        "name": "Amidation",
        "description": "An acid-amine coupling setup with an activating reagent.",
        "category": "Acylation",
        "payload": {
            "reaction_type": "Amidation",
            "template_name": "Amidation",
            "tags": "#amidation",
            "substrate_1_stoich_coeff": 1.0,
            "substrate_2_stoich_coeff": 1.1,
            "product_stoich_coeff": 1.0,
            "reagent_count": 2.0,
            "reagent_1_class": "coupling reagent",
            "reagent_1_name": "HATU",
            "reagent_1_equiv": 1.1,
            "reagent_2_class": "base",
            "reagent_2_name": "DIPEA",
            "reagent_2_equiv": 2.5,
            "solvent_name": "DMF",
            "temperature_c": 25.0,
            "time_h": 4.0,
        },
    },
]


class ReactionService:
    def __init__(self, db_path: Path):
        self.db = Database(db_path)
        self.ensure_schema()

    def ensure_schema(self) -> None:
        with self.db.connect() as conn:
            conn.execute(
                "CREATE TABLE IF NOT EXISTS reactions (id INTEGER PRIMARY KEY AUTOINCREMENT)"
            )
            existing = self._existing_columns(conn)
            for name, dtype in SCHEMA_COLUMNS:
                if name not in existing:
                    conn.execute(f"ALTER TABLE reactions ADD COLUMN {name} {dtype}")
            indexes = {
                row[1] for row in conn.execute("PRAGMA index_list(reactions)").fetchall()
            }
            if "idx_reactions_reaction_id" not in indexes:
                try:
                    conn.execute(
                        "CREATE UNIQUE INDEX IF NOT EXISTS idx_reactions_reaction_id ON reactions(reaction_id)"
                    )
                except sqlite3.DatabaseError:
                    pass
            conn.execute("CREATE INDEX IF NOT EXISTS idx_reactions_tags ON reactions(tags)")
            conn.execute("CREATE INDEX IF NOT EXISTS idx_reactions_type ON reactions(reaction_type)")
            conn.execute("CREATE INDEX IF NOT EXISTS idx_reactions_template ON reactions(template_name)")
            self._ensure_template_schema(conn)
            conn.commit()

    def _ensure_template_schema(self, conn: sqlite3.Connection) -> None:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS reaction_templates (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL,
                description TEXT DEFAULT '',
                category TEXT DEFAULT '',
                source_reaction_db_id INTEGER,
                source_reaction_id TEXT DEFAULT '',
                is_builtin INTEGER DEFAULT 0,
                payload_json TEXT NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_templates_category ON reaction_templates(category)"
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_templates_source_reaction ON reaction_templates(source_reaction_db_id)"
        )
        self._seed_builtin_templates(conn)

    def _seed_builtin_templates(self, conn: sqlite3.Connection) -> None:
        existing_names = {
            row[0] for row in conn.execute("SELECT name FROM reaction_templates WHERE is_builtin = 1")
        }
        for spec in BUILTIN_TEMPLATES:
            if spec["name"] in existing_names:
                continue
            conn.execute(
                """
                INSERT INTO reaction_templates
                    (name, description, category, source_reaction_db_id, source_reaction_id, is_builtin, payload_json)
                VALUES (?, ?, ?, NULL, '', 1, ?)
                """,
                (
                    spec["name"],
                    spec.get("description", ""),
                    spec.get("category", ""),
                    json.dumps(spec.get("payload", {}), ensure_ascii=False),
                ),
            )

    def _table_exists(self, conn: sqlite3.Connection, table_name: str) -> bool:
        row = conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
            (table_name,),
        ).fetchone()
        return row is not None

    def _existing_columns(self, conn: sqlite3.Connection) -> set[str]:
        rows = conn.execute("PRAGMA table_info(reactions)").fetchall()
        return {row[1] for row in rows}

    @staticmethod
    def _selectable_columns(existing_columns: set[str], desired_columns: list[str]) -> list[str]:
        return [column for column in desired_columns if column in existing_columns]

    def list_reactions(
        self,
        query: str = "",
        tag: str = "",
        reaction_type: str = "",
        template_name: str = "",
    ) -> list[dict[str, Any]]:
        with self.db.connect() as conn:
            if not self._table_exists(conn, "reactions"):
                return []
            existing = self._existing_columns(conn)
            columns = self._selectable_columns(existing, BASE_LIST_COLUMNS)
            if not columns:
                return []

            sql = f"SELECT {', '.join(columns)} FROM reactions"
            params: list[Any] = []
            conditions: list[str] = []

            stripped = query.strip()
            searchable = [
                column
                for column in [
                    "reaction_id",
                    "reaction_type",
                    "template_name",
                    "substrate_1_id",
                    "substrate_2_id",
                    "product_id",
                    "tags",
                ]
                if column in existing
            ]
            if stripped and searchable:
                like = f"%{stripped}%"
                conditions.append("(" + " OR ".join([f"{column} LIKE ?" for column in searchable]) + ")")
                params.extend([like] * len(searchable))

            clean_tag = tag.strip()
            if clean_tag and "tags" in existing:
                conditions.append("LOWER(COALESCE(tags, '')) LIKE ?")
                params.append(f"%{clean_tag.lower()}%")

            clean_type = reaction_type.strip()
            if clean_type and "reaction_type" in existing:
                conditions.append("COALESCE(reaction_type, '') = ?")
                params.append(clean_type)

            clean_template = template_name.strip()
            if clean_template and "template_name" in existing:
                conditions.append("COALESCE(template_name, '') = ?")
                params.append(clean_template)

            if conditions:
                sql += " WHERE " + " AND ".join(conditions)

            order_left = "date_started" if "date_started" in existing else columns[0]
            sql += f" ORDER BY COALESCE({order_left}, '') DESC, id DESC"
            rows = conn.execute(sql, params).fetchall()
            return [dict(row) for row in rows]

    def get_reaction_details(self, row_id: int) -> dict[str, Any]:
        with self.db.connect() as conn:
            if not self._table_exists(conn, "reactions"):
                return {}
            existing = self._existing_columns(conn)
            columns = self._selectable_columns(existing, BASE_DETAIL_COLUMNS)
            if not columns:
                return {}
            sql = f"SELECT {', '.join(columns)} FROM reactions WHERE id = ?"
            row = conn.execute(sql, (row_id,)).fetchone()
            return dict(row) if row else {}

    def blank_reaction(self) -> dict[str, Any]:
        data = {"id": None}
        for column in ALL_COLUMNS:
            data[column] = "" if column in TEXT_FIELDS else None
        data["date_started"] = ""
        data["substrate_1_stoich_coeff"] = 1.0
        data["substrate_2_stoich_coeff"] = 1.0
        data["product_stoich_coeff"] = 1.0
        data["reagent_count"] = 0.0
        return data

    def save_reaction(self, payload: dict[str, Any]) -> int:
        record = self.blank_reaction()
        incoming_id = payload.get("id")
        for column in ALL_COLUMNS:
            record[column] = self._coerce_value(column, payload.get(column))

        reaction_id = str(record.get("reaction_id") or "").strip()
        if not reaction_id:
            raise ValueError("reaction_id is required.")
        record["reaction_id"] = reaction_id

        with self.db.connect() as conn:
            existing = self._existing_columns(conn)
            writable_columns = self._selectable_columns(existing, ALL_COLUMNS)
            clean_values = [record[col] for col in writable_columns]

            if incoming_id not in (None, ""):
                row = conn.execute(
                    "SELECT id FROM reactions WHERE reaction_id = ? AND id != ?",
                    (reaction_id, int(incoming_id)),
                ).fetchone()
                if row:
                    raise ValueError(f"reaction_id '{reaction_id}' already exists.")
                assignments = ", ".join([f"{col} = ?" for col in writable_columns])
                conn.execute(
                    f"UPDATE reactions SET {assignments} WHERE id = ?",
                    clean_values + [int(incoming_id)],
                )
                conn.commit()
                return int(incoming_id)

            row = conn.execute(
                "SELECT id FROM reactions WHERE reaction_id = ?",
                (reaction_id,),
            ).fetchone()
            if row:
                raise ValueError(f"reaction_id '{reaction_id}' already exists.")

            cols = ", ".join(writable_columns)
            qs = ", ".join(["?" for _ in writable_columns])
            cur = conn.execute(
                f"INSERT INTO reactions ({cols}) VALUES ({qs})",
                clean_values,
            )
            conn.commit()
            return int(cur.lastrowid)

    def delete_reaction(self, row_id: int) -> bool:
        with self.db.connect() as conn:
            cur = conn.execute("DELETE FROM reactions WHERE id = ?", (row_id,))
            conn.commit()
            return cur.rowcount > 0

    def duplicate_reaction(self, row_id: int) -> int:
        original = self.get_reaction_details(row_id)
        if not original:
            raise ValueError("Reaction not found for duplication.")
        copy_payload = dict(original)
        copy_payload["id"] = None
        base_id = str(original.get("reaction_id") or "reaction")
        copy_payload["reaction_id"] = self._next_copy_reaction_id(base_id)
        return self.save_reaction(copy_payload)

    def _next_copy_reaction_id(self, base_id: str) -> str:
        candidate = f"{base_id}_copy"
        taken = {row.get("reaction_id") for row in self.list_reactions("")}
        if candidate not in taken:
            return candidate
        idx = 2
        while True:
            candidate = f"{base_id}_copy{idx}"
            if candidate not in taken:
                return candidate
            idx += 1

    def list_templates(self) -> list[dict[str, Any]]:
        with self.db.connect() as conn:
            if not self._table_exists(conn, "reaction_templates"):
                return []
            rows = conn.execute(
                """
                SELECT id, name, description, category, source_reaction_db_id, source_reaction_id,
                       is_builtin, payload_json, created_at, updated_at
                FROM reaction_templates
                ORDER BY is_builtin DESC, name COLLATE NOCASE ASC
                """
            ).fetchall()
        templates: list[dict[str, Any]] = []
        for row in rows:
            item = dict(row)
            payload = self._decode_payload(item.get("payload_json"))
            item["payload"] = payload
            item["kind"] = "builtin" if int(item.get("is_builtin") or 0) else "custom"
            item["reaction_type"] = str(payload.get("reaction_type") or "")
            item["preview_text"] = self._summarize_template_payload(payload)
            item["template_name_preview"] = str(payload.get("template_name") or item.get("name") or "")
            templates.append(item)
        return templates

    def get_template(self, template_id: int) -> dict[str, Any] | None:
        for template in self.list_templates():
            if int(template.get("id") or 0) == int(template_id):
                return template
        return None

    def save_template(
        self,
        name: str,
        payload: dict[str, Any],
        description: str = "",
        category: str = "Custom",
        source_reaction_db_id: int | None = None,
        source_reaction_id: str = "",
        is_builtin: bool = False,
    ) -> int:
        cleaned_name = str(name or "").strip()
        if not cleaned_name:
            raise ValueError("Template name is required.")
        cleaned_payload = self._clean_template_payload(payload)
        if not isinstance(cleaned_payload, dict):
            raise ValueError("Invalid template payload.")
        with self.db.connect() as conn:
            existing = conn.execute(
                "SELECT id FROM reaction_templates WHERE name = ?",
                (cleaned_name,),
            ).fetchone()
            encoded = json.dumps(cleaned_payload, ensure_ascii=False)
            if existing:
                conn.execute(
                    """
                    UPDATE reaction_templates
                    SET description = ?, category = ?, source_reaction_db_id = ?, source_reaction_id = ?,
                        is_builtin = ?, payload_json = ?, updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                    """,
                    (
                        str(description or ""),
                        str(category or ""),
                        source_reaction_db_id,
                        str(source_reaction_id or ""),
                        1 if is_builtin else 0,
                        encoded,
                        int(existing[0]),
                    ),
                )
                conn.commit()
                return int(existing[0])
            cur = conn.execute(
                """
                INSERT INTO reaction_templates
                    (name, description, category, source_reaction_db_id, source_reaction_id, is_builtin, payload_json)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    cleaned_name,
                    str(description or ""),
                    str(category or ""),
                    source_reaction_db_id,
                    str(source_reaction_id or ""),
                    1 if is_builtin else 0,
                    encoded,
                ),
            )
            conn.commit()
            return int(cur.lastrowid)

    def create_template_from_reaction(self, row_id: int, name: str, description: str = "") -> int:
        reaction = self.get_reaction_details(row_id)
        if not reaction:
            raise ValueError("Reaction not found for template creation.")
        payload = self.build_repeat_template_payload(reaction)
        reaction_type = str(reaction.get("reaction_type") or "").strip()
        category = reaction_type or "From reaction"
        source_reaction_id = str(reaction.get("reaction_id") or "")
        return self.save_template(
            name=name,
            payload=payload,
            description=description,
            category=category,
            source_reaction_db_id=int(row_id),
            source_reaction_id=source_reaction_id,
            is_builtin=False,
        )

    def instantiate_template(self, template_id: int) -> dict[str, Any]:
        template = self.get_template(template_id)
        if not template:
            raise ValueError("Template not found.")
        draft = self.blank_reaction()
        payload = template.get("payload") or {}
        for key, value in payload.items():
            if key in draft:
                draft[key] = value
        draft["id"] = None
        draft["reaction_id"] = ""
        draft["date_started"] = ""
        draft["date_finished"] = ""
        draft["yield_percent"] = None
        draft["product_notes"] = ""
        draft["template_name"] = str(template.get("name") or payload.get("template_name") or "")
        return draft

    def delete_template(self, template_id: int) -> bool:
        with self.db.connect() as conn:
            row = conn.execute(
                "SELECT is_builtin FROM reaction_templates WHERE id = ?",
                (int(template_id),),
            ).fetchone()
            if not row:
                return False
            if int(row[0] or 0) == 1:
                raise ValueError("Built-in template cannot be deleted.")
            cur = conn.execute("DELETE FROM reaction_templates WHERE id = ?", (int(template_id),))
            conn.commit()
            return cur.rowcount > 0

    def build_repeat_template_payload(self, reaction: dict[str, Any]) -> dict[str, Any]:
        payload = self.blank_reaction()
        for field in REPEATED_REACTION_KEEP_FIELDS:
            payload[field] = reaction.get(field, payload.get(field))
        payload["reaction_type"] = str(reaction.get("reaction_type") or "")
        payload["template_name"] = str(reaction.get("template_name") or reaction.get("reaction_type") or "")
        payload["yield_percent"] = None
        payload["product_notes"] = ""
        payload["date_started"] = ""
        payload["date_finished"] = ""
        payload["reaction_id"] = ""
        for prefix in ("substrate_1", "substrate_2", "product"):
            for field in (
                "id",
                "smiles",
                "moles_mol",
                "mass_g",
                "volume_l",
                "concentration_M",
                "molar_mass_g_mol",
                "formula",
                "cas",
                "iupac_name",
                "inchi_key",
                "pubchem_cid",
                "pubchem_synonyms",
            ):
                payload[f"{prefix}_{field}"] = "" if f"{prefix}_{field}" in TEXT_FIELDS else None
        return self._clean_template_payload(payload)

    def list_available_tags(self) -> list[dict[str, Any]]:
        counter: dict[str, int] = {}
        with self.db.connect() as conn:
            if not self._table_exists(conn, "reactions"):
                return []
            rows = conn.execute("SELECT tags FROM reactions WHERE COALESCE(tags, '') != ''").fetchall()
        for row in rows:
            raw = str(row[0] or "")
            for token in raw.replace(",", " ").replace(";", " ").split():
                tag = token.strip().lower()
                if not tag:
                    continue
                if not tag.startswith("#"):
                    tag = f"#{tag}"
                counter[tag] = counter.get(tag, 0) + 1
        return [{"tag": tag, "count": counter[tag]} for tag in sorted(counter.keys())]

    def list_available_reaction_types(self) -> list[str]:
        with self.db.connect() as conn:
            if not self._table_exists(conn, "reactions"):
                return []
            rows = conn.execute(
                "SELECT DISTINCT reaction_type FROM reactions WHERE COALESCE(reaction_type, '') != '' ORDER BY reaction_type COLLATE NOCASE ASC"
            ).fetchall()
        return [str(row[0]) for row in rows if row[0] not in (None, "")]

    def list_available_template_names(self) -> list[str]:
        with self.db.connect() as conn:
            if not self._table_exists(conn, "reactions"):
                return []
            rows = conn.execute(
                "SELECT DISTINCT template_name FROM reactions WHERE COALESCE(template_name, '') != '' ORDER BY template_name COLLATE NOCASE ASC"
            ).fetchall()
        return [str(row[0]) for row in rows if row[0] not in (None, "")]

    def stats(self) -> dict[str, Any]:
        with self.db.connect() as conn:
            reaction_count = 0
            template_count = 0
            if self._table_exists(conn, "reactions"):
                row = conn.execute("SELECT COUNT(*) AS cnt FROM reactions").fetchone()
                reaction_count = int(row["cnt"])
            if self._table_exists(conn, "reaction_templates"):
                row = conn.execute("SELECT COUNT(*) AS cnt FROM reaction_templates").fetchone()
                template_count = int(row["cnt"])
            return {
                "count": reaction_count,
                "templateCount": template_count,
                "db_path": str(self.db.db_path),
            }

    def find_row_index_by_id(
        self,
        row_id: int,
        query: str = "",
        tag: str = "",
        reaction_type: str = "",
        template_name: str = "",
    ) -> int:
        for idx, item in enumerate(self.list_reactions(query=query, tag=tag, reaction_type=reaction_type, template_name=template_name)):
            if item.get("id") == row_id:
                return idx
        return -1

    def _clean_template_payload(self, payload: dict[str, Any]) -> dict[str, Any]:
        clean: dict[str, Any] = {}
        for key in ALL_COLUMNS:
            if key in payload:
                clean[key] = self._coerce_value(key, payload.get(key))
        return clean

    @staticmethod
    def _decode_payload(payload_json: Any) -> dict[str, Any]:
        if not payload_json:
            return {}
        try:
            data = json.loads(str(payload_json))
        except Exception:
            return {}
        return data if isinstance(data, dict) else {}

    def _summarize_template_payload(self, payload: dict[str, Any]) -> str:
        parts: list[str] = []
        reaction_type = str(payload.get("reaction_type") or "").strip()
        if reaction_type:
            parts.append(reaction_type)
        solvent = str(payload.get("solvent_name") or "").strip()
        temperature = payload.get("temperature_c")
        time_h = payload.get("time_h")
        if solvent:
            parts.append(f"Solvent: {solvent}")
        conds: list[str] = []
        if temperature not in (None, ""):
            conds.append(f"{self._format_number(temperature, 1)} °C")
        if time_h not in (None, ""):
            conds.append(f"{self._format_number(time_h, 2)} h")
        if conds:
            parts.append("Conditions: " + ", ".join(conds))
        reagents: list[str] = []
        for idx in range(1, MAX_REAGENTS + 1):
            cls = str(payload.get(f"reagent_{idx}_class") or "").strip()
            name = str(payload.get(f"reagent_{idx}_name") or payload.get(f"reagent_{idx}_id") or "").strip()
            equiv = payload.get(f"reagent_{idx}_equiv")
            if not cls and not name and equiv in (None, ""):
                continue
            text = f"{cls}: {name}" if cls and name else (name or cls)
            if equiv not in (None, ""):
                text += f" ({self._format_number(equiv, 3)} equiv)"
            reagents.append(text)
        if reagents:
            parts.append("Reagents: " + "; ".join(reagents))
        tags = str(payload.get("tags") or "").strip()
        if tags:
            parts.append("Tags: " + tags)
        if not parts:
            return "No stored conditions"
        return "\n".join(parts)

    @staticmethod
    def _coerce_value(column: str, value: Any) -> Any:
        if column in TEXT_FIELDS:
            if value is None:
                return ""
            return str(value)
        if value in (None, ""):
            return None
        try:
            return float(value)
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _format_number(value: Any, precision: int = 4) -> str:
        try:
            return f"{float(value):.{precision}f}".rstrip("0").rstrip(".")
        except Exception:
            return str(value)
