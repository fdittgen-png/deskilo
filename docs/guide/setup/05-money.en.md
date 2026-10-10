<!-- anchor: setup.money.overview -->
## Money and tax

For owners and billing administrators who are about to decide how a space is paid for. This chapter is about the decisions and their order; the clicks are in the user guide, and every section links to them.

> **Careful** DesKilo records, calculates and prints what you declare, and it checks that the required details are present. It does not certify your invoices, your VAT treatment or your books. Wherever this chapter says "ask your accountant", please do.

In this chapter:
- Whether members pay at all, and who issues the invoices
- How a tariff is built, with figures from the demo space *Atelier du Marché*
- How members pay you
- Your legal identity, and the questions to bring to your accountant
- Manual or automatic invoicing, reminders, and VAT in outline
- The money decisions that cannot be taken back, and how to rehearse safely

<!-- anchor: setup.money.decide -->
### Decide first: do members pay, and who issues the invoices

**Audience:** Owner

You choose how far DesKilo goes in your money. Everything else in this chapter follows from this one choice, and it is easy to change upwards later, hard to change downwards once invoices exist.

<p><img src="images/setup-money-paths.en.jpg" width="280"></p>

**Before you start**

Answer two questions: do members pay you for the space, and do you want the legal invoices to come out of DesKilo?

| Path | Choose it when | What happens |
|---|---|---|
| 1. No money | The space is free, or members are friends who share the rent outside the app | You leave the money features off. Members book; nobody is billed. |
| 2. Statements and payments, invoices outside | You already have an accountant or an invoicing tool, or you work in a country DesKilo cannot issue invoices for | Members have a monthly statement, you record the payments you receive, and you export the figures for your accountant. The legal invoices are produced elsewhere. |
| 3. Invoices issued by DesKilo | You are in France or Germany, and you are either VAT-registered or outside the scope of VAT (an association, for example) | DesKilo produces signed, numbered invoices from what was booked, with your legal identity printed on them. |

**Steps**

1. Pick your path from the table.
2. For path 2 or 3, switch on the money features you need in [Features](help:user.features.switch): **Invoices** is the base of everything that is issued, and the features below it (**Subscription invoices**, **End-of-month invoices**, **Payment reminders**, **VAT management**) come on one by one.
3. For path 3, continue with [your legal identity](help:setup.money.identity) before the first booking, not after.

**Good to know**

- In-app invoice issuing exists today for a workspace in **France** or **Germany**. In any other country, use path 2: statements stay available.
- The server refuses to issue, and the list **Complete these details before issuing** says why, when a detail is missing or when the treatment is one DesKilo does not handle: cross-border sales, reverse charge, export and VAT-exempt invoices must be reviewed and issued outside the app with your accountant.
- A seller on the small-business exemption scheme (franchise en base, Kleinunternehmer) cannot issue invoices in the app: the server refuses the exempt VAT category. Keep path 2, and issue those invoices elsewhere.
- Switching a feature off stops new business of that kind; it deletes nothing.
- You can stay on path 2 forever. Many associations do.

**Result**

You know which of the three paths is yours, and which features it needs.

**See also:** [Invoicing at a glance](help:user.money.invoicing) · [Switch whole processes on or off](help:user.features.processes)

<!-- anchor: setup.money.tariff -->
### Design a tariff

**Audience:** Owner · Billing administrator

You turn "what is a place worth?" into numbers DesKilo can apply every month without you.

<p><img src="images/setup-money-bands--bands.en.jpg" width="280"></p>

**Before you start**

Keep the model in mind. It reads from left to right, and each step feeds the next:

1. Subscription percentage: A member holds a percentage of the month: 25, 50, 75 or 100 %, or a value you allow.
2. Half-day allowance: The percentage becomes a number of half-days for the month: the number of open days, times two, times the percentage, rounded up.
3. Fee band: The percentage falls into one band, which gives the monthly fee and the price of an extra half-day. A band covers "above its start, up to and including its end", and the bands together must cover 0 to 100 % without a gap.
4. Overage policy: When the allowance is used up, each member is either blocked, charged the overage price, or asked to buy a package.
5. Packages and services: A day package sells extra half-days in advance at a price you set; services (a coffee, a locker, printing) are sold on top.

**Steps**

1. Decide the percentages you want to offer under **Subscription levels**, and whether an owner may type a negotiated value (see [Subscription levels](help:user.money.billing.levels)).
2. Set one row per range in **Fee bands**: its upper limit, the monthly fee and the overage price (see [Fee bands](help:user.money.billing.fee-bands)).
3. Decide the default for members who run out: [When days run out](help:user.members.overage-policy).
4. Add the [Day packages](help:user.money.billing.packages) and [services](help:user.money.services.overview) you sell.

**Good to know**

- The arithmetic is frozen on every issued document. Changing a price changes next month, never a month already invoiced.
- Opening hours and closure days decide how many open days a month has, and so the size of the allowance. Set them first.
- A member with no subscription is for visitors who buy carnets; they cannot be on pay-as-you-go.

**See also:** [Billing](help:user.money.billing.fee-bands) · [A member's subscription](help:user.members.subscription)

<!-- anchor: setup.money.example -->
### A worked example

**Audience:** Owner · Billing administrator

You follow one member through one month with the figures of *Atelier du Marché*, so you can check your own numbers the same way.

<p><img src="images/setup-money-packages--packages.en.jpg" width="280"></p>

**Before you start**

The demo space has three fee bands, in euros and VAT included. The figures are the demo's own, not a recommendation.

| Band | Monthly fee | Extra half-day | Half-days in a 22-open-day month |
|---|---|---|---|
| up to 25 % | 0.00 | 15.00 | 11 |
| above 25 %, up to 50 % | 150.00 | 8.00 | 22 |
| above 50 %, up to 100 % | 250.00 | 0.00 | 44 (at 100 %) |

**Steps**

1. A member holds 50 %. In a month with 22 open days the allowance is 22 × 2 × 50 / 100 = 22 half-days.
2. 50 % falls in the second band (above 25, up to 50): the fee is 150.00, whatever the member uses.
3. The member books 24 half-days. Two are over the allowance, at 8.00 each: 16.00.
4. The month costs 150.00 + 16.00 = 166.00, before any service. In the demo the prices are gross: the 20 % VAT is inside them, and the screen shows it under each price.
5. Compare with a package: the demo's 5-day pack costs 40.00 and adds 10 half-days (5 days, two half-days each), that is 4.00 a half-day. Against 8.00 of overage it pays off from the sixth extra half-day in a month.

**Good to know**

- An overage price of 0.00 means extra half-days cost nothing under pay-as-you-go.
- The statement a member sees shows the same lines: fee, included, used, extra, overage.
- Prices are shown including VAT when VAT is on; the tax is extracted from them.
- If a member and you agree on other conditions, see [price negotiation](help:setup.money.negotiation).

**Result**

You can predict a member's bill from three numbers: their percentage, the open days, the bookings.

**See also:** [Read your statement](help:user.money.statement) · [What each booking cost](help:user.money.usage)

<!-- anchor: setup.money.negotiation -->
### Price negotiation

**Audience:** Owner · Billing administrator

You want one member to pay different conditions from the tariff, in a way that leaves a trace.

**Steps**

1. Switch on the price negotiation feature in [Features](help:user.features.switch).
2. Propose conditions on the member page: a different monthly fee, overage rate, discount on supplements, unit prices, or occupation percentage (see [Price negotiation](help:user.members.negotiation)).
3. Let the validation rule for price negotiations decide who confirms it.

**Good to know**

- The tariff stays the default; a negotiated price belongs to one member.
- It is seen by the member, the owners and the people with the right to view commercial agreements, and every read is logged.
- Decide your policy before you open: one exception granted quietly becomes the price everyone asks for.

**See also:** [Your negotiated prices](help:user.money.negotiation)

<!-- anchor: setup.money.pay -->
### How members pay you

**Audience:** Owner · Billing administrator

You choose where a member's money goes, and how much of the work DesKilo does for you.

<p><img src="images/setup-money-payment-instructions.en.jpg" width="280"></p>

**Steps**

1. Start with the free route: fill the [payment instructions](help:user.money.payments.methods): your IBAN and bank details, and any of PayPal.me, Wero, Lydia or Wise you accept, plus a reference hint.
2. Members see these details on an unpaid statement. When a payment reaches your account, you or a billing administrator [record it](help:user.money.payments.record).
3. Only if you want members to pay inside the app, connect a provider in [Online payments](help:user.money.payments.provider): PayPal, Stripe or Mollie. It needs the **Online payments** feature and your own account at the provider.

**Good to know**

- DesKilo records payments; with the manual route it never moves money.
- A provider charges its own fees, takes the keys of your account (the credentials sheet explains how they are entered).
- With **Online payments** off, a new online payment is refused; one already open can still settle.
- A space built from a template does not carry payment details: enter them in each space. A configuration export does carry them.

**See also:** [Pay what you owe](help:user.money.payments) · [Provider credentials](help:user.money.payments.credentials)

<!-- anchor: setup.money.identity -->
### Your legal identity, and what to ask your accountant

**Audience:** Owner

You tell DesKilo who is selling, so every invoice names you correctly. This is the part to settle with a professional.

<p><img src="images/setup-money-legal--top.en.jpg" width="280"></p>

**Before you start**

The screen is [Legal identity & e-invoicing](app:/legal-identity). Have these ready:

- your organisation type: a business, or a non-profit association;
- your VAT regime: outside the scope of VAT, VAT-exempt (small-business scheme), or VAT-registered. The app can issue invoices for the first and the last only; with the small-business exemption, the screen records your status but invoices must be issued elsewhere (path 2);
- your registration number, and your VAT number if you have one;
- your postal address, as it appears on your registration;
- the reason no VAT is charged, if you charge none.

> **Careful** Choosing the regime is a tax decision, not a software setting. An association with no trading activity is normally outside VAT, and the screen warns you if you pick "exempt" for one. Confirm the choice before you issue the first invoice.

**Steps**

1. Open [Legal identity & e-invoicing](app:/legal-identity) and work from the top: the **VAT regime** first, then the identifiers, the address and the **Invoice mentions**.
2. Fill the payment terms, the late-payment mentions and the other mentions your country requires (see [Your legal identity](help:user.money.legal.identity)).
3. Tap **Save**, then read the invoice template once with your accountant (see [The invoice PDF template](help:user.money.reports.invoice-template)).

> **Tip** Questions to bring to your accountant:
>
> 1. Which organisation type and which VAT regime am I in?
> 2. What are my registration number and my VAT number, and how do I write them?
> 3. If I charge no VAT, which legal wording justifies it?
> 4. Which mentions must appear on my invoices (payment term, late-payment penalty, recovery indemnity, early-payment discount, insurance)?
> 5. How should invoices be numbered, and does the number restart each year or each month?
> 6. Does VAT fall due when I invoice or when I am paid?
> 7. Must I send e-invoices to a government platform, and which one?
> 8. Do I need periodic VAT returns, and how often?

**Good to know**

- Invoices already issued keep the identity they were signed with; a change applies to the next ones.
- Only an owner or an active co-owner can open this screen, and the **Invoices** feature must be on.
- A space made from a template does not carry your identity: enter it again. A deployment between the two sides of a pair does carry it.

**See also:** [VAT regime](help:user.money.vat.regime) · [The e-invoicing platform](help:user.money.einvoice.overview) · [Organisation type](help:user.money.legal.seller-kind)

<!-- anchor: setup.money.invoicing -->
### Invoice by hand or automatically

**Audience:** Owner · Billing administrator

You decide whether a person presses the buttons each month or DesKilo does.


**Steps**

1. For a first month, work by hand: open [Invoicing](app:/invoices), read **To issue**, and issue one member's invoice (see [Issue an invoice](help:user.invoicing.new-invoice)).
2. For a routine, use the [month-close wizard](help:user.invoicing.wizard): it walks through **Review**, **Issue**, **Send**, **Remind**, **Payments**, **Match**, **Close** and **Summary**.
3. To automate, switch on **Subscription invoices** and **End-of-month invoices** in [Features](help:user.features.switch), then set the days in [Invoice schedule](help:user.money.billing.schedule).

**Good to know**

- Two documents exist per month: the subscription fee, issued ahead of the month, and what the month actually cost, issued after it. An invoice can be dated a few days ahead (three by default, set in the invoice schedule), so one dated 29 August can name September.
- On the server, a daily run issues both when the installation's database has its scheduler enabled; if you are unsure, ask the operator.
- Each kind of invoice (subscription, end-of-month) can be issued once per member and month. Invoices cannot be edited or deleted; a wrong one is marked erroneous and replaced.
- By default the owner and co-owners issue invoices. **Admins issue invoices** extends this to administrators.

**See also:** [The Invoicing screen](help:user.invoicing.hub) · [Chase and settle open invoices](help:user.invoicing.open)

<!-- anchor: setup.money.reminders -->
### Payment reminders

**Audience:** Owner · Billing administrator

You decide how late is late, and who does the chasing.

<p><img src="images/setup-money-reminders.en.jpg" width="280"></p>

**Steps**

1. Switch on **Payment reminders** in [Features](help:user.features.switch). It sits under **Invoices**.
2. Set the number of levels and the delays in [Reminder rules](help:user.money.reminders.rules): days until the first reminder, days between reminders.
3. Decide whether reminders leave on their own: switch **Automatic reminders** on in the same dialog (see [Automatic reminders](help:user.money.reminders.automatic)); the feature **Automatic payment reminders** must be on too.

**Good to know**

- The delay before the first reminder is also read as your payment term. Set it with [Payment terms](help:user.money.legal.payment-terms).
- Automatic reminders run once a day on the server when the database has its scheduler enabled. They also run when someone who may issue invoices (an owner, a co-owner, or an administrator if **Admins issue invoices** is on) opens Finances, so a space without the scheduler still gets them, on the days someone looks.
- The **Payment reminders** feature only makes the rules available. A reminder leaves on its own only when **Automatic reminders** is switched on in the reminder rules, which is off until you choose it.
- They skip an invoice with a payment pending or on hold, and an invoice without a recorded payment term.
- The member gets an alert in their feed and, if push is set up, a generic notification; see [Tell people](help:setup.notify.overview).

**See also:** [Payment terms](help:user.money.legal.payment-terms)

<!-- anchor: setup.money.vat -->
### VAT in outline

**Audience:** Owner · Billing administrator

You want to know what VAT will ask of you before you switch it on.

<p><img src="images/setup-money-vat--rates.en.jpg" width="280"></p>

**Steps**

1. Only if you are VAT-registered, switch on **VAT management** in [Features](help:user.features.switch).
2. Set the rates in [VAT](app:/vat): **Use the usual rates** for your country, then mark exactly one as the default (see [Setting the rates](help:user.money.vat.rates)).
3. Give each rate its group, and an exemption reason where it applies (see [VAT groups](help:user.money.vat.groups)).
4. When the law changes a rate, use **Change by law** so older invoices keep their rate (see [Change a rate by law](help:user.money.vat.change-by-law)).
5. If you must file returns, switch on **VAT declarations** and generate each period in [VAT declaration](help:user.money.vat.declaration).

**Good to know**

- A catalogue of rates ships for the EU member states, Switzerland, Norway and Canada. Keeping it current when a government changes a rate is your job.
- Registered without a default rate in force, the server refuses to issue.
- A declaration is a filing aid made from your issued invoices. Verify it before you file, and mark it filed only once you have.
- The declaration journal has its own number series.

**See also:** [VAT regime](help:user.money.vat.regime) · [When VAT falls due](help:user.money.vat.due)

<!-- anchor: setup.money.permanent -->
### What cannot be undone

**Audience:** Owner

You want to know, before the first invoice, what you will not be able to change afterwards.

<p><img src="images/setup-money-numbering.en.jpg" width="280"></p>

> **Careful** From the first issued invoice, the items below are permanent. Decide them with your accountant first.

| Decision | What becomes permanent | When |
|---|---|---|
| An issued invoice | It is signed and immutable: amounts, parties, VAT breakdown and tariff arithmetic stay as printed. A correction is a cancellation, a credit note or a refund, each a new document. | At issue |
| Invoice number | Numbers are gapless and drawn in the database at the moment of issue. The next number can be raised, never lowered. A change of format applies from then on. A restart cannot be more frequent than the date the number prints. | At the first issue |
| An invoiced month | A month with an invoice for a member is closed for that member. Closure days and holiday imports skip such months and name them. | At the first invoice for it |
| VAT rates | Rates are versioned by date, never edited. A submitted VAT declaration is never recomputed. | At the first use |
| Currency and country | Amounts are stored as whole minor units without conversion. No guard was found that stops changing them later: decide before the first booking. | Before the first booking |

**Steps**

1. Open [Number sequences](app:/settings/number-sequences) and set the prefix, the suffix, the date part, the digits and the restart for each journal (invoices, credit notes, VAT declarations, members, payments). The screen needs the **Number sequences** feature.
2. Show the result to your accountant before the first invoice.
3. Choose the country, currency and time zone in [Workspace settings](help:user.workspace.settings.country) before anybody books.

**Good to know**

- Numbers are not wasted: a document that fails to issue takes none.
- The two states of a space, test and production, exist so that nothing here is tried for real; see [a safe dry run](help:setup.money.dry-run).

**See also:** [The invoice register](help:user.invoicing.register) · [Currency and time zone](help:user.workspace.settings.currency-timezone)

<!-- anchor: setup.money.dry-run -->
### A safe dry run in a test space

**Audience:** Owner

You rehearse the whole money routine once, with nothing real at stake.

**Steps**

1. Create or open a test workspace (**One test workspace**, or the DEV side of a linked pair); see [Test space](help:user.advanced.test-space) and [Environments](help:user.advanced.environments).
2. Enter the legal identity, the rates, the tariff and the payment instructions as you intend to run them.
3. Invite two or three people to book a few days; add a service for one of them.
4. Run the [month-close wizard](help:user.invoicing.wizard) from start to end and read the invoice PDF.
5. Record a payment, let a reminder fall due, and read the statement as the member.
6. Show the PDFs and the accounting export to your accountant.

**Good to know**

- A test space watermarks every document and says it is a test; nothing is owed.
- Declaring a space production removes the watermark; invoices already issued keep theirs.
- The pair can pull the configuration from one side to the other, but credentials do not travel.

**Result**

A first month you have already seen, and a list of questions answered before they cost anything.

**See also:** [The two environments](help:user.advanced.environments) · [Accounting exports](help:user.invoicing.accounting-export)
