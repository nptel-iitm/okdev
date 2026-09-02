"""Persistence for the subscriptions service."""
import sqlite3

SCHEMA = """
CREATE TABLE IF NOT EXISTS plans (
    id    INTEGER PRIMARY KEY,
    name  TEXT NOT NULL UNIQUE,
    price INTEGER NOT NULL CHECK (price >= 0)
);
CREATE TABLE IF NOT EXISTS subscriptions (
    id      INTEGER PRIMARY KEY,
    email   TEXT NOT NULL,
    plan_id INTEGER NOT NULL REFERENCES plans(id),
    UNIQUE (email)
);
"""


def connect(path):
    conn = sqlite3.connect(path)
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def migrate(conn):
    conn.executescript(SCHEMA)
    conn.commit()


def add_plan(conn, name, price):
    cur = conn.execute("INSERT INTO plans (name, price) VALUES (?, ?)", (name, price))
    conn.commit()
    return cur.lastrowid


def subscribe(conn, email, plan_id):
    """Create a subscription. One subscription per email address."""
    cur = conn.execute(
        "INSERT INTO subscriptions (email, plan_id) VALUES (?, ?)", (email, plan_id)
    )
    conn.commit()
    return cur.lastrowid


def change_plan(conn, email, plan_id):
    """Move an existing subscriber onto a different plan."""
    conn.execute("UPDATE subscriptions SET plan_id = ? WHERE email = ?", (plan_id, email))
    conn.commit()


def monthly_revenue(conn):
    """Total price across all active subscriptions."""
    row = conn.execute(
        "SELECT SUM(p.price) FROM subscriptions s JOIN plans p ON p.id = s.plan_id"
    ).fetchone()
    return row[0] or 0
