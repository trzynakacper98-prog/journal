from __future__ import annotations

import os
import sys
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

from backend.app_bridge import AppBridge
from backend.models import ReactionListModel
from backend.services.chem_service import ChemService
from backend.services.pubchem_service import PubChemService
from backend.services.reaction_service import ReactionService


def resolve_db_path() -> Path:
    env_path = os.environ.get("MINI_ELN_DB_PATH")
    if env_path:
        return Path(env_path).expanduser().resolve()

    cwd_db = Path.cwd() / "data" / "reaction_journal.sqlite"
    if cwd_db.exists():
        return cwd_db

    script_db = Path(__file__).resolve().parent / "data" / "reaction_journal.sqlite"
    return script_db


def main() -> int:
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Material")
    os.environ.setdefault("QT_QUICK_CONTROLS_MATERIAL_VARIANT", "Dense")
    if sys.platform.startswith("linux"):
        os.environ.setdefault("QT_QPA_PLATFORM", "xcb")

    app = QApplication(sys.argv)
    app.setOrganizationName("KacperTrzyna")
    app.setApplicationName("Mini ELN")

    db_path = resolve_db_path()
    reaction_service = ReactionService(db_path=db_path)
    chem_service = ChemService()
    pubchem_service = PubChemService(db_path=db_path)
    reaction_model = ReactionListModel(reaction_service)
    bridge = AppBridge(
        reaction_service=reaction_service,
        reaction_model=reaction_model,
        chem_service=chem_service,
        pubchem_service=pubchem_service,
    )
    bridge.bootstrap()

    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("appBridge", bridge)
    engine.rootContext().setContextProperty("reactionModel", reaction_model)

    main_qml = Path(__file__).resolve().parent / "qml" / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(main_qml)))
    if not engine.rootObjects():
        return 1
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
