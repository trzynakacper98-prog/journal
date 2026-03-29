from __future__ import annotations

import sqlite3
from pathlib import Path


class Database:
    def __init__(self, db_path: Path):
        self.db_path = Path(db_path)

    def connect(self) -> sqlite3.Connection:
        if self.db_path.parent:
            self.db_path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn
