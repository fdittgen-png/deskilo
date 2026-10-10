<!-- anchor: setup.before.overview -->
## Before you start

A little preparation saves you the two things that cost most later: retyping, and decisions you cannot take back. This chapter shows what DesKilo does, what you really need to open, and what to have at hand.

In this chapter:
- [What DesKilo can do](help:setup.before.what)
- [What is necessary and what is optional](help:setup.before.necessary)
- [A test space or a real one](help:setup.before.environment)
- [Start from a template or from nothing](help:setup.before.template)
- [What to prepare](help:setup.before.prepare)
- [Decisions that are hard to undo](help:setup.before.permanent)
- [Who does what](help:setup.before.who)

<!-- anchor: setup.before.what -->
### What DesKilo can do

**Audience:** Owner · Co-owner

You want a picture of the whole before you choose anything. DesKilo groups its features into nine processes; the **Features** screen shows one card per process with its state.

<p><img src="images/setup-before-processes.en.jpg" width="280"></p>

*The nine processes, in plain words*

| Process | What it gives a member |
|---|---|
| **Workspace & access** | A way in: join with the workspace ID, a role, a badge. |
| **Space management** | A place that looks like the real one: floors, rooms, desks, opening times. |
| **Reservations & usage** | Booking a desk or a room, checking in and out, seeing what is free. |
| **Calendar & coordination** | A calendar, messages and requests that someone confirms. |
| **Membership commerce** | A plan, service prices and agreements. |
| **Billing & payments** | A statement, invoices, payment, reminders, VAT. |
| **Documents & information** | Documents to read, reports to print, their own data to export. |
| **Operations & administration** | A space that carries its own colours and words. |
| **Integrations & automation** | Notifications and documents delivered through outside services. |

**Good to know**

- A new space starts with a sensible set of features on; you do not have to decide on them one by one. Switching a feature off stops new business only and deletes nothing.
- A feature that needs another one switches it on with it, and the screen names what came on. See [A feature switch](help:user.features.switch).
- Features marked alpha or beta ask for your consent when you switch them on.

**See also:** [Switch features on and off](help:user.features.processes)

<!-- anchor: setup.before.necessary -->
### What is necessary and what is optional

**Audience:** Owner · Co-owner · Administrator

You want to know the shortest road to a space people can book. The app keeps a readiness list called **Setting up this space** and, on the Reserve screen, tells owners **Before anyone can book here** what is missing.

*What must be there before the first booking*

1. **Opening days, time zone and currency**: a time zone, a currency and at least one open weekday.
2. **Bookable places on the floor plan**: at least one seat.
3. **Roles and who validates requests**: counted only when a validation rule, of any kind, asks for more validators than the space has. A rule asking for two approvals with only you in the space would leave requests waiting for ever.
4. **What members may do**: members hold **Book and use reservations**. A new space grants them nothing, so a member who joins cannot book until you tick it in [Roles](app:/roles).

One more row, **Server and database version**, blocks only when the server is behind this app; it then waits for the server operator. And while **Invoices** is on, **The space's legal identity and address** is required too: the list marks it **Needed before invoicing**, because no invoice can be issued without it.

*What is optional, and can be set aside for later*

- **Membership plans and tariffs**
- **Invite the first members**
- **How members pay**
- **Export and recovery**
- **Details your features need (identity, bank, platforms)**
- **A first booking**

Each of these can be set aside with **Later** and brought back; the list says whether a step is **Needs configuration**, **Ready**, **Not needed here** or **Waiting for someone else**. Two more states exist: **Not verified yet** (**Export and recovery** turns Ready only after a real export in the last 90 days) and a row that could not be read.

**Good to know**

- The list names who acts: **You**, **The server operator** or **A database administrator**.
- Optional does not mean unimportant: bank details, a payment provider or a site are details your features need, and the list names them.
- If you switch invoicing on without legal identity, the app lets you; the list and [What needs you](help:user.collaborate.attention) name it, and issuing an invoice is refused, saying what is missing.

**See also:** [Check your space](help:setup.place.check) · [The Get started card and the tips](help:user.start.get-started)

<!-- anchor: setup.before.environment -->
### A test space or a real one

**Audience:** Owner · Co-owner · Operator

You want to try things without consequences, then run the real space. A space can be a test, a real one, or a linked pair with the same name.

<p><img src="images/setup-before-environment.en.jpg" width="280"></p>

| Option | Choose it when | What happens |
|---|---|---|
| **One test workspace** | You are learning. | Every screen and document says it is a test: documents carry a watermark. No real billing. |
| **One real workspace** | You know your settings. | The invoices it issues are owed. |
| **A linked test and real pair** | You want to rehearse changes before the real members see them. | Two spaces, both yours. Only a deployment moves configuration from one to the other; members, bookings, invoices and payments never travel. |

**Good to know**

- The selector starts on the test option.
- The environment is a statement by the owner; anyone with the configuration permission (the owner always) can change it later, and invoices already issued keep the watermark they carried, so start with a test space if you are unsure.
- To practise with no space of your own, use the demo workspace.

**See also:** [A space has two sides](help:user.advanced.environments) · [Create a workspace](help:user.start.create) · [A test space](help:user.advanced.test-space)

<!-- anchor: setup.before.template -->
### Start from a template or from nothing

**Audience:** Owner

You want a head start without being locked into someone else's choices. When you create a space, **Start from** offers **Empty space** or a ready-made template, and is preselected on *A tiny space*; choose *Empty space* if you want a blank canvas.

<p><img src="images/setup-before-template.en.jpg" width="280"></p>

*The two built-in templates*

| Template | What it sets up |
|---|---|
| A tiny space | Two levels, four desks, eight seats, nothing else: enough to book, scan and browse from the first minute. |
| Association de coworking (France) | Half days 7:00–13:00 and 13:00–19:00, Monday to Friday, public holidays, 50 % and 100 % memberships, two prepaid books of half-days (10 and 20), board roles (treasurer, secretary, room steward), a calendar for validations, and two floors ready to book. It also sets the workspace language to French and the VAT regime to *not subject to VAT*; only three words are renamed (Place, Étage, Réservations). The template's name is French in every app language. |

**Good to know**

- A template never carries your legal identity, bank details, sites, invitations or document links: those are yours, and the readiness list names them (the legal identity, with **Invoices** on, as an area of its own).
- A template-created space can have invoicing on and nothing to issue with until you add the identity.
- Applying a template to a space that already has tariffs replaces its fee bands: use it on a new space.

**See also:** [Create a workspace](help:user.start.create)

<!-- anchor: setup.before.prepare -->
### What to prepare

**Audience:** Owner

You want the facts at hand so that setting up takes minutes, not days. Gather these first.

**Before you start**

- [ ] The **legal identity**: association or company, registered name, address, registration and VAT numbers if you have them.
- [ ] An **accountant** (or someone who will confirm tax choices): invoices and VAT are the part to check with a professional.
- [ ] A tariff idea: free, a flat membership, or a percentage of days with a monthly fee.
- [ ] **Bank details** members will pay to (IBAN and BIC, or the method used in your country).
- [ ] A list of the first people: names and e-mail addresses, and who will approve requests.
- [ ] A floor plan sketch: floors, rooms, how many desks and seats, and whether a whole room can be booked.
- [ ] Your opening days and hours, and the days you close.

**Good to know**

- You can open without the legal identity and the bank details; you need them before the first invoice.
- Write the sketch on paper first. The app draws floors, rooms, desks and seats; it is faster to enter a plan you have already thought through.

**See also:** [Prepare a space with the setup questionnaire](help:user.start.questionnaire)

<!-- anchor: setup.before.permanent -->
### Decisions that are hard to undo

**Audience:** Owner · Co-owner

You want to know which choices to slow down for. Most settings can be changed any day. These cannot, or not cleanly.

> **Careful** An issued invoice never changes, and its number is never reused. If you are wrong, you correct with a cancellation, a credit note or a refund request, not with an edit.

| Decision | When it becomes permanent | What to do instead |
|---|---|---|
| Invoice number format and sequence | The next number can be raised, never lowered. After the first invoice you can no longer print less of the date than the series shows. | Preview the format, ask your accountant, then issue. |
| The month of an issued invoice | Once a member's month is invoiced it is locked; closure days and public-holiday imports skip it. | Set closure days before month-end. |
| VAT regime and rates | Rates are versioned by date and never edited; a submitted VAT declaration is never recomputed. | Add a new rate from a date; decide the regime with your accountant. |
| Country, currency, time zone | Amounts are stored as numbers with no conversion. Once the space has issued a document or recorded money, the server refuses any change of currency or country. The time zone is never locked, but every day is counted in it. | Choose them right on day one; see [Build the place](help:setup.place.overview). |
| Floor plan replacement | Importing a plan is refused once reservations exist. | Edit floors and rooms one by one in the editor. |
| Workspace ID | It is what members type and what the printed QR codes point to. You can change it (4 to 20 letters or digits) with **Change workspace ID**, but the old ID stops working at once. | Choose a short, memorable ID before you print anything; change it early if you must. |
| Test or real | A real space issues invoices that are owed; dev documents are watermarked. | Start in a test space, deploy when ready. |
| A rule that needs more validators than you have | Requests wait for ever. | Count your validators before you require two. |

**Good to know**

- Switching a feature off never erases data.
- Deleting a floor removes every office, desk and seat on it.

**See also:** [Money](help:setup.money.permanent)

<!-- anchor: setup.before.who -->
### Who does what

**Audience:** Owner · Co-owner · Administrator · Operator

You want to know whom to call for what. Three people can be involved, and the readiness list names them.

| Who | What they do |
|---|---|
| **Owner** (and *Co-owner*) | Everything about the space: floors, hours, features, roles, tariffs, legal identity, invitations, deployments. Co-owners hold every permission by default; the owner decides what administrators may do. |
| **Operator** | Runs the installation: the server and its secrets, and the database updates. Needed to make push notifications work, and for anything the readiness list calls **Waiting for someone else**. |
| **Database administrator** | Approves a member's access for assistants. |

**Good to know**

- On a shared installation the operator is usually the platform's, not you.
- Administrators act within the permissions the owner gave them in the [role matrix](help:user.roles.matrix).
- If a section says **The server operator**, the app cannot do it from your screen.

**See also:** [Decide who may do what](help:user.roles.matrix) · [Deploy permissions](help:user.advanced.deploy-permissions)
