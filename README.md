# Mini ELN (desktop, non-web)

Mini ELN is now a **lightweight desktop app** (Tkinter + Python backend).  
It does **not** require a browser or web server.

## Quick start

```bash
python3 main.py
```

If you prefer isolated environments:

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 main.py
```

Optional chemistry editor plugin (only if you still use chemistry plugins from backend):

```bash
pip install rdeditor
```

Use `MINI_ELN_DB_PATH` to point to a custom SQLite database.

---

## Platform notes

### macOS
Works as a native desktop app with system Python.

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 main.py
```

### Windows (WSL)
You can run in WSL with GUI support (WSLg on Windows 11).

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 main.py
```

If GUI does not appear in WSL:
- ensure WSLg is installed/enabled,
- verify GUI apps work in WSL (e.g. `xeyes`),
- then rerun `python3 main.py`.

---

## Why this is desktop-first
- UI is local desktop UI (Tkinter), running in one Python process.
- There is no HTTP backend process required to use the app locally.
