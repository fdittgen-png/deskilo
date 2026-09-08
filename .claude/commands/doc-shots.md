---
description: Ingest the screenshots the owner just posted — name them by screen, merge multi-capture forms, cut the Ausschnitte, update the media index, report what was added or replaced.
---
# /doc-shots — screenshots into documentation images

Read the `deskilo-documentation` skill first.

## 1. Identify each screenshot
For every image the owner posted (they arrive as file paths):
- Name the **screen** from what is on it, as an anchor with dashes:
  `user-money-invoice-detail`, `config-plan-editor`, `env-deploy-screen`.
  Use the app's ARB strings to be sure of the screen's real title; never
  guess a label from a blurry capture.
- Decide whether it is a **new screen**, a **replacement** of one already
  in `.media-workbench/index.json`, or **one capture of several** of the
  same form (same header, scrolled). Say which, per file, before acting.

## 2. Store the originals
```
dart run tool/media.dart ingest --screen <id> <file>…
```
Never edit anything under `docs/media/source/`.

## 3. Merge the captures of one form
```
dart run tool/media.dart merge --screen <id> --trim-top <status bar px> --trim-bottom <nav bar px>
```
The tool prints the overlap it found and its runner-up. If the two are
close, the match is ambiguous — look at the images and pass `--overlap N`.
A single capture that already shows the whole form needs no merge; a
stitched one lands as `<screen>-full.jpg` and belongs inside `<details>`.

## 4. Cut the Ausschnitte
One crop per object the guide explains — the field, the button, the group:
```
dart run tool/media.dart crop --screen <id> --object <name> --rect x,y,w,h
dart run tool/media.dart crop --screen <id> --object <name> --rect x,y,w,h --callout 1@12,40 --callout 2@12,180
```
Read the coordinates off the image; keep a comfortable margin so the
crop is legible on a phone.

## 5. Describe and index
```
dart run tool/media.dart describe --image <name> --text "what it shows"
dart run tool/media.dart index
dart run tool/media.dart check
```
`describe` is what makes the index useful — one sentence: the screen, the
state it is in, and what the reader should look at.

## 6. Report
A table: image · new or replaced (with the old capture's date) · what it
shows · which anchors will use it. Then say which guide sections are now
waiting for their image slot to be filled, and stop — writing the text is
`/doc-user` and friends.
