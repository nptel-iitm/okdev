# Notes

A small notes application. Serve it with:

    python3 -m http.server 8080 --directory public

Then open http://localhost:8080/.

## Intended behaviour

- Sign in with demo@example.com / correct-horse. Wrong credentials show an
  error and do not sign the user in.
- A signed-in user can add a note with a title and a body, and sees it listed.
- A note must have a title; adding one without a title shows a validation error
  and does not create the note.
- Signing out returns the user to the sign-in screen.
- The interface is usable on a 375px-wide phone screen.
