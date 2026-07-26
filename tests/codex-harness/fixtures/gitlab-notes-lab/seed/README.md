# notes-lab

A small notes service: a JSON API and a static frontend, backed by SQLite.

## Running locally

    docker compose up

The app is then at http://localhost:8080/.

Without Docker, `PORT=8080 python3 -m app.server` from the repository root does
the same thing.

## Accounts

    demo@example.com / correct-horse
    sam@example.com  / hunter2222

## Intended behaviour

- Signing in with valid credentials returns a token; wrong credentials return
  401 and an error message on screen.
- A signed-in user can create a note and see it listed.
- **A note must have a title.** Creating one without a title is rejected with a
  validation message, and no note is created.
- **A user sees only their own notes.** One account's notes are never visible
  to another.
- Signing out returns the user to the sign-in screen.
- The interface is usable on a 375px-wide phone screen.

## Tests

    python3 -m pytest
