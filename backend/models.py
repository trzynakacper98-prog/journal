from __future__ import annotations

from typing import Any

from PySide6.QtCore import Property, QAbstractListModel, QModelIndex, Qt, Signal

from .services.reaction_service import ReactionService


class ReactionListModel(QAbstractListModel):
    countChanged = Signal()

    ROLES = {
        Qt.UserRole + 1: b"dbId",
        Qt.UserRole + 2: b"reactionId",
        Qt.UserRole + 3: b"dateStarted",
        Qt.UserRole + 4: b"reactionType",
        Qt.UserRole + 5: b"templateName",
        Qt.UserRole + 6: b"substrate1Id",
        Qt.UserRole + 7: b"substrate2Id",
        Qt.UserRole + 8: b"productId",
        Qt.UserRole + 9: b"yieldPercent",
        Qt.UserRole + 10: b"tags",
    }

    def __init__(self, reaction_service: ReactionService):
        super().__init__()
        self._reaction_service = reaction_service
        self._items: list[dict[str, Any]] = []

    @Property(int, notify=countChanged)
    def count(self) -> int:
        return len(self._items)

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:
        if parent.isValid():
            return 0
        return len(self._items)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole) -> Any:
        if not index.isValid() or not (0 <= index.row() < len(self._items)):
            return None

        item = self._items[index.row()]
        role_map = {
            Qt.UserRole + 1: item.get("id"),
            Qt.UserRole + 2: item.get("reaction_id", ""),
            Qt.UserRole + 3: item.get("date_started", ""),
            Qt.UserRole + 4: item.get("reaction_type", ""),
            Qt.UserRole + 5: item.get("template_name", ""),
            Qt.UserRole + 6: item.get("substrate_1_id", ""),
            Qt.UserRole + 7: item.get("substrate_2_id", ""),
            Qt.UserRole + 8: item.get("product_id", ""),
            Qt.UserRole + 9: self._format_yield(item.get("yield_percent")),
            Qt.UserRole + 10: item.get("tags", ""),
        }
        return role_map.get(role)

    def roleNames(self) -> dict[int, bytes]:
        return self.ROLES

    def refresh(self, query: str = "", tag: str = "", reaction_type: str = "", template_name: str = "") -> None:
        items = self._reaction_service.list_reactions(query=query, tag=tag, reaction_type=reaction_type, template_name=template_name)
        self.beginResetModel()
        self._items = items
        self.endResetModel()
        self.countChanged.emit()

    def item(self, row: int) -> dict[str, Any] | None:
        if 0 <= row < len(self._items):
            return self._items[row]
        return None

    def row_for_db_id(self, db_id: int) -> int:
        for idx, item in enumerate(self._items):
            if item.get("id") == db_id:
                return idx
        return -1

    @staticmethod
    def _format_yield(value: Any) -> str:
        if value is None or value == "":
            return ""
        try:
            return f"{float(value):.1f}%"
        except (TypeError, ValueError):
            return str(value)
