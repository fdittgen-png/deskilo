# Admin guide — the technical side

For whoever keeps a DesKilo space running: the documents it prints, the
files it exchanges, the services it talks to, and the database under it.
The everyday configuration is in the
[configuration guide](Admin-Configuration-Guide); what a member sees is
in the [user guide](User-Guide).

*A slot marked `<!-- image: … -->` is a screenshot the pipeline has not
been given yet.*

<!-- anchor: admin.reports.overview -->
## Documents and reports

Every printed thing in DesKilo — an invoice, a reminder, a member letter,
a consumption report, a VAT return, a badge sheet — comes out of one
engine. A **report kind** names the document; a **design** says how it
looks; the **data** the app hands it is a fixed vocabulary of
placeholders.

<!-- image: admin-reports-editor -->

<!-- anchor: admin.reports.kinds -->
### The kinds, and the four presets

Each kind (invoice, credit note, proforma, statement, agreement,
payments, usage, VAT, workspace) starts from one of four presets —
*Simple*, *Classic*, *Verbose*, *Formal* — which differ only in how much
they say, never in what is legally required.

<!-- anchor: admin.reports.bands -->
### Bands: header, body, continuation, footer

The quick way to design. Four bands of markup, each with its own job:

| Band | Where it prints |
|---|---|
| **header** | the top of page 1 only — the letterhead |
| **continuation** | the top of pages 2 and after — a strip naming the document |
| **body** | the only flowing zone: it is what runs on and paginates |
| **footer** | the bottom of *every* page |

Inside a band, one sign per line decides what the line is:

| Sign | What the line becomes |
|---|---|
| `# ` | a heading |
| `## ` | a subheading |
| `- ` | a small line |
| `\| a \| b \|` | a table row; a row of `---` makes the one above a header |
| `---` | a horizontal rule |
| `![name\|w\|align]` | an image from the library, with size and alignment |
| (blank) | a spacer |
| anything else | body text |

The designer's *Placeholders and markup* panel carries all of this
inline, plus **Insert a field…** — the searchable picker grouped by
topic, with a one-line meaning under every name, searchable by that
meaning too — and three ready-made pieces: a line that prints only when
its value exists, one row per invoice line, and the title that says
invoice, credit note or proforma. Whatever you tap lands at the caret of
the band you last edited.

<!-- anchor: admin.reports.layouts -->
### Positioned layouts

The exact way. An XML layout places every element at a millimetre, for
a document that has to satisfy a window envelope or a national form.
**A layout wins over the bands** for the kind it is set on.

The root and its zones:

```xml
<report-layout version="1" page="A4" margin="20mm"
               margin-top="8mm" margin-bottom="8mm">
  <header height="…">…</header>
  <continuation height="…">…</continuation>
  <recipient window="fr|din|off"/>
  <body y="90mm">…</body>
  <footer height="…">…</footer>
</report-layout>
```

`margin` is the side margin; `margin-top` and `margin-bottom` split the
vertical one when a document needs them apart, and are the side margin
when absent. `<recipient>` takes a named window — **fr** at 110 mm,
**din** at 20 mm, both 45 mm down in an 85 × 40 mm box — or explicit
`x y w h`, or `off`. `<body y="…">` is the only flowing zone: `y` is
where it resumes, 90 mm under a window.

**Elements**, valid inside a zone, a `<box>` or a `<column>`:

| Element | What it does |
|---|---|
| `<text style="heading\|subheading\|body\|small" align="left\|center\|right" bold="true">` | a run of type |
| `<image name="library-name" fit="contain\|cover\|fill" align="…"/>` | a picture from the image library |
| `<table><col w="55%" align="right"/>…<row bold="true"><cell align="…">…</cell></row></table>` | a table with declared columns |
| `<box>…</box>` | a group, so children position inside it |
| `<columns><column>…</column>…</columns>` | side-by-side groups |
| `<rule/>` | a horizontal line |
| `<spacer size="4mm"/>` | vertical space |
| `<markup>…</markup>` | band markup, verbatim, inside a positioned layout |

**Frame attributes** — `x y w h` — apply to any element. With `x` or
`y` the element is placed absolutely inside its parent; without either,
it flows after its siblings.

**Units** are `mm cm px pt %`. A bare number is millimetres; `px` is the
CSS pixel (1/96 in); `%` is of the parent — width for `x` and `w`,
height for `y` and `h`.

<!-- anchor: admin.reports.placeholders -->
### The vocabulary

Every placeholder the engine knows, per document family, with the loops
(`lines`, `vat`, `usage_records`, …) and the fields each row carries.
`dart run tool/report.dart describe` prints the current list — it is
generated from the same registry the renderer reads, so it can never be
out of date.

<!-- anchor: admin.reports.operators -->
### Liquid: conditions, loops, filters

Liquid runs over the whole file **first**, before the XML is parsed, so
a condition may open in one element and close in another. Values are
XML-escaped on the way in.

| Form | What it does |
|---|---|
| `{{ field }}` | prints the value, escaped |
| `{% if field != "" %}…{% endif %}` | prints the block only when the field has a value |
| `{% if a == b %}…{% else %}…{% endif %}` | the two-branch form |
| `{% unless field == "" %}…{% endunless %}` | the negated form |
| `{% for line in lines %}…{% endfor %}` | one pass per row of a loop |
| `{{ forloop.index }}` | the 1-based row number inside a loop |

**The rule that catches everyone:** every placeholder the engine knows
is seeded **empty**, never nil. An absent field is `""`, so
`{% if x != "" %}` behaves and a design never prints the word `nil`.
Owner texts (`text.<key>`) are seeded the same way through their own
defaulting map.

**Loops and their rows.** `lines` gives `label, kind, pct, month, qty,
unit_price, net, vat_rate, amount, negative`. `month` is the
subscription position's month, already translated into the document's
language — the reason an invoice line can read *September 100 %*.
`vat` gives the per-rate breakdown, `usage_records` the half-days,
`vat_positions` and `vat_rate_totals` the declaration's own rows.

<!-- anchor: admin.reports.window -->
### The window-envelope contract

A letter that goes in a window envelope has one geometry, and it is not
a matter of taste:

| Thing | Where |
|---|---|
| sender line | 20 mm from the left, 20 mm down |
| recipient block | 110 mm from the left, 45 mm down, inside 85 × 40 mm |
| body | resumes at 90 mm |
| footer | on every page |
| continuation strip | from page two |

Nothing but the recipient may put ink inside the window band. This is
**proven on the rendered PDF**, not by eye: the check measures the ink
positions of the produced file and exits non-zero when something lands
where the window is.

<!-- anchor: admin.reports.cli -->
### The command line

```
dart run tool/report.dart check <layout.xml> [--data data.json]
dart run tool/report.dart render <layout.xml> [--data data.json] -o out.pdf
dart run tool/report.dart sample --kind invoice > data.json
dart run tool/report.dart describe
```

- **check** renders the design and measures it against the window
  contract. Exit 0 conforms; exit 1 means ink in the window band, and
  it says which element; exit 2 means the design could not be read, and
  it names the element that broke.
- **render** produces the PDF, so a design can be proofed without the
  app.
- **sample** writes a data file carrying every placeholder the engine
  knows, which is the fastest way to see what a field is called.
- **describe** prints the vocabulary above — zones, elements, frame
  attributes, units, Liquid and the placeholder list. It is generated
  from the same registry the renderer reads, so it cannot drift from
  the engine.

The CLI is pure Dart and must stay that way: it imports nothing from
Flutter or the localizations, and a test breaks the moment a domain
file it uses pulls `AppLocalizations` in.

<!-- anchor: admin.einvoice.overview -->
## Electronic invoicing

An invoice leaves DesKilo as a PDF a person reads and a structured file
a machine reads, and the two say the same thing because they are
produced from the same frozen document.

<!-- anchor: admin.einvoice.formats -->
### CII, UBL, Factur-X

All three are the same invoice expressed three ways, and all three
satisfy **EN 16931**, the European semantic model that says which facts
an invoice must carry (BT-1 the number, BT-48 the buyer's VAT
identifier, and so on).

| Format | What it is |
|---|---|
| **CII** | UN/CEFACT Cross Industry Invoice — the XML syntax Chorus Pro takes |
| **UBL** | OASIS Universal Business Language — the syntax Peppol takes |
| **Factur-X** | a PDF/A-3 with the CII XML *embedded in it* — one file a person reads and a machine parses |

Factur-X is why the PDF and the XML cannot disagree: they are the same
file. When a platform wants them apart, both are produced from the one
frozen document, never re-rendered from live data.

<!-- anchor: admin.einvoice.readiness -->
### The readiness gate

Before anything is transmitted the app checks the document against the
norm and **refuses with the missing item named**, because an invoice
rejected by a platform costs more to fix than one never sent.

What it refuses:

- a seller with no identifier the regime demands — a VAT number when you
  charge VAT, a company registration number when you do not;
- a **reverse-charge** document whose customer has no VAT number: that
  number is what proves the tax is theirs;
- an exemption with no reason and no country default to fall back on;
- a customer VAT number whose **shape does not match its country** —
  a warning, not a refusal, since shapes change;
- a buyer with no address, once the destination requires one.

Members supply their own country and, when they invoice as a business,
their VAT number, beside their address in *Settings → Personal
information*.

<!-- anchor: admin.einvoice.platforms -->
### Platforms and credentials

A document can go to **two destinations at once**: the government
platform your country mandates, and the customer's own service. Both are
configured on the space, and either may be off.

Credentials live on the workspace, never in the space file and never in
a deployment — an export you send to a colleague carries the
configuration and not the keys. A **development space always uses the
test endpoint**, which physically cannot reach a government platform, so
a test invoice can never become a real one.

Every attempt is recorded on the invoice's own transmission history:
when, to which destination, what the platform answered, and the
reference it returned. A failed transmission leaves the invoice
untouched and retryable — the document is frozen, the transmission is
not part of it.

<!-- anchor: admin.exports.accounting -->
## Accounting exports

Three formats, one ledger underneath:

| Format | Where it is asked for | What it carries |
|---|---|---|
| **FEC** | France (art. A47 A-1 LPF) | every entry of the period, in the mandated column order |
| **SAF-T** | the OECD standard, several EU countries | the audit file: accounts, entries, documents |
| **DATEV** | Germany, for the tax adviser's software | the entries in the layout DATEV imports |

All three cover a period you choose and use the **chart of accounts**
configured on the space — the VAT account included, which is why that
field belongs to the legal identity rather than to the export. A period
already exported is not locked: an export is a read, and it can be taken
again after a correction.

<!-- anchor: admin.integrations.overview -->
## Integrations

| Integration | What it does | Without it |
|---|---|---|
| **Payment provider** | takes a payment against an invoice | payments are recorded by hand; nothing else changes |
| **WhatsApp channel** | sends a reminder or a notice on WhatsApp | the message stays in the app's own inbox |
| **Push** | delivers notifications to a device | notifications appear when the app is opened |
| **E-invoicing platform** | transmits the structured invoice | the PDF is produced and sent by other means |

Two rules hold for all of them. **Credentials live on the workspace**,
in a table the space file and every deployment skip, so no export ever
carries a key. And **an unconfigured integration degrades, it does not
break**: the feature that needs it is switched off, the screen says so,
and nothing throws.

<!-- anchor: admin.instances.overview -->
## Instances

An **instance** is a whole DesKilo on its own database. Two workspaces —
even a development and production pair — share one; two instances share
nothing. Use one where personal data or payment credentials must be
physically separated, or where a client insists on their own database.

The **bundle** is the instance's build material: every migration in
order, the edge functions, the storage buckets and the seed. It is
regenerated whenever a migration is applied, so the bundle and the live
database are never out of step.

Create an instance from the app's wizard or from
`dart run tool/instance.dart`; both apply the bundle to an empty
database and stamp which migration it stands at. A later migration
reaches an existing instance the same way — applied in order from the
stamp forward, never re-run.

Configuration and master data travel between instances through the
**space file**, since a deployment needs one database and an instance is
the point at which there are two.

<!-- anchor: admin.trace.overview -->
## The trace

*Settings → Developer.* A ring buffer of the last 500 entries, backed by
a file on the device, with every framework and platform error hooked
into it from the first line of `main()`.

Three shapes, and the middle one is the useful one:

- **step** — a decision or a server round trip that went as intended.
- **refused** — the app declining to do the thing someone reached for.
  Warn level, and the first thing to scroll to when the report is *"I
  tapped it and nothing happened"*.
- **failed** — an exception, carrying the same fields as the step that
  was attempting it, so a red line is never orphaned from its context.

Every line is a verb followed by `key=value` pairs, so a trace can be
grepped: `grep 'act=check-in'` reads one kind of attempt end to end, and
`grep 'server='` reads every refusal the server issued, with its code,
message, details and hint in one field.

**A trace is per device.** The log that answers *"a member could not
check in"* is on that member's phone. *Export* writes it to a file
stamped with the app version and the workspace, which is what makes an
exported trace tie back to the report it answers. Scanned payloads are
recorded by **shape** — scheme, host, which parameters are present, how
long — never by value, because an invite code is a secret and a trace is
meant to be sent to someone.

**A "started" with no matching "done"** means the act never came back:
the app was killed, the request never returned, or an `await` is
hanging. That gap is the finding.
