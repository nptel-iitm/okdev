"""Notes API and static file server. Standard library only."""
import json
import os
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

from . import store

USERS = {"demo@example.com": "correct-horse", "sam@example.com": "hunter2222"}
DB_PATH = os.environ.get("NOTES_DB", "notes.db")
PUBLIC = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "public")

conn = store.connect(DB_PATH)
store.migrate(conn)
SESSIONS = {}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def _json(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _owner(self):
        token = (self.headers.get("Authorization") or "").replace("Bearer ", "")
        return SESSIONS.get(token)

    def _body(self):
        length = int(self.headers.get("Content-Length") or 0)
        if not length:
            return {}
        try:
            return json.loads(self.rfile.read(length))
        except json.JSONDecodeError:
            return {}

    def do_POST(self):
        path = urlparse(self.path).path
        if path == "/api/signin":
            data = self._body()
            email, password = data.get("email", ""), data.get("password", "")
            if USERS.get(email) == password:
                token = f"tok-{len(SESSIONS) + 1}-{email}"
                SESSIONS[token] = email
                return self._json(200, {"token": token, "email": email})
            return self._json(401, {"error": "Email or password is incorrect."})

        if path == "/api/notes":
            owner = self._owner()
            if not owner:
                return self._json(401, {"error": "Sign in first."})
            data = self._body()
            note_id = store.create_note(conn, owner, data.get("title", ""), data.get("body", ""))
            return self._json(201, {"id": note_id})

        return self._json(404, {"error": "Not found"})

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/notes":
            owner = self._owner()
            if not owner:
                return self._json(401, {"error": "Sign in first."})
            limit = int((parse_qs(parsed.query).get("limit") or ["20"])[0])
            return self._json(200, {"notes": store.list_notes(conn, owner, limit)})

        rel = parsed.path.lstrip("/") or "index.html"
        if not re.fullmatch(r"[A-Za-z0-9_.\-/]+", rel):
            return self._json(400, {"error": "Bad path"})
        full = os.path.join(PUBLIC, rel)
        if not os.path.isfile(full):
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        ctype = {"html": "text/html", "css": "text/css", "js": "application/javascript"}.get(
            rel.rsplit(".", 1)[-1], "text/plain"
        )
        with open(full, "rb") as fh:
            payload = fh.read()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


def main():
    port = int(os.environ.get("PORT", "8080"))
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()


if __name__ == "__main__":
    main()
