# deskilo-documentation — reference

## Stitching a scrolled form — what 2026-09-10 cost

- **Measure the trims per batch.** `--trim-top` must remove the status bar AND the
  orange dev banner AND the app bar — on that device 390 px, not the 130 of the
  status bar alone. Leave the app bar in and every junction carries a repeated
  "← Features" band; the matcher matches the band instead of the content and splices
  two unrelated paragraphs. `--trim-bottom` is the navigation bar, 120 there.
- **The matcher scores the WHOLE overlap with a trimmed mean** (`findOverlap`,
  #1053). A one-number-per-row signature is a strip, and a strip matches a card edge
  anywhere: it put capture 10 at an overlap of 644 instead of 150 and **swallowed 494
  rows** without changing the output's dimensions. The trim matters because the
  rotating help-hint card corrupts a minority of rows outright.
- **Trust the render, not the score.** Whole-width, a true overlap scores
  ~0.00–0.36; above ~1.5 is not an overlap. Every stitching bug that session was
  caught by looking at the cropped junction, none by the number.
- **Real gaps exist, and butt-joining is the honest answer.** Two of the Features
  form's 27 junctions had nothing in common (nobody photographed between them).
  Losing rows nobody photographed beats silently losing rows that WERE photographed.
- **`ingest` and `merge` order by the capture INDEX** (a string sort handed `merge`
  1, 10, 11, … 2 until #1053). Zero-padded names in scroll order cost nothing.

## Screenshots in English (#1198)

One image set serves all five guides, so four readers in five always see a foreign
screenshot; what the set can be is **consistent**. English, because it is the
widest reach and the anchors are English already. Per-language sets are correct and
cost five times the shooting and storage. The French legacy images are a backlog,
not a batch: each is replaced for free the next time that screen is photographed
(`media ingest --screen <id>` overwrites the same file). Set the device to English
before a batch, next to entering the Demo workspace.

## Personal data (#1199, #1380, #1514)

The old Demo *mode* blurred fields on a live workspace; it is gone (#1380) and the
blur is forbidden by `no_render_tree_blur_test` because it failed OPEN — one
unregistered string stayed in the clear. Today's Demo is a self-contained workspace
of invented people with no backend, so nothing on screen can leak. The 2026-09-09
batch carried a full IBAN, a customer's address, five names, three e-mail addresses
and a live join QR; the #1199 sweep pixelated 25 of 85 images and still left a
telephone number legible for ten days (#1514). Images reach the public wiki AND
`assets/help/images/` in every store build, and the originals are in git history.
