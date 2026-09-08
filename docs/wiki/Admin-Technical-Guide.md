# Admin guide — the technical side

For whoever keeps a DesKilo space running: the documents it prints, the
files it exchanges, the services it talks to, and the database under it.
The everyday configuration is in the
[configuration guide](Admin-Configuration-Guide); what a member sees is
in the [user guide](User-Guide).

*This guide is being written; sections carry their outline and grow with
each release. Screenshots arrive through the documentation pipeline —
`<!-- image: … -->` marks a slot whose capture is still missing.*

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

The quick way to design: four bands of markup, each rendered per page.
Text, headings, tables, rules, two-column blocks, and the Liquid a band
may use.

<!-- anchor: admin.reports.layouts -->
### Positioned layouts

The exact way: an XML layout that places every element at a millimetre,
for documents that must satisfy a window envelope or a national form.
Elements, frame attributes, units, and the page contract.

<!-- anchor: admin.reports.placeholders -->
### The vocabulary

Every placeholder the engine knows, per document family, with the loops
(`lines`, `vat`, `usage_records`, …) and the fields each row carries.
`dart run tool/report.dart describe` prints the current list — it is
generated from the same registry the renderer reads, so it can never be
out of date.

<!-- anchor: admin.reports.operators -->
### Liquid: conditions, loops, filters

`{{ field }}`, `{% if field != "" %}…{% endif %}`,
`{% for line in lines %}…{% endfor %}`, and the filters a design may use.
The rule that catches everyone: an absent placeholder is the empty
string, never nil, so a guard on `!= ""` behaves.

<!-- anchor: admin.reports.window -->
### The window-envelope contract

Sender at 20/20 mm, recipient at 110/45 in an 85×40 mm window, body from
90 mm, footer on every page, continuation from page two. Proven on the
rendered PDF, not by eye.

<!-- anchor: admin.reports.cli -->
### The command line

`dart run tool/report.dart check <layout.xml>` measures a design against
the contract and exits non-zero when ink lands in the window band;
`render`, `sample` and `describe` complete the set.

<!-- anchor: admin.einvoice.overview -->
## Electronic invoicing

<!-- anchor: admin.einvoice.formats -->
### CII, UBL, Factur-X

What the app produces, which standard each satisfies, and how the PDF and
the XML travel together.

<!-- anchor: admin.einvoice.readiness -->
### The readiness gate

What the app refuses to send and why — a missing buyer identifier, an
exemption without its code, a category the seller's regime cannot carry.

<!-- anchor: admin.einvoice.platforms -->
### Platforms and credentials

Configuring a transmission platform, the test endpoint, and what is
recorded on the invoice's transmission history.

<!-- anchor: admin.exports.accounting -->
## Accounting exports

FEC, SAF-T and DATEV: what each contains, the accounts they use, and the
period they cover.

<!-- anchor: admin.integrations.overview -->
## Integrations

Payment providers, the WhatsApp channel, push. Where the credentials
live, why none of them is ever in the space file, and what happens when
one is not configured.

<!-- anchor: admin.instances.overview -->
## Instances

Creating a new instance with its own database from the app's wizard or
from `dart run tool/instance.dart`, what the bundle carries, and how a
migration reaches an existing instance.

<!-- anchor: admin.trace.overview -->
## The trace

Every guarded action writes its start and its end; every provider failure
and every uncaught error is recorded. Where to read it, what a "started"
with no "done" means, and how to export it.
