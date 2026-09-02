import os
import tempfile

from app import store


def make_conn():
    path = os.path.join(tempfile.mkdtemp(), "t.db")
    conn = store.connect(path)
    store.migrate(conn)
    return conn


def test_create_and_list_a_note():
    conn = make_conn()
    store.create_note(conn, "a@example.com", "Shopping", "milk")
    notes = store.list_notes(conn, "a@example.com")
    assert [n["title"] for n in notes] == ["Shopping"]


def test_delete_removes_the_note():
    conn = make_conn()
    note_id = store.create_note(conn, "a@example.com", "Temp", "x")
    store.delete_note(conn, "a@example.com", note_id)
    assert store.list_notes(conn, "a@example.com") == []
