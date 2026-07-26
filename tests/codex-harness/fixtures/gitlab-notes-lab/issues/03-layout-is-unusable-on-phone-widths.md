# Layout is unusable on phone widths
## What happens

The page has a fixed 900px container, so at a 375px viewport the document is
900px wide and the user must scroll sideways. The signed-in email is absolutely
positioned and collides with the heading.

## What should happen

Per the README: *"The interface is usable on a 375px-wide phone screen."*

## Steps to reproduce

1. `docker compose up`, open http://localhost:8080/
2. Set the viewport to 375x812

Observed: horizontal scrolling; the header identity overlaps the title.

## Where to look

`public/style.css` — `.page { width: 900px }` and `.who { position: absolute }`.
The `.hint` colour `#dcdcd6` on the `#fbfbf8` background is also close to
unreadable.

## Acceptance criteria

- [ ] No horizontal scrolling at 375px, 768px or 1920px
- [ ] The header identity does not overlap other content at any of those widths
- [ ] Hint text meets a normal contrast bar