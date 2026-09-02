# A signed-in user can see other users' notes
## What happens

`GET /api/notes` returns every note in the database regardless of who owns it.
Any signed-in account can read every other account's notes.

## What should happen

Per the README: *"A user sees only their own notes. One account's notes are
never visible to another."*

## Steps to reproduce

1. `docker compose up`
2. Sign in as `demo@example.com` / `correct-horse`, create a note "Private thing"
3. Sign out, sign in as `sam@example.com` / `hunter2222`
4. Look at the notes list

Observed: Sam sees Demo's "Private thing". Expected: Sam sees only their own notes.

Against the API:

```
curl localhost:8080/api/notes -H "Authorization: Bearer $SAM_TOKEN"
-> returns notes with "owner":"demo@example.com"
```

## Where to look

`app/store.py` — `list_notes` takes an `owner` argument and never uses it in
the query.

## Acceptance criteria

- [ ] `list_notes` filters by owner
- [ ] A signed-in user's list contains only their own notes
- [ ] A regression test creates notes for two owners and asserts separation