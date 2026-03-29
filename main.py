from __future__ import annotations

import os
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, ttk

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


class MiniELNApp:
    def __init__(self, root: tk.Tk, reaction_service: ReactionService):
        self.root = root
        self.reaction_service = reaction_service
        self.current_id: int | None = None

        self.root.title("Mini ELN (Desktop)")
        self.root.geometry("1200x760")
        self.root.minsize(1000, 640)

        self._build_ui()
        self.refresh_list()
        self.new_reaction()

    def _build_ui(self) -> None:
        container = ttk.Frame(self.root, padding=12)
        container.pack(fill=tk.BOTH, expand=True)
        container.columnconfigure(0, weight=2)
        container.columnconfigure(1, weight=3)
        container.rowconfigure(1, weight=1)

        title = ttk.Label(container, text="Reaction Library + Editor", font=("Segoe UI", 14, "bold"))
        title.grid(row=0, column=0, sticky="w", pady=(0, 8))

        self.stats_var = tk.StringVar(value="Ready")
        stats_label = ttk.Label(container, textvariable=self.stats_var)
        stats_label.grid(row=0, column=1, sticky="e", pady=(0, 8))

        # Left: library
        left = ttk.Frame(container, padding=8)
        left.grid(row=1, column=0, sticky="nsew", padx=(0, 8))
        left.rowconfigure(1, weight=1)
        left.columnconfigure(0, weight=1)

        search_row = ttk.Frame(left)
        search_row.grid(row=0, column=0, sticky="ew", pady=(0, 6))
        search_row.columnconfigure(0, weight=1)
        self.search_var = tk.StringVar()
        self.search_var.trace_add("write", lambda *_: self.refresh_list())
        ttk.Entry(search_row, textvariable=self.search_var).grid(row=0, column=0, sticky="ew")
        ttk.Button(search_row, text="Refresh", command=self.refresh_list).grid(row=0, column=1, padx=(6, 0))

        self.table = ttk.Treeview(
            left,
            columns=("reaction_id", "reaction_type", "date_started"),
            show="headings",
            selectmode="browse",
        )
        self.table.heading("reaction_id", text="Reaction ID")
        self.table.heading("reaction_type", text="Type")
        self.table.heading("date_started", text="Started")
        self.table.column("reaction_id", width=180, anchor=tk.W)
        self.table.column("reaction_type", width=120, anchor=tk.W)
        self.table.column("date_started", width=110, anchor=tk.W)
        self.table.grid(row=1, column=0, sticky="nsew")
        self.table.bind("<<TreeviewSelect>>", self.on_select)

        scrollbar = ttk.Scrollbar(left, orient=tk.VERTICAL, command=self.table.yview)
        self.table.configure(yscrollcommand=scrollbar.set)
        scrollbar.grid(row=1, column=1, sticky="ns")

        # Right: editor
        right = ttk.Frame(container, padding=8)
        right.grid(row=1, column=1, sticky="nsew")
        right.columnconfigure(1, weight=1)
        right.rowconfigure(7, weight=1)

        self.fields: dict[str, tk.StringVar] = {
            "reaction_id": tk.StringVar(),
            "reaction_type": tk.StringVar(),
            "date_started": tk.StringVar(),
            "substrate_1_name": tk.StringVar(),
            "substrate_2_name": tk.StringVar(),
            "product_name": tk.StringVar(),
        }

        form_rows = [
            ("Reaction ID", "reaction_id"),
            ("Type", "reaction_type"),
            ("Date started", "date_started"),
            ("Substrate 1", "substrate_1_name"),
            ("Substrate 2", "substrate_2_name"),
            ("Product", "product_name"),
        ]

        for idx, (label, key) in enumerate(form_rows):
            ttk.Label(right, text=label).grid(row=idx, column=0, sticky="w", pady=4)
            ttk.Entry(right, textvariable=self.fields[key]).grid(row=idx, column=1, sticky="ew", pady=4)

        ttk.Label(right, text="Notes").grid(row=6, column=0, sticky="nw", pady=4)
        self.notes = tk.Text(right, height=10, wrap=tk.WORD)
        self.notes.grid(row=6, column=1, sticky="nsew", pady=4)

        actions = ttk.Frame(right)
        actions.grid(row=8, column=0, columnspan=2, sticky="ew", pady=(8, 0))
        actions.columnconfigure(0, weight=1)
        ttk.Button(actions, text="New", command=self.new_reaction).grid(row=0, column=1, padx=4)
        ttk.Button(actions, text="Save", command=self.save_reaction).grid(row=0, column=2, padx=4)
        ttk.Button(actions, text="Delete", command=self.delete_reaction).grid(row=0, column=3, padx=4)

    def refresh_list(self) -> None:
        query = self.search_var.get().strip()
        rows = self.reaction_service.list_reactions(query=query)
        self.table.delete(*self.table.get_children())
        for item in rows:
            row_id = int(item.get("id") or 0)
            self.table.insert(
                "",
                tk.END,
                iid=str(row_id),
                values=(
                    item.get("reaction_id", ""),
                    item.get("reaction_type", ""),
                    item.get("date_started", ""),
                ),
            )
        stats = self.reaction_service.stats()
        self.stats_var.set(f"Total reactions: {stats.get('count', 0)}")

    def on_select(self, _event=None) -> None:
        selected = self.table.selection()
        if not selected:
            return
        row_id = int(selected[0])
        item = self.reaction_service.get_reaction_details(row_id)
        if not item:
            return
        self.current_id = row_id
        for key, var in self.fields.items():
            var.set(str(item.get(key) or ""))
        self.notes.delete("1.0", tk.END)
        self.notes.insert("1.0", str(item.get("notes") or ""))

    def new_reaction(self) -> None:
        self.current_id = None
        blank = self.reaction_service.blank_reaction()
        for key, var in self.fields.items():
            var.set(str(blank.get(key) or ""))
        self.notes.delete("1.0", tk.END)

    def save_reaction(self) -> None:
        payload = self.reaction_service.blank_reaction()
        payload["id"] = self.current_id
        for key, var in self.fields.items():
            payload[key] = var.get().strip()
        payload["notes"] = self.notes.get("1.0", tk.END).strip()

        try:
            saved_id = self.reaction_service.save_reaction(payload)
        except Exception as exc:
            messagebox.showerror("Save failed", str(exc))
            return

        self.current_id = int(saved_id)
        self.refresh_list()
        self.table.selection_set(str(self.current_id))
        self.table.focus(str(self.current_id))
        self.table.see(str(self.current_id))
        messagebox.showinfo("Saved", "Reaction saved.")

    def delete_reaction(self) -> None:
        if not self.current_id:
            return
        if not messagebox.askyesno("Delete", "Delete selected reaction?"):
            return
        try:
            self.reaction_service.delete_reaction(int(self.current_id))
        except Exception as exc:
            messagebox.showerror("Delete failed", str(exc))
            return
        self.current_id = None
        self.new_reaction()
        self.refresh_list()


def main() -> int:
    reaction_service = ReactionService(db_path=resolve_db_path())
    root = tk.Tk()
    MiniELNApp(root, reaction_service)
    root.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
