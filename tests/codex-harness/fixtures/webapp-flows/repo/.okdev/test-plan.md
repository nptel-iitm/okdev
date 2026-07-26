# Test Plan — Notes

## 7. Manual Test Cases

### M1 — Sign in with valid credentials
1. Open http://localhost:8080/.
2. Enter demo@example.com and correct-horse.
3. Press Sign in.
Expected: the notes screen appears and the signed-in email is shown.

### M2 — Sign in with a wrong password
1. Open the app.
2. Enter demo@example.com and wrong-password.
3. Press Sign in.
Expected: an error is shown and the user stays on the sign-in screen.

### M3 — Add a note
1. Sign in.
2. Type a title and a body.
3. Press Add note.
Expected: the note appears in the list with its title and body.

### M4 — Add a note with no title
1. Sign in.
2. Leave the title empty, type a body.
3. Press Add note.
Expected: a validation message appears and no note is created.

### M5 — Empty state
1. Sign in with no notes yet.
Expected: a readable message says there are no notes.

### M6 — Sign out
1. Sign in, then press Sign out.
Expected: the sign-in screen returns and notes are no longer visible.

### M7 — Phone width
1. Open the app at a 375px-wide viewport.
Expected: the layout fits without sideways scrolling and nothing overlaps.

### M8 — Long note body
1. Sign in and add a note with a very long body.
Expected: the text wraps inside its card and does not overflow the page.
