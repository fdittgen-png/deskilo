<!-- anchor: setup.reports.overview -->
## Documents and reports

**Audience:** Owner · Co-owner · Billing administrator

Everything DesKilo prints or exports comes from one engine and one place to design it. This chapter tells you which documents exist, the order in which to prepare them, what you may hand to your accountant, and where an AI assistant can help you and where it must not. The clicks are in the user guide; here you get the reasons and the order.

The running example is the demo space *Atelier du Marché*.

<!-- anchor: setup.reports.documents -->
### The documents the app produces

**Audience:** Owner · Billing administrator

You want to know what exists before you design anything, and who receives each document.

<p><img src="images/setup-reports-hub.en.jpg" width="280"></p>

Every document is one *kind*. Each kind has its own design, so changing the invoice never changes the statement.

| Document | Who receives it | Where you find it |
|---|---|---|
| Invoice and credit note (one shared design) | The member, or the customer of an invoiced month | [Invoicing](help:user.invoicing.hub) |
| Proforma | A member who needs a quote or a prepayment request | Same screen |
| Statement | The member (their account over a period) | [The statement](help:user.money.statement) |
| Agreement | The member (the negotiated conditions) | [Price negotiation](help:user.money.negotiation) |
| Payments, usage | The member, the billing administrator | [Payments](help:user.money.payments) · [Usage](help:user.money.usage) |
| Reminder letters, level 1 to 9 | The member with an overdue invoice | [Reminder rules](help:user.money.reminders.rules) |
| Workspace report and workspace status | You, the board, an auditor | **Reports** |
| VAT declaration | You, then the tax platform | [The periodic VAT declaration](help:user.money.vat.declaration) |
| Badges, space QR codes | Members at the door, your walls | [Space QR codes](help:user.workspace.export.space-qr) · [Badges](help:user.badges.nfc) |

**Good to know**

- The **Reports** screen groups them under **Financial reports**, **Workspace documents**, **Business analytics** and **Templates**, depending on your permissions.
- A few reports (chart of accounts, badges, QR cards) have one shipped layout. The others can be redesigned.
- Documents drawn from a test space carry a watermark that says so. See [What a test space is for](help:user.advanced.test-space).

**See also:** [Reports](help:user.money.reports) · [The invoice PDF template](help:user.money.reports.invoice-template)

<!-- anchor: setup.reports.designer -->
### The designer, in owner terms

**Audience:** Owner · Billing administrator

You want a letter that looks like yours without learning a language of markup.

<p><img src="images/setup-reports-professional.en.jpg" width="280"></p>

A document is a page made of **bands**. The *header* carries your letterhead and the recipient. The *body* carries the lines. The *continuation* strip starts on page two, and the *footer* repeats on every page with your payment terms and legal mentions. You edit them in **Design** and check them in **Preview**; **Markup** shows the same bands as text for the day you need it.

| Piece | What it gives you | Choose it when |
|---|---|---|
| Presets (**Professional**, **Classic**, **Simple**, **Detailed**, **Formal letter**) | A finished design to start from. The presets differ for invoices, proformas, statements, agreements and reminders; structural documents have one shipped layout | Always: start from **Professional** and change little |
| One design per language | A member reads the document in their own language | Your members do not all read one language |
| Letterhead and window envelope | Sender, recipient and body placed where a window envelope expects them | You post invoices on paper |
| Positioned layout (XML) | Each element placed by millimetres, for a national form | A document must match a fixed form |
| Image library | A logo, a stamp or a signature reused across designs | You have a logo |
| Design exchange | A design written to a file and read back | A person or a tool outside the app edits it |

Two facts keep you from surprises. The letter standard prints a recipient in the window on the right for a French space and on the left for a German one, unless you override it. And a design that fails to render never blocks a document: the built-in layout takes over.

> **Careful** The wording in a design is not legal advice. Appearance and translation alone do not establish legal compliance or satisfy an electronic-invoicing obligation. What an invoice must say is decided under [Your legal identity](help:user.money.legal.identity), and confirmed by your accountant.

**See also:** [The report editor](help:user.money.reports.editor) · [Ready-made templates](help:user.money.reports.presets) · [One design per language](help:user.money.reports.languages)

<!-- anchor: setup.reports.sequence -->
### The sequence to follow

**Audience:** Owner · Billing administrator

You are about to design documents and want to do it once, in the right order.

<p><img src="images/setup-reports-presets.en.jpg" width="280"></p>

**Steps**

1. Fix your legal identity first: organisation type, address, registration, VAT regime and the special mentions. A design prints only what you entered there. See [Your legal identity](help:user.money.legal.identity).
2. Open [Report editor](app:/report-editor), pick the document and start from **Professional** under **Templates**.
3. Add a language version for each language your members read. Choose **EN**, **FR**, **DE**, **ES** or **IT** under the document. See [One design per language](help:user.money.reports.languages).
4. Check each one with **Quick preview**. It uses your newest invoice, or sample data when there is none.
5. Rehearse on a test space: enter it, issue a trial invoice, print it and send it to your accountant. See [What a test space is for](help:user.advanced.test-space).
6. Freeze the design before the first invoice. Write down what you decided, then change a design only when a rule changes.

**Good to know**

- Replacing a layout can be undone with **Undo** until you leave the editor.
- An issued invoice is a frozen document. Changing the design later changes new documents, never the ones already issued.
- With the same wording in two languages, ask someone who reads the second language to read the preview.

> **Careful** The invoice number and the legal mentions printed on an invoice become permanent with the first issued invoice. Settle them before it, not after.

**Result:** every document you will send looks like yours, in each language, and has been read once by someone other than you.

**See also:** [Your legal identity](help:user.money.legal.identity) · [The invoice PDF template](help:user.money.reports.invoice-template)

<!-- anchor: setup.reports.accountant -->
### What you hand your accountant

**Audience:** Owner · Billing administrator

You want your accountant to have what they need, and to know what the app does not claim.

<p><img src="images/setup-reports-export.en.jpg" width="280"></p>

Start from the [Invoice register](app:/invoice-register), which lists every invoice with its status, and tap **Accounting export**. Each format says in the sheet what it claims.

| File | What it claims | What it does not claim |
|---|---|---|
| FEC | The French format an audit asks for, rebuilt from invoices and payments | Complete books. Your accountant completes them |
| DATEV | An exchange file for German accountants' software, read and posted by a person | A filing, or a handover for a tax audit |
| SAF-T | The international structure, deliberately partial: invoices and payments, no general ledger | A complete accounting file. It says so in its header |
| SAF-T PT, Sage 50 | A Portuguese regulatory format (uncertified) and a British/Irish exchange format, depending on your country | A filing or a certification |
| Accounting CSV, Audit trail, Year archive (zip) | A reading aid for your accountant | A filing |

The list of formats depends on your country. FEC and DATEV ask for your account numbers, and FEC also for your registration number: have them ready. The VAT figures for the period are in [The periodic VAT declaration](help:user.money.vat.declaration).

*What the app does not do*

- It keeps invoices, payments and a running account per member. It does not keep a double-entry ledger over a chart of accounts, so it cannot replace accounting software.
- Some obligations remain with you and your accountant: complete books, certified software where your country demands it, and the target authority's acceptance.
- A file is blocked until the problems in the source are fixed.

**Good to know**

- Exporting is a read. You can repeat it for any period.
- Prepare a short brief for your accountant before the first invoice: your VAT regime, when VAT falls due, the numbering you chose and the exports you will want. See [AI help](help:setup.reports.ai).

**See also:** [Accounting exports](help:user.invoicing.accounting-export) · [The invoice register](help:user.invoicing.register) · [VAT account](help:user.money.vat.account)

<!-- anchor: setup.reports.analytics -->
### Business analytics in outline

**Audience:** Owner · Billing administrator

You want to see how the space performs once it runs, without a spreadsheet.

<p><img src="images/setup-reports-documents.en.jpg" width="280"></p>

**Business analytics** shows figures by area: invoiced and collected, occupancy and capacity. You choose a period (month, quarter or year), compare it with another, save a view and export it as a PDF. You see only the analyses your role may read.

Collected is payments matched to invoices. It is not a profit, because no costs are in the figure, and the current period is partial.

For a document about the whole space, the **Workspace documents** tab holds the **Workspace report**, **Space QR codes (PDF)**, **Export data (Excel)** and **Export configuration (PDF)**. Use the last two as a recovery copy before a big change.

**See also:** [Business analytics](help:user.invoicing.bi) · [Exports](help:user.workspace.export.workspace-report)

<!-- anchor: setup.reports.ai -->
### Help from an AI assistant

**Audience:** Owner · Co-owner

An AI chat tool can save you hours on the words around your setup. It cannot be the one who decides what is legally or fiscally right. This section is about the tools you use outside DesKilo; the assistant connection inside the app is described at the end.

*What an outside tool is good for*

- Drafting the invitation message you send to your first members. See [The invitation message](help:user.workspace.settings.invitation-message). The placeholders such as the first name or the invite link stay as they are.
- Wording the special mentions you will submit to your accountant, as a draft to check, never as a final text.
- Translating a design's wording into another language, so that you only have to review it.
- Explaining a report or a statement to a member in plain words.
- Preparing the brief of your choices for your accountant: country, organisation type, VAT regime, numbering, exports.
- Drafting the picture behind your floor plan, from photographs, in an image tool.

*What it must not decide*

- The legal mentions of an invoice, the VAT treatment of an activity, the reason no VAT is charged, and the VAT rates.
- Anything that becomes permanent: an invoice number format, a VAT regime, the currency, an issued invoice.
- Whether something is compliant. A confident answer is not a verified one, and your accountant is.

*The safe workflow*

1. Ask the tool for a draft. Give it a scenario, not your members' names or any personal data.
2. Paste the draft into the field, in the **Report editor** or in the settings.
3. Look at it in **Preview** with sample data.
4. Send the text that has legal weight to your accountant and wait for the answer.
5. Try the whole flow on a test space before the real one.

> **Careful** Do not paste a token, a password, a bank number or a member's personal data into an outside tool.

*DesKilo's own assistant connection*

The app lets an assistant such as Claude or ChatGPT act for a member through a protocol called MCP. It is off by default and is a feature you switch on (**MCP interface**, see [A feature switch](help:user.features.switch)). It is made in layers, so no one person can open everything.

<p><img src="images/setup-reports-assistants.en.jpg" width="280"></p>

| Layer | Who | What they do |
|---|---|---|
| The installation | The operator | Turns assistants on for the installation. |
| The workspace | You, the owner | Switch the feature on, then choose in [What assistants may do](help:user.advanced.assistants-policy) which services are offered and whether an assistant sees own records only or workspace-wide. |
| The database | A database administrator | Approves each person's request. |
| The member | Each member | Asks once for approval and chooses this workspace. |
| A request with impact | The member, on their device | Confirms the exact request, which still follows your validation rules. |

A member's assistant works on that member's own records: find and describe free places, favourites and ratings, book, change or cancel one's own reservation, ask to delete a started booking, check in and out, read one's statement and invoices, and list and answer the validations one is asked for. A few requests (invoice issue, invoice void, refund, member status change, subscription share) are for staff only: they need staff rights, the person's confirmation in the app, and then your validation rules. It has no operation that configures a space: it cannot switch a feature on, set a tariff, change a role or build a plan. It cannot set your space up for you, and it acts only within what you expose.

**Good to know**

- Switching assistants on grants nobody anything by itself.
- Each approval expires; the screen tells how many days remain.
- Read the steps in [Approvals and confirmations for assistants](help:user.advanced.assistants-approve).

**See also:** [Assistants: what they are](help:user.advanced.assistants) · [Connect an assistant](help:user.advanced.assistants-connect)

<!-- anchor: setup.reports.developer -->
### Working with a developer: the design file and the report tool

**Audience:** Owner · Operator

Someone technical is helping you, and a design must be edited or proved outside the app.

**Steps**

1. In [Report editor](app:/report-editor), use **Export this design** to write the design as one file. The file says what its fields mean and which placeholders exist. **Import a design** reads it back; a file for another report, or from a newer version, is refused with the reason.
2. A developer can proof the design from a terminal with the report tool, described in the technical administrator's guide: `check` measures a layout against the window-envelope contract and exits non-zero when ink lands in the window; `render` makes the PDF; `sample` writes a data file with every placeholder; `describe` lists the vocabulary.
3. Back in the app, import the file, preview it with **Quick preview** and **Save**.

**Good to know**

- The design exchange is a feature (**Export and import report designs**), under the report features of [Features](app:/features). Switch it on first.
- The tool needs the source code of the app; it is for the person who runs your installation, not for daily use.

**See also:** [The report editor](help:user.money.reports.editor) · [The invoice PDF template](help:user.money.reports.invoice-template)
