# The help-and-guide framework, for any app

A method for turning an app plus a pile of screenshots into documentation
that is at once the product's help and its wiki, where the help symbol
beside a field opens the paragraph about **that field**. Written from
DesKilo's implementation, but nothing here is specific to it: a second
app adopts it by copying one tool, one registry and seven commands.

## 1. The anchor: one identity for four things

```
<guide>.<module>.<screen>.<object>        user.money.vat.rates
```

Dotted, lower case, never translated. The same id names:

| | |
|---|---|
| the help symbol | `HelpDot(anchor: …)` — a registry constant in the app |
| the documented object | an invisible comment above its heading, in every language |
| its screenshot | the id with dashes: `user-money-vat-rates.jpg` |
| a crop of one part | `user-money-vat-rates--percent.jpg` |

Everything else follows from that single decision:

- **The jump is exact.** The build lifts the comments into an
  anchor → heading map beside the compiled guide; the help screen
  resolves the anchor and jumps to that heading. No substring search, so
  no landing on the nearest section.
- **A new screenshot replaces the old one for free.** Same screen, same
  id, same file name: every link in every language keeps working.
- **The three can be checked.** A lint refuses an anchor the guides do
  not have, a guide that drifts from its translations, a symbol pointing
  into a language that does not exist yet.

Use an **HTML comment**, not a `{#id}` suffix: a comment renders as
nothing on a wiki host and in the app, so one source serves both and the
reader never sees the machinery.

## 2. Guide families, and the rule that keeps them honest

One family per audience — the member, the configuring owner, the
technical administrator, the environments — each existing once per
language. Two rules:

- **A translation that exists is parallel to the original**: same
  headings, same anchors, same image names. Prose is translated;
  structure is not reinvented.
- **A guide that exists in one language only compiles into that
  language's bundle alone.** A reader never gets a document that changes
  language mid-page, and a help symbol may not point into a family until
  every language has it.

The wiki shows the families as separate pages; the app bundles the ones a
language has into one searchable document. That asymmetry is deliberate:
a wiki is browsed, a help screen is searched.

## 3. The screenshot pipeline

```
media/source/      the originals, dated, never edited
guide/images/      what the guides link — the tool's only output
app/images/        the small copies, produced by the guide compiler
workbench/         NOT in version control: what each image shows
```

Commands, in the order a session uses them:

| | |
|---|---|
| `ingest` | store what the owner posted under the id of the screen it shows |
| `merge` | stitch several captures of one scrolling form |
| `crop` | an *Ausschnitt* of one object, with optional numbered callouts |
| `frame` · `redact` | scale and strip; blur what should not be published |
| `describe` · `index` | the workbench index, one line per image |
| `slots` · `check` | what the guides still wait for; what has drifted |

**Merging without asking the user for offsets.** Reduce every row of a
capture to one luminance value; the overlap is the offset where the tail
of the first vector matches the head of the second. Reject a band with no
contrast — a blank scroll gap matches everything — and report the
runner-up, so an ambiguous stitch can be forced by hand instead of
guessed silently.

**Image slots.** Write the text before the screenshot exists: an
`<!-- image: name -->` comment marks the place. It renders as nothing,
the tool lists the waiting ones, and filling one replaces a comment —
never a sentence.

## 4. Where the words come from

From the app, not from memory of the app. The localization files give
every label verbatim; the registries give every field, flag, permission
and placeholder; the migrations give what the server actually allows.
Screenshots confirm and illustrate — they are not the source of the
wording, because a blurry capture invites invention.

For each object, in this order: what it is, in one sentence · what it
decides · what happens if it is left alone · the rule that is easy to get
wrong. Consequences, not mechanisms.

## 5. Adopting it in a second app

1. Copy the media tool and its test; adjust the four folder constants and
   the image format to whatever that app's guides already use.
2. Add the commands and the skill that holds the rules.
3. Create the guide families for the languages that app treats as
   canonical — the rest fall back, exactly as they do for its interface.
4. Write the technical reference from that repository's own facts.
5. Only then the in-app half: the anchor registry, the anchor map, the
   help screen, and the symbols, screen by screen, with a **ratchet lint**
   counting the symbols that still open the nearest section. That number
   may only fall.

An app with no help surface at all does steps 1 to 4 first: the wiki
becomes real without touching the product, and the help screen lands
afterwards as ordinary feature work.
