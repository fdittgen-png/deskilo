<!-- anchor: user.invoicing.overview -->
## Tax, invoicing and accounting

For owners and billing administrators: who you are as a seller, how VAT is handled, where e-invoices go, how your documents look, and the monthly rhythm of issuing, sending and chasing invoices.

> **Careful** DesKilo prints what you declare and checks that the required details are present. It does not certify your invoices, your VAT treatment or your books. Whenever a section below says "confirm with your accountant", please do.

In this chapter:
- Your legal identity and the mentions printed on every invoice
- VAT: regime, number, rates, groups and the periodic declaration
- E-invoicing: where the machine-readable invoice is sent
- The invoice PDF template and the report editor
- Issuing and closing a month: the Invoicing screen, the month-close wizard, regrouping, shared expenses
- Payment reminders
- The invoice register, accounting exports and business analytics

<!-- anchor: user.money.legal.identity -->
### Your legal identity

**Audience:** Owner

You want your invoices to name you correctly: who you are, how you are registered and how you charge VAT.

**Steps**

1. Open [Workspace](app:/workspace-settings) and tap **Legal identity & e-invoicing**, or go straight to [Legal identity & e-invoicing](app:/legal-identity).
2. Work from the top: the VAT regime first, then the identifiers, the address and the **Invoice mentions**.
3. Tap **Save** at the bottom.

**Good to know**

- The screen shows only the fields your VAT regime needs. Change the regime and the form follows.
- Invoices already issued keep the identity they were signed with. A change applies to the next ones.
- Only owners can open this screen.

**See also:** [VAT regime](help:user.money.vat.regime) · [Organisation type](help:user.money.legal.seller-kind) · [E-invoicing](help:user.money.einvoice.overview)

<!-- anchor: user.money.legal.seller-kind -->
### Organisation type

**Audience:** Owner

You run either a business or a non-profit association, and your invoices should read accordingly.

<p><img src="images/user-money-legal-seller-kind--f.en.jpg" width="280"></p>

**Steps**

1. Open [Legal identity & e-invoicing](app:/legal-identity) and scroll to **Invoice mentions**.
2. Choose **Company / business** or **Association (non-profit)**.
3. Tap **Save**.

**Good to know**

- For an association, the example texts change (for instance a registration such as RNA instead of a trade register). Which payment clauses print depends on your country and on the customer's capacity, not on the organisation type.
- An association with no trading activity is normally outside the scope of VAT. The screen warns you if you pick "exempt" for an association; confirm the right choice with your accountant.

**See also:** [Customer capacity](help:user.money.legal.customer-capacity) · [VAT regime](help:user.money.vat.regime)

<!-- anchor: user.money.legal.customer-capacity -->
### Default customer capacity

**Audience:** Owner

Business customers and private individuals are not owed the same payment clauses. You set the default for the workspace.

<p><img src="images/user-money-legal-customer-capacity--f.en.jpg" width="280"></p>

**Steps**

1. In **Invoice mentions**, find **Default customer capacity**.
2. Choose **Not stated**, **Business** or **Consumer**.
3. Tap **Save**.

**Good to know**

- The statutory late-penalty, recovery-indemnity and discount defaults apply only to business customers of a French workspace; for other countries nothing is printed unless you wrote it. A consumer never receives the recovery indemnity.
- A member's own capacity wins over this default.
- Every invoice keeps the clauses it was issued with.

**See also:** [Late-payment penalty](help:user.money.legal.late-penalty) · [Recovery indemnity](help:user.money.legal.recovery)

<!-- anchor: user.money.legal.legal-form -->
### Legal form and capital

**Audience:** Owner

Your invoices state the legal form of your business and, where it applies, its share capital.

<p><img src="images/user-money-legal-legal-form--f.en.jpg" width="280"></p>

**Steps**

1. In **Invoice mentions**, tap **Legal form & capital**.
2. Type the line as it should print, for example "SARL au capital de 7 500 €" (an association might write "Association loi 1901").
3. Tap **Save**.

**Good to know**

- The text is printed as you type it, up to 300 characters. Check the exact wording required for your legal form with your accountant.

**See also:** [Trade register](help:user.money.legal.registration)

<!-- anchor: user.money.legal.registration -->
### Trade register

**Audience:** Owner

You show where your organisation is registered.

<p><img src="images/user-money-legal-registration--f.en.jpg" width="280"></p>

**Steps**

1. In **Invoice mentions**, tap **Trade register**.
2. Type the registration line, for example "RCS Saint-Brieuc 680 357 910". An association might enter an RNA number, and a SIRET if it has one.
3. Tap **Save**.

**Good to know**

- This line is a mention printed on the document. The identifier the e-invoice itself needs is the [company registration number](help:user.money.legal.legal-id) or the [VAT number](help:user.money.vat.number), depending on your regime.

**See also:** [Legal form and capital](help:user.money.legal.legal-form)

<!-- anchor: user.money.legal.payment-terms -->
### Payment terms

**Audience:** Owner

You state when invoices are due.

<p><img src="images/user-money-legal-payment-terms--f.en.jpg" width="280"></p>

**Steps**

1. In **Invoice mentions**, tap **Payment terms**.
2. Type your terms, for example "Payment within 30 days of the invoice date".
3. Tap **Save**.

**Good to know**

- Left empty, invoices print "Payment on receipt."
- A member can have their own payment terms; those print on that member's documents instead.
- Reminders do not read this text: they count from the invoice date plus **Days until the first reminder** in the reminder rules. The payment terms are only what the document prints.

**See also:** [Reminder rules](help:user.money.reminders.rules)

<!-- anchor: user.money.legal.late-penalty -->
### Late-payment penalty

**Audience:** Owner

You state the penalty for late payment.

<p><img src="images/user-money-legal-late-penalty--f.en.jpg" width="280"></p>

**Steps**

1. In **Invoice mentions**, tap **Late-payment penalty**.
2. Type your clause, or leave it empty.
3. Tap **Save**.

**Good to know**

- Left empty, nothing is invented for you, except for a French workspace invoicing a business customer, where the statutory wording prints (three times the legal interest rate).
- Confirm the clause that applies to your country with your accountant.

**See also:** [Default customer capacity](help:user.money.legal.customer-capacity)

<!-- anchor: user.money.legal.recovery -->
### Recovery indemnity

**Audience:** Owner

You state the fixed indemnity for collection costs.

<p><img src="images/user-money-legal-recovery--f.en.jpg" width="280"></p>

**Steps**

1. In **Invoice mentions**, tap **Recovery indemnity**.
2. Type your clause, or leave it empty.
3. Tap **Save**.

**Good to know**

- Left empty, the fixed indemnity of €40 prints only on invoices from a French workspace to a business customer.
- A consumer never receives this mention.

**See also:** [Default customer capacity](help:user.money.legal.customer-capacity)

<!-- anchor: user.money.legal.escompte -->
### Early-payment discount

**Audience:** Owner

You say whether paying early earns a discount.

<p><img src="images/user-money-legal-escompte--f.en.jpg" width="280"></p>

**Steps**

1. In **Invoice mentions**, tap **Early-payment discount**.
2. Type the conditions of your discount, or leave it empty.
3. Tap **Save**.

**Good to know**

- Left empty, invoices from a French workspace to a business customer print "No discount for early payment."; elsewhere the line is left out unless you write one.

**See also:** [Payment terms](help:user.money.legal.payment-terms)

<!-- anchor: user.money.legal.insurance -->
### Professional insurance

**Audience:** Owner

If your activity requires you to name your professional insurance, it prints on your invoices.

<p><img src="images/user-money-legal-insurance--f.en.jpg" width="280"></p>

**Steps**

1. In **Invoice mentions**, tap **Professional insurance**.
2. Type the insurer, the policy and the geographical cover as they should read.
3. Tap **Save**.

**Good to know**

- There is no default: an empty field prints nothing.
- Whether you must state it depends on your activity. Ask your accountant.

**See also:** [Special mentions](help:user.money.legal.special-mentions)

<!-- anchor: user.money.legal.special-mentions -->
### Special mentions

**Audience:** Owner

A line of your own that must appear on every invoice.

<p><img src="images/user-money-legal-special-mentions--f.en.jpg" width="280"></p>

**Steps**

1. In **Invoice mentions**, tap **Special mentions**.
2. Type the text.
3. Tap **Save**.

**Good to know**

- Nothing prints when the field is empty.
- Below the mentions, when the **Envelope address window** feature is on, **Address window** sets where the recipient's address sits so it shows through a window envelope.

**See also:** [The invoice PDF template](help:user.money.reports.invoice-template)

<!-- anchor: user.money.vat.regime -->
### VAT regime

**Audience:** Owner

You declare how your organisation stands with VAT. The choice decides which number your documents need.

<p><img src="images/user-money-vat-regime--f.en.jpg" width="280"></p>

**Steps**

1. Open [Legal identity & e-invoicing](app:/legal-identity).
2. In **VAT regime**, choose **Outside the scope of VAT**, **VAT-exempt (small-business scheme)** or **VAT-registered (charges VAT)**.
3. Tap **Save**.

**Good to know**

- Outside the scope of VAT: no VAT number is printed; the company registration number identifies you.
- Exempt or registered: your VAT number is asked for.
- Choosing the regime is a tax decision, not a software setting. Confirm it with your accountant before you issue invoices.
- In this version the app issues invoices itself for workspaces in France or Germany, to domestic customers, under the VAT-registered or the outside-the-scope regime. Invoices under the VAT-exempt regime are issued outside the app with your accountant.

**See also:** [VAT number](help:user.money.vat.number) · [Company registration number](help:user.money.legal.legal-id)

<!-- anchor: user.money.vat.reverse-charge -->
### Reverse charge for EU businesses

**Audience:** Owner

When you charge VAT and invoice a business in another EU country, the tax can be due by the customer.

<p><img src="images/user-money-vat-reverse-charge--f.en.jpg" width="280"></p>

**Steps**

1. Choose **VAT-registered (charges VAT)** as the regime.
2. Switch **Reverse charge for EU businesses** on or off.
3. Tap **Save**.

**Good to know**

- On: the app recognises a business with a VAT number in another member state. Today the app does not issue those invoices itself: you issue them outside the app with your accountant.
- Off: turn it off if you never invoice businesses abroad.
- The option appears only for the VAT-registered regime.

**See also:** [VAT treatment of a member](help:user.members.vat-treatment)

<!-- anchor: user.money.vat.due -->
### When VAT falls due

**Audience:** Owner

You choose whether VAT is counted when you issue the invoice or when you are paid.

<p><img src="images/user-money-vat-due--f.en.jpg" width="280"></p>

**Steps**

1. Choose **VAT-registered (charges VAT)** as the regime.
2. In **VAT falls due**, choose **On invoices (accrual)** or **On receipts (cash)**.
3. Tap **Save**.

**Good to know**

- On receipts, a period declares what customers paid inside it; on invoices, what you issued.
- The choice is printed on every invoice and drives the [VAT declaration](help:user.money.vat.declaration).
- Which basis applies to you is a tax question for your accountant.

**See also:** [The periodic VAT declaration](help:user.money.vat.declaration)

<!-- anchor: user.money.vat.account -->
### VAT account

**Audience:** Owner

Your accountant wants collected VAT booked on a specific account.

<p><img src="images/user-money-vat-account--f.en.jpg" width="280"></p>

**Steps**

1. Choose **VAT-registered (charges VAT)** as the regime.
2. Type your account number in **VAT account**.
3. Tap **Save**.

**Good to know**

- The accounting export books collected VAT on this account. Left empty, it uses 445710.

**See also:** [Accounting exports](help:user.invoicing.accounting-export)

<!-- anchor: user.money.vat.number -->
### VAT number

**Audience:** Owner

Your VAT identification number appears on your invoices and e-invoices.

<p><img src="images/user-money-vat-number--f.en.jpg" width="280"></p>

**Steps**

1. Open [Legal identity & e-invoicing](app:/legal-identity).
2. Type the number in **VAT number**.
3. Tap **Save**.

**Good to know**

- The field appears for the exempt and registered regimes. Outside the scope of VAT it is replaced by the company registration number.
- Your members have their own VAT number in their settings, for their documents.

**See also:** [Company registration number](help:user.money.legal.legal-id)

<!-- anchor: user.money.vat.exemption-reason -->
### Reason no VAT is charged

**Audience:** Owner

When no VAT is charged, the law usually wants the reason printed on the invoice.

<p><img src="images/user-money-vat-exemption-reason--f.en.jpg" width="280"></p>

**Steps**

1. Open [Legal identity & e-invoicing](app:/legal-identity).
2. Type the legal basis in **Why no VAT is charged**, for instance "TVA non applicable, art. 293 B du CGI".
3. Tap **Save**.

**Good to know**

- The app cannot know which basis applies to you. Take the exact wording from your accountant.
- The wording is printed on the invoice. For now the app does not issue invoices under the exempt regime itself: they are issued outside the app with your accountant.

**See also:** [VAT regime](help:user.money.vat.regime)

<!-- anchor: user.money.legal.legal-id -->
### Company registration number

**Audience:** Owner

If you are outside the scope of VAT, your registration number identifies you on e-invoices.

<p><img src="images/user-money-legal-legal-id--f.en.jpg" width="280"></p>

**Steps**

1. Set **VAT regime** to **Outside the scope of VAT**.
2. Type the number in **Company registration number**.
3. Tap **Save**.

**Good to know**

- Under the other regimes this field is replaced by the VAT number.
- An association usually uses its registration (for instance RNA, or SIRET if assigned).

**See also:** [Trade register](help:user.money.legal.registration)

<!-- anchor: user.money.legal.address -->
### Structured address

**Audience:** Owner

An e-invoice needs your address in separate parts, not as one block of text.

<p><img src="images/user-money-legal-address--f.en.jpg" width="280"></p>

**Steps**

1. Open [Legal identity & e-invoicing](app:/legal-identity).
2. Fill **Street**, **Post code** and **City**.
3. Tap **Save**.

**Good to know**

- The street starts from the address already in your workspace settings, so you complete it rather than retype it.
- Invoices cannot be issued without the workspace postal address.

**See also:** [Letterhead address](help:user.workspace.settings.address)

<!-- anchor: user.money.vat.rates -->
### Setting the rates

**Audience:** Owner · Billing administrator

You list the VAT rates your invoices may use. What members pay does not change: prices include VAT, and the tax is extracted from them.

<p><img src="images/user-money-vat-rates--f.en.jpg" width="320"></p>

**Steps**

1. Open [VAT](app:/vat) (from **Legal identity & e-invoicing**, tap **VAT rates**).
2. On an empty list, tap **Use the usual rates** (if your country has a catalogue) to start from your country's rates, or **Add a rate** and fill the name and **Rate %** (0 to 99.99).
3. Tap the star on exactly one rate to make it the default.
4. Tap **Save**.

**Good to know**

- The usual rates are a starting point. Which supply falls under which rate is a question for your accountant.
- The default rate is used by subscriptions and by anything without its own rate.
- A rate still used by an invoice or a service is kept, deactivated, rather than deleted.
- With no rate while you are VAT-registered, invoices show no tax and the XML export stays disabled.
- This screen needs the **VAT management** feature; the VAT rates entry on the legal identity screen shows only for the VAT-registered regime.

**See also:** [VAT groups](help:user.money.vat.groups) · [Change by law](help:user.money.vat.change-by-law)

<!-- anchor: user.money.vat.groups -->
### VAT groups

**Audience:** Owner · Billing administrator

A group says what kind of rate this is, so the invoice puts it in the right category.

<p><img src="images/user-money-vat-groups.en.jpg" width="320"></p>

**Steps**

1. Open [VAT](app:/vat).
2. On each rate, when the **VAT groups** feature is on, choose a **Group**: **Standard**, **Intermediate**, **Reduced**, **Super-reduced**, **Zero rate**, **Exempt**, **Not subject**, **Deposit (outside VAT)** or **Excise-bearing**.
3. For an exempt or not-subject group, fill the **Exemption reason** that appears.
4. Tap **Save**.

**Good to know**

- **What falls in each group** lists examples for your country, as a guide only.
- A line outside VAT, such as a refundable deposit, cannot share a document with taxed lines; issue it on its own.

**See also:** [Setting the rates](help:user.money.vat.rates)

<!-- anchor: user.money.vat.change-by-law -->
### Change a rate by law

**Audience:** Owner · Billing administrator

A rate changes from a given date. Old supplies keep the old value; the new one applies from that day.

<p><img src="images/user-money-vat-change-by-law.en.jpg" width="320"></p>

**Steps**

1. Open [VAT](app:/vat) and make sure the rate is saved.
2. Tap the **Change by law** button on the rate.
3. Type **New rate %** and the **Effective date (YYYY-MM-DD)**.
4. Tap **Save** in the dialog, then **Save** on the screen.

**Good to know**

- The old rate closes on that date and a new one opens, with the star moved along if it was the default.
- Nothing already issued is re-pointed.

**See also:** [Setting the rates](help:user.money.vat.rates)

<!-- anchor: user.money.vat.declaration -->
### The periodic VAT declaration

**Audience:** Owner

You want a ready summary of the VAT of a period to file with the tax office or hand to your accountant.

<p><img src="images/user-money-vat-declaration.en.jpg" width="280"></p>

**Steps**

1. Open [VAT declaration](app:/vat-declarations).
2. Choose the **Period** and tap **Generate**.
3. Open the result with **PDF** or **XML export**, or look at **VAT report (PDF)** and **VAT report (CSV)**.
4. Once you have filed it yourself, tap **Mark as filed**.

**Good to know**

- It exists only under the VAT-registered regime. The note at the top says whether the period counts invoices or receipts.
- It is a filing aid generated from the period's issued invoices, not tax advice. Verify it against your accounting before filing.
- A filed declaration can no longer be changed.
- Where a platform is set up in [E-invoicing](help:user.money.einvoice.overview), a **Transmit** button can send it.

**See also:** [When VAT falls due](help:user.money.vat.due) · [Accounting exports](help:user.invoicing.accounting-export)

<!-- anchor: user.money.einvoice.overview -->
### The e-invoicing platform

**Audience:** Owner · Billing administrator

You tell DesKilo where to post your invoices as machine-readable files.

<p><img src="images/user-money-einvoice-overview--f.en.jpg" width="280"></p>

**Steps**

1. Open [E-invoicing platform](app:/einvoice-config) (also reachable from **Legal identity & e-invoicing**).
2. Fill **Upload URL** and **Token or credential**, and the two optional fields if your platform asks for them.
3. Tap **Save**. **Remove the platform** clears the settings.

**Good to know**

- Any platform that accepts an upload with a token works: an approved platform, a Peppol access point, a national platform.
- The token is stored on the server and never shown again.
- The valid file is an EN 16931 invoice. Whether your country requires a platform, and which, is something to confirm with your accountant.

**See also:** [Sending an e-invoice](help:user.money.einvoice.send) · [Legal identity](help:user.money.legal.identity)

<!-- anchor: user.money.einvoice.endpoint -->
### Upload URL

**Audience:** Owner · Billing administrator

The address at which your platform receives invoices.

<p><img src="images/user-money-einvoice-endpoint--f.en.jpg" width="280"></p>

**Steps**

1. Open [E-invoicing platform](app:/einvoice-config).
2. Paste the address in **Upload URL**, exactly as your platform documents it.
3. Tap **Save**.

**Good to know**

- It comes from your platform's documentation or your provider.

**See also:** [Token or credential](help:user.money.einvoice.token)

<!-- anchor: user.money.einvoice.token -->
### Token or credential

**Audience:** Owner · Billing administrator

The secret that proves to the platform that the upload is yours.

<p><img src="images/user-money-einvoice-token--f.en.jpg" width="280"></p>

**Steps**

1. Open [E-invoicing platform](app:/einvoice-config).
2. Paste the key in **Token or credential**.
3. Tap **Save**.

**Good to know**

- Once saved, the screen says "A token is stored". Type a new one only to replace it.
- It is kept on the server and never comes back out.

**See also:** [Auth header](help:user.money.einvoice.auth-header)

<!-- anchor: user.money.einvoice.auth-header -->
### Auth header

**Audience:** Owner · Billing administrator

The name of the header that carries the token.

<p><img src="images/user-money-einvoice-auth-header--f.en.jpg" width="280"></p>

**Steps**

1. Open [E-invoicing platform](app:/einvoice-config).
2. If your platform expects another header than the standard one, type its name in **Auth header (default Authorization)**.
3. Tap **Save**.

**Good to know**

- Left empty, **Authorization** is used.

**See also:** [File field name](help:user.money.einvoice.file-field)

<!-- anchor: user.money.einvoice.file-field -->
### File field name

**Audience:** Owner · Billing administrator

The name of the form field that carries the invoice file.

<p><img src="images/user-money-einvoice-file-field--f.en.jpg" width="280"></p>

**Steps**

1. Open [E-invoicing platform](app:/einvoice-config).
2. If your platform expects another field name, type it in **File field name (default file)**.
3. Tap **Save**.

**Good to know**

- Left empty, **file** is used.

**See also:** [Upload URL](help:user.money.einvoice.endpoint)

<!-- anchor: user.money.einvoice.customer-delivery -->
### Customer delivery service

**Audience:** Owner · Billing administrator

Your customer may receive its invoices elsewhere than a government platform: its own Peppol access point, portal or agreed upload service.

<p><img src="images/user-money-einvoice-customer-delivery--f.en.jpg" width="280"></p>

**Steps**

1. Open [E-invoicing platform](app:/einvoice-config).
2. In **Customer delivery service**, fill the same four fields as above.
3. Tap **Save**.

**Good to know**

- It is separate from the government platform. Both can be set up, and each invoice offers both sends.

**See also:** [Sending an e-invoice](help:user.money.einvoice.send)

<!-- anchor: user.money.einvoice.uat -->
### UAT endpoint and token

**Audience:** Owner · Billing administrator

You want to rehearse before sending real invoices.

<p><img src="images/user-money-einvoice-uat--f.en.jpg" width="280"></p>

**Steps**

1. Open [E-invoicing platform](app:/einvoice-config).
2. Under **Test environments (UAT / Dev)**, fill **UAT upload URL** and **UAT token or credential**.
3. Tap **Save**.

**Good to know**

- The choice of environment appears at send time only while developer mode is on.
- A test send is logged as a test send.

**See also:** [Dev endpoint and token](help:user.money.einvoice.dev)

<!-- anchor: user.money.einvoice.dev -->
### Dev endpoint and token

**Audience:** Owner · Billing administrator

A second test endpoint, for development.

<p><img src="images/user-money-einvoice-dev--f.en.jpg" width="280"></p>

**Steps**

1. Open [E-invoicing platform](app:/einvoice-config).
2. Under **Test environments (UAT / Dev)**, fill **Dev upload URL** and **Dev token or credential**.
3. Tap **Save**.

**Good to know**

- Same rules as for UAT. The real submission always goes to the production endpoint.

**See also:** [UAT endpoint and token](help:user.money.einvoice.uat)

<!-- anchor: user.money.einvoice.send -->
### Sending an e-invoice

**Audience:** Owner · Billing administrator

You want to hand an issued invoice over in its machine-readable form.

**Steps**

1. Open an invoice in [Invoicing](app:/invoices) and tap **E-invoice (XML)**.
2. Read the check at the top of the sheet: it says whether the file is ready or what is missing.
3. Tap **Send to the government platform**, **Send to the customer's service**, or download or share the file (**Download Factur-X (PDF)** carries the XML inside the PDF).

**Good to know**

- If something is missing, the sheet lists it. **Complete the legal identity** takes you to the screen that fixes it.
- An invoice signed before you completed your identity keeps what it was issued with. Mark it erroneous and issue a replacement if it matters.
- Which channel a customer must use depends on your country and the customer. Confirm with your accountant.

**See also:** [The e-invoicing platform](help:user.money.einvoice.overview) · [The Invoicing screen](help:user.invoicing.hub)

<!-- anchor: user.money.reports.invoice-template -->
### The invoice PDF template

**Audience:** Owner · Billing administrator

You want your invoices to look like yours: logo, layout, wording.

<p><img src="images/user-money-reports-invoice-template.en.jpg" width="280"></p>

**Steps**

1. Open [Reports](app:/reports?section=templates) and the **Templates** tab.
2. Tap **Report editor**.

**Good to know**

- The template changes the PDF only. The e-invoice XML is never touched.
- Anyone with permission to design documents can do this.
- A template that does not render never blocks a document: the built-in layout takes over.

**See also:** [The report editor](help:user.money.reports.editor)

<!-- anchor: user.money.reports.editor -->
### The report editor

**Audience:** Owner · Billing administrator

You design a document on a page, instead of writing code.

<p><img src="images/user-money-reports-editor.en.jpg" width="280"></p>

**Steps**

1. Open [Report editor](app:/report-editor).
2. Pick the document with the chips (Invoice, Proforma, Statement, reminders and the other reports).
3. In **Design**, tap a line to edit it, add lines, or drag to reorder. Tap **Preview** to see it with your data.
4. Tap **Save**.

**Good to know**

- The **Markup** mode edits the same bands as text.
- **Insert image** places a logo, stamp or signature from the image library.
- **Quick preview** renders instantly with your newest invoice, or sample data if there is none. **Reset to default** brings back the built-in layout.
- **Export this design** and **Import a design** carry a design in and out as a file. **Positioned layout (XML)** is for documents that must match a window envelope or a national form.
- Leaving with unsaved work asks first.

**See also:** [Templates and presets](help:user.money.reports.presets) · [Languages](help:user.money.reports.languages)

<!-- anchor: user.money.reports.presets -->
### Ready-made templates

**Audience:** Owner · Billing administrator

You start from a finished design and change what you want.

<p><img src="images/user-money-reports-presets.en.jpg" width="280"></p>

**Steps**

1. Open [Report editor](app:/report-editor) and pick a document.
2. Tap **Templates** and choose **Professional**, **Classic**, **Simple**, **Detailed** or **Formal letter**.
3. Confirm the replacement if the app asks, then edit and **Save**.

**Good to know**

- Replacing a layout can be undone with **Undo**.
- The structural reports (chart of accounts, badges, QR cards) have one shipped layout.
- Invoice templates already carry your legal mentions. They still print only what you entered under [Invoice mentions](help:user.money.legal.identity).

**See also:** [The report editor](help:user.money.reports.editor)

<!-- anchor: user.money.reports.languages -->
### One design per language

**Audience:** Owner · Billing administrator

Your members read their documents in their own language.

<p><img src="images/user-money-reports-languages--f.en.jpg" width="280"></p>

**Steps**

1. Open [Report editor](app:/report-editor).
2. Under the document, choose **Default (all languages)** or one of **EN**, **FR**, **DE**, **ES**, **IT**.
3. Edit the bands for that language and **Save**. **Use the default for this language** removes an own design.

**Good to know**

- A dot on a language means it has its own design; otherwise it inherits the default.
- A member's document prints in their language when a design exists for it, otherwise in the workspace default.

**See also:** [Workspace language](help:user.workspace.settings.language)

<!-- anchor: user.invoicing.hub -->
### The Invoicing screen

**Audience:** Owner · Billing administrator

You see at a glance what to issue, what to collect and what is closed.

<p><img src="images/user-invoicing-hub.en.jpg" width="280"></p>

**Steps**

1. Open [Invoicing](app:/invoices).
2. Read the strip: **To issue**, **To collect**, **To confirm**, **Closed**.
3. Work in the three tabs: **To invoice** (members with something tracked, not yet invoiced), **Open** (issued, unpaid) and **Archive** (paid or closed).
4. Tap the tools icon for the other tools.

**Good to know**

- You see invoices for the whole workspace. Your own are in your finances, under **My finances**.
- Invoices are never edited or deleted: a wrong one is marked erroneous and replaced.
- The **How invoicing works** entry explains who moves at each step.

**See also:** [New invoice](help:user.invoicing.new-invoice) · [Open invoices](help:user.invoicing.open)

<!-- anchor: user.invoicing.new-invoice -->
### Issue an invoice

**Audience:** Owner · Billing administrator

You invoice a member for a month.

<p><img src="images/user-invoicing-new-invoice.en.jpg" width="280"></p>

**Steps**

1. In [Invoicing](app:/invoices), tap **New invoice**, or **Issue** on a row of **To invoice**.
2. Pick the **Member** and the month. The positions come from what was tracked.
3. Switch on **Include the detailed annex (check-ins, services, payments)** if you want it.
4. Tap **Issue invoice**. In **To invoice**, **Invoice all** issues every row.

**Good to know**

- Invoices are derived from tracked data and cannot be composed by hand. The bottom line is the **Balance due**.
- A month can only be invoiced once per member, and a month still running warns you that positions may change.
- If a required detail is missing, **Complete these details before issuing** lists it (address, VAT number, exemption basis, VAT rate; also the workspace country, which must be France or Germany).
- In this version, issuing in the app is available for workspaces in France or Germany, for domestic customers. Cross-border, reverse-charge, export and exempt-buyer invoices are issued outside the app with your accountant.
- An issued invoice is signed and immutable.

**See also:** [Month-close wizard](help:user.invoicing.wizard)

<!-- anchor: user.invoicing.open -->
### Chase and settle open invoices

**Audience:** Owner · Billing administrator

You follow what is unpaid and close it properly.

<p><img src="images/user-invoicing-open.en.jpg" width="280"></p>

**Steps**

1. In [Invoicing](app:/invoices), open the **Open** tab and tap an invoice.
2. Use the actions it offers: **Send a reminder**, **Mark as paid** (match a registered payment), **Cancel outstanding amount**, **Mark erroneous**, or share the PDF.
3. Paid invoices move to **Archive**.

**Good to know**

- An invoice is paid once a real payment is matched to it. A difference needs a note, or a credit note for the excess.
- Cancelling an outstanding amount goes through validation.
- **Mark erroneous** cannot be undone. Do it before payment, never after.

**See also:** [Reminder rules](help:user.money.reminders.rules) · [Regroup invoices](help:user.invoicing.settlement)

<!-- anchor: user.invoicing.wizard -->
### The month-close wizard

**Audience:** Owner · Billing administrator

One guided path for the money routine: issue, send, remind, register payments, match and close.

<p><img src="images/user-invoicing-wizard.en.jpg" width="280"></p>

**Steps**

1. In [Invoicing](app:/invoices), tap **Month-close wizard** (or open the [Invoicing wizard](app:/invoicing/wizard)).
2. Choose the run: **Start of month** (subscriptions members pay ahead, for the coming month) or **End of month** (usage, consumption and extra charges of the month just ended). The date proposes one.
3. Follow the steps: **Review**, **Issue**, **Send**, **Remind**, **Payments**, **Match**, **Close**, **Summary**.
4. Tap **Next** at each step, and **Finish** at the end.

**Good to know**

- You can untick a member to leave them out of a batch; members already covered show as done.
- **Summary** lists what the run did, and what is still open and whose move it is.
- A step with nothing to do says so.

**See also:** [The Invoicing screen](help:user.invoicing.hub) · [Regroup invoices](help:user.invoicing.settlement)

<!-- anchor: user.invoicing.settlement -->
### Regroup invoices into one

**Audience:** Owner · Billing administrator

A member has several open invoices and should pay a single one.

<p><img src="images/user-invoicing-settlement.en.jpg" width="280"></p>

**Steps**

1. In [Invoicing](app:/invoices), tap the tools icon and **Regroup into one invoice**.
2. Choose at least two open invoices of the same member.
3. Confirm. You are asked whether to attach the regrouped invoices.

**Good to know**

- The new invoice is what is owed and chased. The originals stay readable behind it.
- Lines and VAT are carried over; the VAT declaration counts the originals once.

**See also:** [Open invoices](help:user.invoicing.open)

<!-- anchor: user.invoicing.shared-expense -->
### Distribute a shared expense

**Audience:** Owner · Billing administrator

A cost shared by the community is split among members.

<p><img src="images/user-invoicing-shared-expense.en.jpg" width="280"></p>

**Steps**

1. In [Invoicing](app:/invoices), tap the tools icon and **Distribute an expense**.
2. Describe **The expense**, then choose **Split by**: **Equal**, **Subscription**, **Usage** or **Custom key**.
3. Check the **Shares**, untick anyone to **Leave out**, and tap **Book the shares**.

**Good to know**

- Once booked (after validation, if a rule asks for it), the shares land as lines on each member's next usage invoice.
- **Reversal — give back as credit notes** returns the money.
- **Remember this rule** proposes the adjusted rule again next month.

**See also:** [The month-close wizard](help:user.invoicing.wizard)

<!-- anchor: user.money.reminders.rules -->
### Reminder rules

**Audience:** Owner · Billing administrator

You decide when and how often an overdue invoice is chased.

<p><img src="images/user-money-reminders-rules.en.jpg" width="280"></p>

**Steps**

1. In [Invoicing](app:/invoices), tap the tools icon and **Reminder rules**.
2. Set **Number of reminder levels**, **Days until the first reminder** and **Days between reminders**.
3. Tap **Save**.

**Good to know**

- Reminders print the payment mentions you set up.
- A reminder is recorded for the invoice and shows as a **Reminded** badge.

**See also:** [Automatic reminders](help:user.money.reminders.automatic) · [Payment terms](help:user.money.legal.payment-terms)

<!-- anchor: user.money.reminders.automatic -->
### Automatic reminders

**Audience:** Owner · Billing administrator

You want reminders to leave on their own.

<p><img src="images/user-money-reminders-automatic.en.jpg" width="280"></p>

**Steps**

1. Open **Reminder rules** in the Invoicing tools.
2. Switch **Automatic reminders** on.
3. Tap **Save**.

**Good to know**

- Once a day, invoices past their recorded payment term get their next level, for the amount still outstanding.
- Never while a payment is pending or the invoice is on hold. Invoices without a recorded term are left to you.
- Off: you send each reminder yourself.

**See also:** [Reminder rules](help:user.money.reminders.rules)

<!-- anchor: user.invoicing.register -->
### The invoice register

**Audience:** Owner · Billing administrator

All invoices in one sortable list.

<p><img src="images/user-invoicing-register.en.jpg" width="280"></p>

**Steps**

1. Open [Invoice register](app:/invoice-register).
2. Pick the **Year** or **All years**.
3. Sort by **Date**, **Name** or **Amount**; the total is at the bottom.

**Good to know**

- Members see their own; people who issue invoices see the workspace.
- The accounting export starts here.

**See also:** [Accounting exports](help:user.invoicing.accounting-export)

<!-- anchor: user.invoicing.accounting-export -->
### Accounting exports

**Audience:** Owner · Billing administrator

You hand the year's invoices and payments to your accountant.

<p><img src="images/user-invoicing-accounting-export.en.jpg" width="280"></p>

**Steps**

1. Open [Invoice register](app:/invoice-register) and tap **Accounting export**.
2. In **Export for accounting**, choose a format, such as **FEC (France, required in an audit)**, **SAF-T (XML, international)**, **Accounting CSV**, **Audit trail** or **Year archive (zip)**. The list depends on your country; a few countries add their own, such as **DATEV (Buchungsstapel)**.
3. In **Before you save**, read the check, then tap **Save file and report**.

**Good to know**

- Each format says what it claims. "For your accountant to import and review — not a filing" is not a tax return.
- DesKilo keeps no double-entry ledger: the files are rebuilt from invoices and payments, and your accountant completes them.
- A file is blocked until problems in the source are fixed.
- Some formats note that DesKilo is not certified software in your country.

**See also:** [VAT account](help:user.money.vat.account) · [The invoice register](help:user.invoicing.register)

<!-- anchor: user.invoicing.bi -->
### Business analytics

**Audience:** Owner · Billing administrator

You look at how the workspace performs.

**Steps**

1. Open [Business analytics](app:/bi), or **Reporting** in the menu.
2. Choose **Period length** (**Month**, **Quarter**, **Year**), a comparison, and a grouping where offered.
3. Read the analyses by area, such as **Finance** (**Invoiced**, **Collected**) and **Space and capacity**.
4. Save a view under **Views**, or tap **Export as PDF**.

**Good to know**

- You only see analyses you are allowed to read.
- Collected is payments matched to invoices. It is not a profit: no costs are in the figure.
- The current period is partial; its figures still change.

**See also:** [The Invoicing screen](help:user.invoicing.hub)
