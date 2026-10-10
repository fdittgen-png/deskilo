<!-- anchor: setup.consistent.overview -->
## Keep it consistent

A space can be wrong in two ways: a setting that is missing, and two settings that contradict each other. DesKilo catches some of both, and says so on screen. This chapter lists what it catches and where you see it, says plainly what it does not catch, and gives you an audit to run before the doors open and a short routine to run every month.

In this chapter:
- [The guards the app gives you](help:setup.consistent.guards)
- [The mistakes the guards do not catch](help:setup.consistent.gaps)
- [The pre-launch audit](help:setup.consistent.audit)
- [The monthly routine](help:setup.consistent.monthly)
- [When something looks wrong](help:setup.consistent.wrong)
- [What cannot be undone](help:setup.consistent.irreversible)

The running example is *Atelier du Marché*. Its owner, Ada, runs the audit once in a test space and once more in the real one.

<!-- anchor: setup.consistent.guards -->
### The guards the app gives you

**Audience:** Owner · Co-owner · Administrator · Billing administrator

You want to know which of your mistakes the app will point out, and where it will do it, so that you look in the right place.

<p><img src="images/setup-consistent-features-attention.en.jpg" width="280"></p>

| Guard | What it catches | Where you see it |
|---|---|---|
| A feature that needs another | A feature cannot work without the one it needs. Switching a feature on switches its parent on and names what came on. Switching a parent off holds its children back and keeps their own choice. | **Features**: the switch flow with its preview, **Requires…** and **Waiting on the feature above** |
| A process held back | A feature that is on but waits for something that is off. | **Features**, **Processes** view: the state **Needs attention** and its filter chip |
| The readiness list | One line per area of the space, with its state, who acts and where to set it. Areas: **Opening days, time zone and currency**, **Bookable places on the floor plan**, **Membership plans and tariffs**, **Invite the first members**, **How members pay**, **Roles and who validates requests**, **Export and recovery**, **Details your features need (identity, bank, platforms)**, **A first booking** and, when relevant, **Server and database version** and **Assistant access (optional)** (the latter only with the MCP interface on). | **Setting up this space**, at the top of [Workspace](app:/workspace-settings) |
| The line that stops a first booking | Only what a booking truly needs: a time zone, a currency, an open weekday, one seat, and, when a booking rule asks for more validators than exist, those validators. The rest is optional and can be set aside with **Later**. | **Before anyone can book here**, on the Get started card of [Reserve](app:/reserve) |
| What your features still need locally | Legal identity (needed by **Invoices**), bank details, an online payment provider, an e-invoicing account, a site. | The same card, area **Details your features need (identity, bank, platforms)**, with **Set up** and **Recommended** |
| The invoice guard | An invoice is refused until it is complete: the workspace address, its VAT number, a country France or Germany, a legal basis for an exemption, the member's name, address and VAT number when reverse charge applies, a VAT rate in force, an explanation for every line billed at 0 %. Cross-border, reverse-charge, export and exempt invoices are refused: issue them outside the app. | **Complete these details before issuing**, with the missing items listed |
| The online payment guard | With **Online payments** off, the server refuses a new online payment. One already open still settles. | The payment screens (the feature row carries no note about it) |
| The validation guard | **Required validations** above the people available. | **Not enough eligible validators.** in the rule editor; "A policy asks for more validators than this space has" in the readiness list |
| The number sequence guard | A reset more frequent than the date printed in the number is refused. | [Number sequences](app:/settings/number-sequences), when you save |
| The maturity check | A feature reviewed as **Alpha** or **Beta**. | A confirmation before you switch it on, and a badge on every switch |
| The plan replacement check | Replacing the floor plan or the settings from a file. | A warning that it cannot be undone. The plan is refused once reservations exist |

**Good to know**

- **Setting up this space** is a list, not a lock. It never stops you from switching something on.
- Most guards act when you try to issue, pay or book, not when you choose a setting. That is why the audit below exists.
- The owner inbox ([What needs you](help:user.collaborate.attention)) does not raise configuration problems today. Do not wait for it to tell you.

**See also:** [Avoid features that contradict each other](help:setup.features.consistency) · [Check your space](help:setup.place.check)

<!-- anchor: setup.consistent.gaps -->
### The mistakes the guards do not catch

**Audience:** Owner · Co-owner · Billing administrator

You want the honest list of what stays your responsibility. These are configurations the app lets you create and does not warn about. Each has a way to avoid it by hand.

| Mistake | Why nothing stops it | Avoid it by |
|---|---|---|
| Choosing a country other than France or Germany and expecting invoices | The app offers many countries and VAT rates, but issues invoices only for France and Germany. Nothing says so when you choose the country. | Deciding before you promise members an invoice. Elsewhere, keep statements in the app and issue invoices outside it. |
| Being registered for VAT with no rate in force | Issuing is refused, but only at the first invoice. With **VAT management** off, the configuration is hidden but the stored rates keep applying. | Adding the rate under [VAT](app:/vat) before the first month-close, and running a trial invoice. |
| **Online payments** on with no provider | You can switch it on; the missing provider shows only as an item in the readiness list. | Connecting the provider first, then switching on. |
| **Invoices** on with no legal identity | The feature is on from the first day; the refusal comes at issue time. | Filling in the identity before telling members they will be invoiced. |
| A rule needing more validators than you have, outside bookings | The readiness list holds up the first booking only for reservation rules. The editor lets you save one above the people available. Other requests are created, cannot be completed, and expire after seven days. | Counting active owners and administrators after each rule. See [Avoid requests that wait for ever](help:setup.people.stuck). |
| Members who cannot open the plan | In a new space the **User** card of [Roles](app:/roles) is empty and nothing warns you. | Ticking the everyday permissions and joining once with a second account. |
| A space made from a template | A template never carries the identity, bank details, sites or invitations. | Treating the area **Details your features need (identity, bank, platforms)** as a to-do list. |
| A settings file that promises more than it delivers | Today the file carries the role matrix, your own roles and every validation rule, but not the members, the invoice and member numbers, the VAT period or whole-space prices. What it carries is applied only if **Configuration in the space file** is on in the target. A plan is not replaced once reservations exist. | Re-entering what it does not carry by hand, and reading the preview before **Replace and import**. |
| Reminders that never run | They run every morning on the server when the database has its scheduler (pg_cron); if it has none, they run when an administrator opens Finances. They also stay silent when **Automatic payment reminders** is off. | Asking the operator whether the scheduler exists, and opening Finances yourself if it does not. See [Payment reminders](help:user.money.reminders.automatic). |
| Changing country, currency or time zone once money exists | I found no guard. Amounts are stored as numbers and are not converted: check with the owner of the installation before relying on one. | Choosing them on day one. See [Decisions that are hard to undo](help:setup.before.permanent). |
| Numbering or VAT period that does not suit your accountant's format | The app does not compare them with the country's accounting export. | Asking your accountant for the numbering format and the export they use before you issue. See [Accounting exports](help:user.invoicing.accounting-export). |
| Taking a test for the real space | Beyond the watermark on printed documents, the difference is easy to miss. | Looking at the test-space banner and the side shown in [Me](app:/me) before you act. |

**Good to know**

- A kiosk with no kiosk member, a site feature with no site, push without a push service: [Avoid features that contradict each other](help:setup.features.consistency).
- The app is stricter than it looks about invoices and looser than it looks about everything else. When in doubt, issue a trial invoice in a test space.

**See also:** [A safe dry run](help:setup.money.dry-run)

<!-- anchor: setup.consistent.audit -->
### The pre-launch audit

**Audience:** Owner · Co-owner

You want proof, not a feeling, before you open. Thirty-one checks, in three levels. Run *Open* before you invite anyone, *Run* before you promise anything about money, *Grow* before the first invoice leaves. Do it in a test space first, with a second person.

*Open: a place people can book*

| # | Check | Where | Good looks like |
|---|---|---|---|
| 1 | Country, currency, time zone | [Workspace](app:/workspace-settings), **General details** | Atelier du Marché: France, EUR, Europe/Paris |
| 2 | Workspace language | Same screen | The language your invitations are written in |
| 3 | Open weekdays and hours | [Availability](app:/availability) | The days you open are ticked; the hours match the day |
| 4 | Closure days | Availability, closure days | Holidays and closures for the next months are in, before the first month-end |
| 5 | At least one seat | [Workspace editor](app:/editor) | Every room you rent has seats |
| 6 | Readiness | **Setting up this space** | Nothing under **Opening days, time zone and currency** or **Bookable places on the floor plan** needs configuration |
| 7 | You booked a seat | [Reserve](app:/reserve) | The seat is booked, checked in and cancelled without a surprise |
| 8 | The workspace ID | [Workspace ID & QR](app:/workspace-code) | The ID is one you can say aloud; the QR is printed |
| 9 | Everyday permissions | [Roles](app:/roles) | **User** holds the six everyday permissions |
| 10 | A second account joined | Another device | It was approved and could open the plan and book |
| 11 | More than one person can act | [Members & plans](app:/members) | An owner plus a co-owner or an administrator, all **Active** |
| 12 | Validation counts | [Validation rules](app:/validation) | No rule asks for more validators than active owners and administrators |
| 13 | The invitation in each language | **Community & invitations** | You read each version once; no tag is left unfilled |
| 14 | The side you are on | [Me](app:/me) | The test-space banner is shown, or not, as you intended |

*Run: people pay and roles hold*

| # | Check | Where | Good looks like |
|---|---|---|---|
| 15 | Fee bands | [Billing](app:/billing) | Every share a member can choose falls in a band; no gap between 0 and 100 percent |
| 16 | Plans offered | Billing, levels | Only the plans you want to sell |
| 17 | What new members start with | **New members**, in Workspace | The subscription and the rule when days run out are the ones you chose |
| 18 | Packages and services | Billing, [Services](app:/services) | Names and prices read right to a member |
| 19 | How members pay | **How members pay** in the readiness list | The area reads **Ready** and the bank details you expect (IBAN, reference) are shown in Settings; a provider alone also turns it ready |
| 20 | Online payments | [Features](app:/features) | Off, unless a provider is connected |
| 21 | Administrators | Members & plans | Each one is a person you would trust with every member's data |
| 22 | Administrator card of the matrix | Roles | You can read each tick and defend it |
| 23 | Who is told what | [How members are told](help:setup.notify.members) | Members find everything under **Events**; push only if the operator set it up |
| 24 | Kiosk and badges | [Features](app:/features) | Off, or a kiosk member exists and badges are issued |
| 25 | Sites | Features | Off, or at least one site exists |
| 26 | Features held back | **Features**, **Needs attention** | The filter shows no process |

*Grow: invoices, tax and records*

| # | Check | Where | Good looks like |
|---|---|---|---|
| 27 | Legal identity | [Legal identity & e-invoicing](app:/legal-identity) | **Complete these details before issuing** shows nothing when you start a trial invoice |
| 28 | VAT regime and rates | [VAT](app:/vat) | The regime is the one your accountant gave; a rate is in force for your default |
| 29 | Number format | [Number sequences](app:/settings/number-sequences) | You read the preview and your accountant agrees |
| 30 | A trial invoice | Test space, month-close wizard | It issued, in each language your members read, without a missing item |
| 31 | A recent export | **Export and recovery** | "A recent export is on record" |

**Steps**

1. Print the three tables or copy them into your notes.
2. Run *Open* and tick each line as you see the *good* column, not as you remember it.
3. Do the same for *Run* and *Grow* in the test space, with your accountant for the lines of *Grow*.
4. Repeat the lines that changed when you move to the real space. A template or a settings file does not carry all of them.

**Result** A list you can show someone, and a space you have seen working before anyone depends on it.

**See also:** [Week 0 to week 4](help:setup.training.overview) · [A safe dry run](help:setup.money.dry-run) · [The sequence to follow](help:setup.reports.sequence)

<!-- anchor: setup.consistent.monthly -->
### The monthly routine

**Audience:** Owner · Administrator · Billing administrator

You want a short habit that keeps the space coherent, in ten minutes at month-end.

**Steps**

1. Open **Setting up this space**. Every area still reads **Ready**, or **Not needed here**, or is set aside on purpose.
2. Open [Events](app:/events). **Waiting for your confirmation** is empty or small, and no member has been **Pending** for more than a day or two.
3. Recount the team. Anyone who left or was paused can leave a rule short. See [Avoid requests that wait for ever](help:setup.people.stuck).
4. Close the month: closure days are entered, the month-close wizard is run, payment reminders have gone out (automatically each morning, or on opening Finances where the database has no scheduler). See [The month-close wizard](help:user.invoicing.wizard).
5. Take the data export, and open **Features** to check that no process needs attention after the changes of the month.

**Good to know**

- Writing the date of the last run on the first line of your notes tells the next person when it was last true.
- Anything changed during the month in the role matrix or in a validation rule is worth one more check of the audit lines 9, 11 and 12.

**Result** A space that stays what you set up.

**See also:** [The pre-launch audit](help:setup.consistent.audit)

<!-- anchor: setup.consistent.wrong -->
### When something looks wrong

**Audience:** Owner · Co-owner · Administrator

You want to know what to try, in what order, and whom to ask.

<p><img src="images/setup-consistent-recovery-export.en.jpg" width="280"></p>

**Steps**

1. Read the message on the screen. Most say what to do.
2. Check the side. Look at the test-space banner and the side shown in [Me](app:/me). Documents printed on the test side carry a watermark and nothing there is owed; the real side issues invoices that are.
3. Check [Features](app:/features) and [Roles](app:/roles): a missing function is a feature that is off or a permission nobody ticked.
4. Open **Setting up this space** and read the area that matches the symptom.
5. Prepare **Support details** under [Help](app:/help): choose **Last hour** or **Last 24 hours**, **Prepare preview**, read it, **Save**, and send the file. It holds counts and checks only, not identities, credentials or business records.
6. Before you change anything big, take the data export (below).

*Who to ask*

| About | Ask |
|---|---|
| A setting of your space, a rule, a role | You, then your co-owner |
| An invoice, VAT, a number | Your accountant, with the trial invoice |
| An area that says **Waiting for someone else** or **The server operator** | The operator of your installation |
| An assistant that is not approved | A database administrator |
| An error you cannot explain | Support, with the support file |

*The recovery export*

1. Open [Reports](app:/reports?section=documents) and choose **Workspace documents**.
2. Tap **Export data (Excel)**. It needs the **Data export (Excel)** feature and the permission **Export accounting and data**. You get one ZIP: a workbook with a tab per dataset, a manifest counting the rows, and the stored files.
3. Tap **Export configuration (PDF)** for a record of the parameters and, in **Workspace**, **Export workspace (XML)** for the plan and settings.

**Good to know**

- A completed data export is recorded; the readiness area **Export and recovery** says so for 90 days, then reads that the export is older.
- The PDF is a record, not a backup. Only the XML can be imported back, and it never holds members or money.
- Keep the file somewhere only you can open: it contains your members.

**See also:** [Support details](help:user.advanced.support) · [When something does not work](help:user.advanced.troubleshooting) · [Export the data (Excel)](help:user.workspace.export.excel)

<!-- anchor: setup.consistent.irreversible -->
### What cannot be undone

**Audience:** Owner · Co-owner · Billing administrator

You want one page that says what to slow down for. The full list, with what to do instead, is [Decisions that are hard to undo](help:setup.before.permanent). This is the recap.

> **Careful** An issued invoice never changes and its number is never reused. A mistake is corrected with a cancellation, a credit note or a refund request, not with an edit.

| Decision | Permanent from | Covered in |
|---|---|---|
| Invoice number format and sequence | The first issued invoice | [Decisions that are hard to undo](help:setup.before.permanent) |
| A member's invoiced month | The moment the invoice is issued | [Money](help:setup.money.permanent) |
| Legal mentions on the invoice | The first issued invoice | [The sequence to follow](help:setup.reports.sequence) |
| VAT regime and rates | Rates are versioned by date and never edited; a submitted declaration is never recomputed | [Money](help:setup.money.permanent) |
| Country, currency, time zone | When money exists: amounts are not converted | [Decisions that are hard to undo](help:setup.before.permanent) |
| Floor plan replacement | Refused once a reservation exists; deleting a floor removes what is on it | [Decisions that are hard to undo](help:setup.before.permanent) |
| The workspace ID | When you change it, the old one stops working at once; reprint the QR | [How people join](help:setup.people.join) |
| Ownership | An owner can give it; there is no owner invite | [Co-owners](help:setup.people.coowner) |
| A matrix or validation change | It is recorded as an event and takes effect for everyone at once | [The role matrix](help:setup.people.matrix) |
| Test or real | A real space issues invoices that are owed | [Before you start](help:setup.before.overview) |
| An export shared | A shared file cannot be revoked | [When something looks wrong](help:setup.consistent.wrong) |

**Good to know**

- Switching a feature off never erases data.
- A file with credentials is not a backup. Keep tokens out of any file you send.

**Result** You know which lines to read twice.

**See also:** [Before you start](help:setup.before.overview)
