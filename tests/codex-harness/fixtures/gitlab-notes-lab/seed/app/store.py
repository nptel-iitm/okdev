"""SQLite persistence for notes."""
import sqlite3

SCHEMA = """
CREATE TABLE IF NOT EXISTS notes (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    owner   TEXT NOT NULL,
    title   TEXT NOT NULL,
    body    TEXT NOT NULL DEFAULT ''
);
"""


def connect(path):
    conn = sqlite3.connect(path, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn


def migrate(conn):
    conn.executescript(SCHEMA)
    conn.commit()


def create_note(conn, owner, title, body):
    cur = conn.execute(
        "INSERT INTO notes (owner, title, body) VALUES (?, ?, ?)", (owner, title, body)
    )
    conn.commit()
    return cur.lastrowid


def list_notes(conn, owner, limit=20):
    """Return the caller's notes, most recent first."""
    rows = conn.execute(
        "SELECT id, owner, title, body FROM notes ORDER BY id DESC LIMIT ?", (limit,)
    ).fetchall()
    return [dict(r) for r in rows]


def delete_note(conn, owner, note_id):
    conn.execute("DELETE FROM notes WHERE id = ? AND owner = ?", (note_id, owner))
    conn.commit()
