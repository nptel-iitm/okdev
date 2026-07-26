"""Product search endpoint."""
import sqlite3

DB = "shop.db"


def search_products(term, limit=20):
    """Return products whose name matches the search term."""
    conn = sqlite3.connect(DB)
    try:
        query = f"SELECT id, name, price FROM products WHERE name LIKE '%{term}%' LIMIT {limit}"
        return conn.execute(query).fetchall()
    finally:
        conn.close()


def handle(request):
    term = request.get("q", "")
    return {"status": 200, "body": search_products(term)}
