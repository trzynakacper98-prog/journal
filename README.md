# Mini ELN (desktop, non-web)

Mini ELN is a **desktop Qt application** (PySide6 + QML).  
It does **not** require a browser or web server.

## Quick start

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install PySide6
python3 main.py
```

Optional chemistry editor plugin:

```bash
pip install rdeditor
```

Use `MINI_ELN_DB_PATH` to point to a custom SQLite database.

---

## Platform notes

### macOS
Works as a native desktop app with Python + PySide6.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt 2>/dev/null || pip install PySide6
python3 main.py
```

### Windows (WSL)
You can run in WSL with GUI support (WSLg on Windows 11).

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install PySide6
python3 main.py
```

If GUI does not appear in WSL:
- ensure WSLg is installed/enabled,
- verify GUI apps work in WSL (e.g. `xeyes`),
- then rerun `python3 main.py`.

---

## Why this is desktop-first
- UI is loaded directly from `qml/Main.qml` by Qt (`QQmlApplicationEngine`).
- There is no HTTP backend process required to use the app locally.
