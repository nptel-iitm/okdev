# Notes can be created without a title
## What happens

Submitting the note form with an empty title creates the note. It renders in
the list with an empty heading, and the API returns 201.

## What should happen

Per the README: *"A note must have a title. Creating one without a title is
rejected with a validation message, and no note is created."*

## Steps to reproduce

1. `docker compose up`, open http://localhost:8080/
2. Sign in as `demo@example.com` / `correct-horse`
3. Leave the Title field empty, type anything in the body
4. Press **Add note**

Observed: a note appears with a blank heading. Expected: a validation message,
and no note created.

Reproducible against the API directly:

```
curl -X POST localhost:8080/api/notes -H "Authorization: Bearer $TOKEN" \
  -d '{"title":"","body":"no title here"}'
-> 201 {"id": 1}
```

## Acceptance criteria

- [ ] The API rejects a note with a blank or whitespace-only title with 400 and an error message
- [ ] The frontend shows a validation message and does not clear the body field
- [ ] No note is persisted in either case
- [ ] A regression test covers the API rejection