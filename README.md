# Mini ELN QML – stage 16

This stage updates the reaction editor layout:
- Substrate 1 and Substrate 2 stay as the only always-visible species sections.
- Reagents are added dynamically with an **Add reagent** button and saved with the reaction.
- Product remains available as an optional section.
- Reagent count is stored in SQLite and restored when reopening a reaction or template.
- CAS-based property lookup is preserved for reagents and species.

Run:
```bash
pip install PySide6
python3 main.py
```

Optional for structure drawing/editing:
```bash
pip install rdeditor
```

Use `MINI_ELN_DB_PATH` to point to a custom SQLite database.
# journal
