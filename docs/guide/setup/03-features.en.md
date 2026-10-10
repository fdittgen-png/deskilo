<!-- anchor: setup.features.overview -->
## Choose what your space offers

A space is not one product with a hundred settings. It is a handful of things you decide to offer, one at a time. This chapter explains how DesKilo groups what it can do, what a new space already has, how the pieces depend on each other, and in which order to switch them on so that you never offer something you cannot yet run.

In this chapter:
- [Features and processes](help:setup.features.what)
- [Core and Platform: what a new space has](help:setup.features.tiers)
- [Features that need other features](help:setup.features.dependencies)
- [Switching off deletes nothing](help:setup.features.off)
- [Beta, Unreviewed and the question before you switch on](help:setup.features.maturity)
- [Three starting points](help:setup.features.profiles)
- [The order to switch things on](help:setup.features.order)
- [Switch a feature on safely](help:setup.features.safely)
- [Avoid features that contradict each other](help:setup.features.consistency)
- [The feature map](help:setup.features.map)

<!-- anchor: setup.features.what -->
### Features and processes

**Audience:** Owner · Co-owner

You want to know what you are switching when you open **Features**. Everything DesKilo can do beyond the basics is a feature with its own switch. To keep a hundred switches readable, the screen groups them by what they are for.

<p><img src="images/setup-features-what.en.jpg" width="280"></p>

*How it is organised*

- A **process** is a business job: for example **Billing & payments** or **Calendar & coordination**. There are nine.
- A **subprocess** is a step of that job: **Invoicing**, **Payment collection** and **VAT management** are three of the five steps of **Billing & payments**.
- A **feature** is one switch inside a subprocess: **Invoices**, **Payment reminders**, **VAT declarations**.

*The nine processes and their subprocesses*

| Process | Subprocesses |
|---|---|
| **Workspace & access** | **People & membership** · **Physical access** |
| **Space management** | **Space structure** · **Opening days & hours** · **Space presentation** |
| **Reservations & usage** | **Booking desks & spaces** · **Attendance & usage** |
| **Calendar & coordination** | **Calendar views** · **Decisions & approvals** · **Member communication** |
| **Membership commerce** | **Services & pricing** |
| **Billing & payments** | **Financial records** · **Invoicing** · **Payment collection** · **Shared expenses** · **VAT management** |
| **Documents & information** | **Document publication** · **Report design** · **Personal data access & exports** |
| **Operations & administration** | **Configuration & deployment** · **Application experience** |
| **Integrations & automation** | **External delivery** |

**Good to know**

- A feature belongs to exactly one process, even when it needs a feature of another. The card says so: "Switching it all on also needs: Money tab (Billing & payments)".
- Membership plans and the floor plan editor are not features: they are always there. Their settings sit in Workspace and Billing, not on this screen. Prepaid carnets are a feature: see **Carnets**.
- Switching a feature off hides it from every screen where it appeared; it is not a permission. Who may do what is decided in [Roles](help:user.roles.matrix).

**See also:** [What DesKilo can do](help:setup.before.what) · [Switch whole processes on or off](help:user.features.processes)

<!-- anchor: setup.features.tiers -->
### Core and Platform: what a new space has

**Audience:** Owner · Co-owner

You want to know what members find on the first day, before you have switched anything.

<p><img src="images/setup-features-tiers.en.jpg" width="280"></p>

Every feature belongs to one of two tiers, and a new space is created from them:

| Tier | In the app's words | What a new space gets |
|---|---|---|
| **Core** | What every space needs. On from the first day. | On, when the feature is meant to be on at the start. |
| **Platform** | Asked for, never assumed. Switch on what this space actually runs. | Off. In **Switches**, they are listed under the **Platform** tier. |

A new space starts with 45 features on, all of them Core (46 if you create the test twin at the same time: **Environment pairs** is then on as well). In plain words:

- Booking: reserve a seat on the plan, repeat a booking (**Series booking**), book for someone else (**Book for others**), see a half-booked seat as part-filled (**Seat day timeline**), save a booking to a personal calendar (**Calendar file of a booking**), booking rules such as past bookings and outside hours (**Booking policies**, **Booking gate**), request the deletion of a past booking (**Booking deletion requests**), print QR cards for places (**Space QR codes**), configurable working hours (**Working hours**).
- People: the community tab (**Members directory**), one page per member (**Member page**), the central role matrix (**Role management** and **Giving roles**), personal details for letters and invoices (**Personal information**), distinct initials on avatars (**Distinct avatar initials**).
- Calendar and messages: the calendar in several views (**Calendar tab**, **Calendar hub**, **Calendar views**), the activity feed and confirmations (**Events tab**), private and group conversations (**Member notifications**, **Messages, reworked**) with references, forwarding, mentions, swipe gestures and screen-capture protection, the grouping of the notification feed (**Notification feed grouping**), and the button to write to the hosts of a published page (**Write to the hosts**).
- Money: the Finances tab with its four faces (**Money tab**, **Finances in four faces**), invoices (**Invoices**), a service catalogue (**Services**), a PDF of the monthly bill (**PDF export**).
- Documents and data: the document library (**Document library**), data export for the owner (**Data export (Excel)**), and each member's own export and erasure (**Export & erasure**).
- Comfort: help hints, the Get started card, favourites and ratings for places, animations, regional formats and the choice of navigation style.
- Delivery: **Push notifications**, which only reach phones once whoever runs the installation has set up the push service (see [How members are told](help:setup.notify.channels)).
- Plan tidying: **Delete spaces with history** and **Name a single-room level by the level**.

Everything else is Platform and off: kiosk and badges, several sites, accessory supplements, online payments, VAT management, the invoice journey, report design, deployments, WhatsApp, the assistant interface and the rest.

**Good to know**

- The invoices feature is on from the start, but nothing can be issued until your legal identity is complete. See [Avoid features that contradict each other](help:setup.features.consistency).
- A space that already exists never changes when DesKilo changes what a new space gets.
- If you start from a template, the template can switch a few features on or off on top of this set. See [Three starting points](help:setup.features.profiles).

**See also:** [A feature switch](help:user.features.switch)

<!-- anchor: setup.features.dependencies -->
### Features that need other features

**Audience:** Owner · Co-owner

You want to switch something on and be sure it works, or switch something off without breaking what hangs from it.

Many features sit under another one. **Online payments** needs **Money tab**; **Payment reminders** needs **Invoices**; **Automatic payment reminders** needs **Payment reminders**; **VAT declarations** needs **VAT management**, which needs **Invoices**. In the **Switches** list a feature that needs another one shows **Requires** followed by the name of its parent.

**What the app does**

| You | The app |
|---|---|
| Switch a feature on whose parent is off | Switches the whole chain on, and names what came on with it: "Also switched on: …". |
| Switch a parent off | Does not erase its children's choices. They are stored as you set them, but they do nothing; the row says "Waiting on the feature above — switch that on and this one works again". |
| Switch the parent on again | The children that were on work again at once. |
| Switch a whole process or subprocess off while something still needs it | Refuses and names who needs it ("… is still needed by: …"), unless you choose **Switch off anyway, keep their settings** or to switch the dependants off too. |

**Good to know**

- A child that is on but waits for its parent makes its process show **Needs attention**. That is the one state in which a switch and the app disagree, so it is worth a look. See [Switch a feature on safely](help:setup.features.safely).
- A parent can be in a different process from its child: **Services** (Membership commerce) needs **Money tab** (Billing & payments). The card then warns that switching it all on also needs the other.
- The check is made on the feature, not on a permission: a role that may do something is never enough if the feature is off.

**See also:** [A feature switch](help:user.features.switch) · [Switch whole processes on or off](help:user.features.processes)

<!-- anchor: setup.features.off -->
### Switching off deletes nothing

**Audience:** Owner · Co-owner

You want to change your mind later, so you need to know what a switch does not touch.

Switching a feature off stops new business. It does not delete a single record: invoices, bookings, messages, roles and settings stay where they are, and switching the feature on again brings them back. Something already done stays done: an invoice issued while the feature was on keeps what it says.

Behind this, DesKilo sorts the actions of a switchable feature into three kinds:

| Kind | What the switch does to it | Example |
|---|---|---|
| New work (*acceptNew*) | Stops when the feature is off. | Starting a new conversation with the hosts; giving a member a custom role; blocking a seat; starting a new online payment. |
| Work already open (*serviceExisting*) | Carries on, so nothing is left hanging. | Answering a conversation already started; taking a custom role back; lifting a seat block; settling a payment already open. |
| Unsafe paths (*suspended*) | Stay shut whatever the switch says. | Reserved for a path the server judges unsafe; no action is classed this way today. |

Three features say it on their row, in these words: "Off: nothing new starts; what is already open can still be answered and closed." They are **Write to the hosts**, **Roles this space defines** and **Admins can block seats**. **Auto check-in/out at day end** also stops its end-of-day sweep when it is off, but its row does not say so. On a server that cannot confirm this, the row says "do not count on it".

**Good to know**

- Money already committed is always settled: a payment return or a refund is never blocked by a switch.
- With **Online payments** off, the server refuses a new online payment; one that is already open still settles. Its row carries no note about this.
- A switch is not a way to hide something from one person. Use [Roles](help:user.roles.matrix) for that.

**See also:** [A feature switch](help:user.features.switch)

<!-- anchor: setup.features.maturity -->
### Beta, Unreviewed and the question before you switch on

**Audience:** Owner · Co-owner

You see a small word under a feature's name and you want to know what to do with it.

<p><img src="images/setup-features-maturity.en.jpg" width="280"></p>

Each row of **Switches** carries a maturity badge, which says how far the feature has been reviewed against evidence:

| Badge | It means |
|---|---|
| **Unreviewed** | Nobody has yet assessed it against evidence. It says nothing bad about it. |
| **Alpha** | Assessed, at an early stage. |
| **Beta** | Assessed, with known limits; its tests run on every change. |
| **Stable** | Assessed, and also qualified with real providers, hardware or operators. |

At the time of writing most features read **Unreviewed**, eighteen read **Beta**, and none has reached **Stable** yet.

*What the app asks*

1. Flip the switch of an **Alpha** or **Beta** feature.
2. The app asks **Switch on an experimental feature?** and says: "Not yet reviewed as stable: … It may change and has known limits. Switch on only if this space accepts that."
3. It names the stage of each feature and the features that would come on with it because they are needed.
4. Tap **Switch on** to accept, or **Cancel**: nothing is written.

**Good to know**

- **Unreviewed** features do not ask. Only **Alpha** and **Beta** ask.
- The question is asked on a single switch. A whole-process **Switch on** shows what it will switch on, but does not ask this question: switch **Beta** features one by one.
- Beta features at the time of writing include **Invoices**, **Online payments**, **VAT management**, **Carnets**, **Shared expenses**, **Usage records**, **Booking policies**, **Series booking**, **Booking gate**, **Booking deletion requests**, **Finances in four faces**, **Supplies from expenses**, **Validators by role or person**, **Chained validations**, **Auto check-in/out at day end**, **Data export (Excel)**, **E-invoice delivery to customers** and **Demo workspace**. Read each feature's limits with **More** before you rely on it for money.
- Several of these are Core and already on in a new space. They start on without the question; it appears only when you switch one back on.
- **Maturity** narrows the list to one stage, which is a quick way to see everything experimental that your space already uses.

**See also:** [A feature switch](help:user.features.switch)

<!-- anchor: setup.features.profiles -->
### Three starting points

**Audience:** Owner · Co-owner

You do not want to decide a hundred things. Here are three realistic starting points; each one lists exactly what is on. Pick the nearest, then adjust.

The first needs no template. The second is the ready-made template of the app. The third is built from the features themselves. They are named after what they offer, not after a size.

<!-- anchor: setup.features.profile-tiny -->
### A few shared places

**Audience:** Owner

You run a handful of desks or rooms that people book, and nothing else yet. Create the space with **Empty space** or the template "A tiny space" under **Start from**: two levels, four desks and eight seats, enough to book, scan and browse.

The template sets no features, so the space has exactly the 45 Core features of [Core and Platform](help:setup.features.tiers). Nothing is switched on beyond that. For this profile, leave the rest alone:

- Booking, calendar, messages, directory, QR cards for places, the document library and help hints are all there.
- **Money tab** and **Invoices** are on, but until you enter your legal identity and tariffs they only show an empty statement.
- Nothing needs configuring outside the plan and the opening hours. See [Your place](help:setup.place.overview).

> **Tip** If you never charge anything, you can leave the money features on without harm: members just see nothing to pay.

<!-- anchor: setup.features.profile-association -->
### An association with a room

**Audience:** Owner

You are a French association that shares a room, with a bureau, members who pay a fee, and half-day bookings. Choose the template "Association de coworking (France)" under **Start from**. It sets up the opening rules, fee bands at 50 % and 100 %, two prepaid packs, the roles of the bureau, French wording and two floors, and it carries this feature profile:

- The 45 Core features, **except** four it switches **off**: **Events tab**, **Members directory**, **Member page** and **Notification feed grouping**. A small association does not need a feed of events or a directory beside its conversations.
- Four it switches **on**, because the bureau needs them: **Validations on the calendar** (decisions shown on the calendar), **Carnets** (prepaid half-days for people who do not subscribe, Beta), **Roles this space defines** (treasurer, secretary, room referent) and **Workspace vocabulary** (the association's own words).

That is 45 − 4 + 4 = 45 features on. The template carries no identity, so the address, the registration number and the bank details stay yours to enter, and the VAT regime starts as "not subject".

**Good to know**

- Carnets is Beta and is switched on by the template without the question; that is the template's choice, and you can switch it off.
- The template leaves **Invoices** on from the Core set. An association that does not invoice can leave it.

<!-- anchor: setup.features.profile-invoicing -->
### A coworking that invoices

**Audience:** Owner

You rent desks to members and send them invoices every month, in France or Germany. There is no ready-made template, so this profile is a list of what to add to the Core set, in this order. Everything in it chains from **Money tab** and **Invoices**, which are already on.

| # | Switch on | Why | Needs |
|---|---|---|---|
| 1 | **Number sequences** | Decide how documents are numbered before the first one exists. | **Invoices** |
| 2 | **Subscription invoices** | The membership fee is invoiced before the month it pays for. | **Invoices** |
| 3 | **Usage records** | A record of the time really used (Beta). | **Invoices** |
| 4 | **End-of-month invoices** | What the month cost beyond the subscription is invoiced separately. | **Invoices** |
| 5 | **Invoicing wizard** | One guided month-close for whoever does the billing. | **Invoices** |
| 6 | **The journey of an invoice** | Every invoice shows where it stands and whose move it is. | **Invoices** |
| 7 | **Invoice PDF template** | Your own introduction and footer text on the PDF. | **Invoices** |
| 8 | **Member reports** | The financial agreement and the monthly payments report for members. | **Money tab** |
| 9 | **Payment reminders** | Reminder levels, a letter per level, "Reminder due" on late invoices. | **Invoices** |
| 10 | **Consumption report** | A letter at month end with what was used. | **Usage records** |

Then add only what applies to you:

- **VAT management** (Beta) if your space is registered for VAT. Then **VAT declarations**, and **VAT rate versions** and **VAT groups** if your accountant asks for them.
- **Admins issue invoices** if you want a billing administrator to issue them. The owner always can.
- **Online payments** (Beta) only when you have a payment provider to connect.
- **Automatic payment reminders** only after you read [what it does](help:setup.money.reminders).
- **Accessory supplements**, **Carnets** and **Shared expenses** when you bill those things.

**Good to know**

- Before the first invoice, complete your legal identity and VAT. See [Legal identity and invoicing](help:setup.money.identity).
- Issuing here works for spaces in France and Germany only.
- Switch these on one at a time and issue a test invoice in a test space first. See [The order to switch things on](help:setup.features.order).

**See also:** [Money and invoicing](help:setup.money.overview) · [Start from a template or from nothing](help:setup.before.template)

<!-- anchor: setup.features.order -->
### The order to switch things on

**Audience:** Owner · Co-owner

You want to avoid the day on which everything is on and nothing works. Go one process at a time, and look at each from a member's side before you move on.

<p><img src="images/setup-features-order.en.jpg" width="280"></p>

**Steps**

1. Keep the Core set and make the basics work: the places, the opening hours, one tariff. See [Your place](help:setup.place.overview).
2. Open [Features](app:/features) and open one process card. Choose the process that matches your next need, not the one that looks most complete.
3. Tap **Switch on** for a subprocess, or open a single feature among **Switches**.
4. Read the preview: what is **Also needed**, what is already on.
5. Look at it as a member: sign in as one (a second account, or the test side of your space) and do what a member would do.
6. Only then move on to the next process.

*A sensible order*

| Step | Process | Why this place in the order |
|---|---|---|
| 1 | **Space management** | Nothing can be booked without a place and opening hours. |
| 2 | **Reservations & usage** | Booking rules shape everything after them. |
| 3 | **Workspace & access** | Roles and who validates, before the first invitation. |
| 4 | **Calendar & coordination** | Messages and validations need people to exist. |
| 5 | **Membership commerce**, then **Billing & payments** | Prices before invoices; legal identity before the first invoice. |
| 6 | **Documents & information**, **Integrations & automation** | They dress and deliver what the others produce. |
| 7 | **Operations & administration** | Pairs, deployments and transfers once the space is worth copying. |

**Good to know**

- Switching on is cheap and switching off deletes nothing, so a wrong step costs time, not data. The exception is anything that issues an invoice: see [Decisions that are hard to undo](help:setup.before.permanent).
- A test space is the right place to try a process. See [A test space or a real one](help:setup.before.environment) and [A test space](help:user.advanced.test-space).
- Invite members last, after the roles, the validation rules and the tariffs they will meet.

**See also:** [Switch whole processes on or off](help:user.features.processes)

<!-- anchor: setup.features.safely -->
### Switch a feature on safely

**Audience:** Owner · Co-owner

You are about to change a feature and you want to see the effect before it exists.

<p><img src="images/setup-features-safely.en.jpg" width="280"></p>

**Steps**

1. Open [Features](app:/features). The **Processes** view is shown.
2. Tap **Needs attention**. Only the processes holding something that is on but waiting remain.
3. Open a card. A feature **On, waiting for** a named parent is the thing to fix.
4. Fix it by switching the parent on, or by switching the feature off.
5. To change one feature, tap **Switches**, find it with **Search features** and flip its switch.
6. Read the question or the "Also switched on" line, and confirm.

*What "held back" means*

A feature is held back when you chose it but something it needs is off. Its own switch stays on, which is why it is easy to miss: the screen says the feature is on, and the app does not offer it. The card says how many features are held back ("… on but wait for a switched-off prerequisite") and which prerequisite they wait for, and you fix it in [Features](app:/features) itself.

Other things a feature can wait for are not on this screen. A feature can be on and fully allowed while its details are missing: your legal identity, a site, a payment provider. Those appear in **Setting up this space**, under **Details your features need (identity, bank, platforms)**, at the top of the workspace settings.

**Good to know**

- If somebody else changed the features while you were looking, the app writes nothing and says so: "The features changed meanwhile, so nothing was written." Look at the list again and switch again.
- **Changed** counts the switches that differ from the registry default. On a new space it already shows a number (the Platform features that start off), so it is not a count of your own changes.
- Nobody but an owner or co-owner can write features. The server checks again at the moment of writing.

**See also:** [Switch whole processes on or off](help:user.features.processes) · [A feature switch](help:user.features.switch)

<!-- anchor: setup.features.consistency -->
### Avoid features that contradict each other

**Audience:** Owner · Co-owner · Billing administrator

You want to know which combinations leave a space half-working, and which of them the app catches for you.

The app has guards for some contradictions and none for others. In the table, a guard is what the app does; a gap is what stays your responsibility.

| If you have… | Guard in the app | Gap that remains |
|---|---|---|
| **Invoices** on, no legal identity | Issuing is refused, with **Complete these details before issuing** listing the missing address, VAT number and so on. The need also shows in **Setting up this space**. | The feature is on from the first day, so nothing prevents inviting members and running a month before the identity exists. |
| A country other than France or Germany | Issuing says the country "must be France or Germany for issuing here". | Nothing warns you when you choose the country or switch invoicing on. |
| Registered for VAT, no rate in force | Issuing is refused until a rate is in force. | With **VAT management** off, the configuration is hidden while the stored rates keep applying. Check the rates after switching it off. |
| **Online payments** on, no provider | A new online payment is refused when the feature is off; the missing provider shows in **Setting up this space**. | You can switch it on without a provider. Connect it first: [Payment provider](help:user.money.payments.provider). |
| **Kiosk mode** on, no badges and no kiosk member | **RFID / NFC badges**, **QR badges**, **Member photos at the kiosk** and **Sign in with a badge** cannot be on without it. | Nothing checks that a kiosk member exists or that a badge has been issued. See [Run a wall tablet](help:user.kiosk.mode). |
| **Sites** on, no site | **At least one site** appears among the details your features need. | The switch can be on with no site. |
| **Push notifications** on, no push service | Members still get everything in the app. | Phones receive nothing until whoever runs the installation has set up the push service. See [How members are told](help:setup.notify.channels). |
| **Payment reminders** on, **Automatic payment reminders** on | The second cannot be on without the first. | The server's scheduler sends them each morning; if the database has no scheduler, they are sent when an administrator opens Finances. |
| A validation rule asking more validators than exist | **Setting up this space** says "A policy asks for more validators than this space has", and it holds up the first booking when the rule is for reservations. | Other requests are created, cannot be completed and expire after seven days. See [Who validates](help:user.validation.overview). |
| **Booking deletion requests** on, nobody to validate | Same readiness line. | Same gap. |
| **Desk, office & level reservations** on | **Admins can assign levels** needs it. | Each member also needs the right; nothing checks that anybody has it. |
| A child feature on, its parent off | **Needs attention**, and "Waiting on the feature above". | None: this one is fully covered. |
| A space made from a template | The template names what is yours to enter (identity, bank, site). | It carries none of them, so a space can start with **Invoices** on and nothing to issue with. |

**Good to know**

- The rule of thumb: if a feature brings your name, your money or your legal duties onto a document, finish its details before you tell members.
- **Setting up this space** is a list, not a lock. It never stops you from switching something on.
- The check "Before anyone can book here" only speaks about what a booking truly needs: the time zone, the currency, an open weekday and at least one seat.

**See also:** [Legal identity and invoicing](help:setup.money.identity) · [Dry run](help:setup.money.dry-run)

<!-- anchor: setup.features.map -->
### The feature map

**Audience:** Owner · Co-owner

You want one place that says, for the main features, what members get, what it needs and who has to set it up. "Needs" lists the feature above it first, then the details outside the Features screen. "Who" is the person who must do something before it is useful; "Nobody" means it works the moment it is on.

*Workspace & access*

| Feature | What it adds for members | What it needs | Who configures |
|---|---|---|---|
| **Members directory** | The community tab: who is here, statuses, presence. | | Nobody |
| **Co-owners** | Owner permissions for appointed people, now or on succession. | | Owner |
| **Role management** | The matrix of which role holds which permission. | | Owner |
| **Giving roles** | A Roles section on each member page. | **Role management** | Owner |
| **Roles this space defines** | Roles of your own, such as treasurer or secretary. | | Owner |
| **Questions this space asks** | Your own questions in the identity form. | | Owner |
| **Personal information** | Name, address, phone and ids that letters print. | | Members |
| **Managed profiles** | Members without an account, booked and invoiced for. | **Members directory** | Administrator |
| **Member page** | One page per member. | **Members directory** | Nobody |
| **Guest visits** | A person who is not a member can ask to visit. | | Whoever admits visits |
| **Kiosk mode** | A wall tablet locked to the live plan. | A tablet and a kiosk member | Owner |
| **RFID / NFC badges** | Check in by tapping a card. | **Kiosk mode**, Android with NFC, issued badges | Owner |
| **QR badges** | Printable QR badge cards. | **Kiosk mode** | Owner |
| **Sign in with a badge** | Badge and PIN instead of typing an e-mail. | **RFID / NFC badges** | Owner, then each member |
| **NFC/RFID chair tags** | A chip on a chair opens its seat. | Tags | Owner |
| **Space QR codes** | Printable QR cards per place. | | Nobody |

*Space management*

| Feature | What it adds for members | What it needs | Who configures |
|---|---|---|---|
| **Sites** | Several addresses, each with its own registration. | At least one site | Owner |
| **Delete spaces with history** | Owners can delete a place that has past bookings. | | Nobody |
| **Admins can block seats** | Seats marked not reservable for maintenance. | | Owner |
| **Working hours** | The working day and exact-hours booking. | | Owner |
| **Public holidays** | Closure days from the holidays of a year. | | Owner |
| **Import public holidays** | Holidays of a country or region imported. | **Public holidays** | Owner |
| **Seat utilisation** | A monthly figure for how much was booked. | | Owner |
| **Member photos on the plan** | Occupants' photos on seats. | | Nobody |
| **Workspace vocabulary** | The space's own words for a few labels. | | Owner |
| **Workspace colours** | The brand colour and room colours. | | Owner |
| **Public workspace listing** | A public page with what you choose to show. | | Owner |

*Reservations & usage*

| Feature | What it adds for members | What it needs | Who configures |
|---|---|---|---|
| **Series booking** | Repeat a booking. | | Nobody |
| **Book for others** | Admins book for members. | | Nobody |
| **Desk, office & level reservations** | Book a whole desk, office or floor. | A right granted per member | Owner |
| **Admins can assign levels** | Admins assign those reservations. | **Desk, office & level reservations** | Owner |
| **Booking policies** | Past bookings, bookings outside hours, admin check-out. | | Owner |
| **Booking gate** | Every surface checks the rules and names the reason. | **Booking policies** | Nobody |
| **Auto check-in/out at day end** | Unchecked bookings complete themselves. | | Owner |
| **Usage records** | The time really used, and a request to stop billing unused time. | **Invoices** | Billing administrator |

*Calendar & coordination*

| Feature | What it adds for members | What it needs | Who configures |
|---|---|---|---|
| **Calendar tab**, **Calendar hub**, **Calendar views** | Month, week and agenda, with everything dated. | | Nobody |
| **Validations on the calendar** | Decisions shown when they were taken. | **Calendar hub** | Nobody |
| **Events tab** | The activity feed and confirmations. | | Nobody |
| **Notification feed grouping** | Notifications grouped in the feed. | | Nobody |
| **Validators by role or person** | A rule can name who validates and how many. | | Owner |
| **Chained validations** | Validations asked one after another. | | Owner |
| **Booking deletion requests** | A member asks to delete a past booking. | A validator | Owner |
| **Member notifications** | Private and group conversations. | | Nobody |
| **Messages, reworked** | Inbox bar, pin, mute, archive, drafts. | | Nobody |
| **Write to the hosts** | A person who finds your page can write to you. | A published page | Owner |
| **Mentions in groups**, **Message forwarding**, **Screen capture protection** | Messaging extras. | **Member notifications** | Nobody |

*Membership commerce*

| Feature | What it adds for members | What it needs | Who configures |
|---|---|---|---|
| **Services** | A catalogue of things to consume and pay for. | **Money tab** | Billing administrator |
| **Accessory supplements** | Priced seat accessories per half-day. | **Money tab** | Billing administrator |
| **Price negotiations** | Conditions of their own for one member. | **Money tab** | Billing administrator |
| **Payment conditions per member** | Payment terms of their own. | **Invoices** | Billing administrator |
| **Carnets** | Prepaid half-days (Beta). | **Invoices**, a pack defined | Billing administrator |

*Billing & payments*

| Feature | What it adds for members | What it needs | Who configures |
|---|---|---|---|
| **Money tab** | The Finances tab: statement, payments, expenses. | | Nobody |
| **Finances in four faces** | Statement, Payments, Invoices, Documents. | **Money tab** | Nobody |
| **Member reports** | The agreement and the monthly payments report. | **Money tab** | Billing administrator |
| **Invoices** | Immutable signed invoices (Beta). | **Money tab**, legal identity, VAT, FR or DE | Billing administrator |
| **Admins issue invoices** | Administrators issue them too. | **Invoices** | Owner |
| **Subscription invoices** | The fee invoiced before its month. | **Invoices**, a date | Billing administrator |
| **End-of-month invoices** | Usage invoiced after the month. | **Invoices** | Billing administrator |
| **Regroup invoices** | Several open invoices as one. | **Invoices** | Billing administrator |
| **The journey of an invoice** | Where each invoice stands. | **Invoices** | Nobody |
| **Invoicing wizard** | A guided month-close. | **Invoices** | Billing administrator |
| **Number sequences** | Numbering per journal. | **Invoices** | Billing administrator |
| **Online payments** | Pay online (Beta). | **Money tab**, a payment provider | Owner |
| **Payment reminders** | Reminder levels and letters. | **Invoices**, rules | Billing administrator |
| **Automatic payment reminders** | Reminders sent by themselves. | **Payment reminders** | Billing administrator |
| **Supplies from expenses** | Supplies bought become services. | **Services** | Billing administrator |
| **Scheduled expenses** | Recurring costs scheduled. | **Money tab** | Billing administrator |
| **Shared expenses** | Costs shared between members. | **Invoices** | Billing administrator |
| **Repartition wizard** | A guided split of a shared cost. | **Shared expenses** | Billing administrator |
| **Accounting book** | Who keeps the official books. | **Invoices** | Billing administrator |
| **VAT management** | VAT rates and pickers (Beta). | **Invoices**, VAT regime | Billing administrator |
| **VAT declarations** | The periodic return. | **VAT management** | Billing administrator |
| **VAT groups**, **VAT rate versions**, **VAT by counterparty** | Finer VAT handling. | **VAT management** | Billing administrator |

*Documents & information, Operations, Integrations*

| Feature | What it adds for members | What it needs | Who configures |
|---|---|---|---|
| **Document library** | Statutes, minutes, guides, per role. | | Owner |
| **PDF export** | The monthly bill as a PDF. | | Nobody |
| **Invoice PDF template** | Your texts on the invoice. | **Invoices** | Owner |
| **Report designer**, **Positioned report layouts**, **Report texts** | Designed reports. | **Invoice PDF template** | Owner |
| **Consumption report** | A monthly letter on what was used. | **Usage records** | Billing administrator |
| **VAT report** | Every taxable line, with a CSV. | **VAT declarations** | Billing administrator |
| **Data access log** | Members see who looked at their finances. | **Money tab** | Nobody |
| **Data export (Excel)** | The owner exports the data as a workbook (Beta). | The permission **Export accounting and data** | Owner |
| **Export & erasure** | A member exports and erases their own data. | | Nobody |
| **Filming mode** | Replaces real people with invented ones on screen. | | Owner |
| **Environment pairs**, **Deployments** | A test side and a real side, with deployment. | | Owner |
| **Configuration in the space file** | The whole configuration travels in the space file. | **Data export (Excel)** | Owner |
| **Instance wizard** | Create a new server from the app. | | Operator |
| **What needs you** | One ranked list of what waits for you. | | Nobody |
| **Task recorder** | Record and replay the steps of a task. | | Nobody |
| **Push notifications** | Pending confirmations on the phone. | The push service of the installation | Operator |
| **WhatsApp integration** | A chat with a member in one tap, the group link. | **Members directory** | Owner |
| **E-invoice delivery to customers** | Sending to the customer's own platform (Beta). | **Invoices**, an account | Billing administrator |
| **MCP interface** | An assistant can be connected. | A grant per person, approved by the installation | Owner, then Operator |

**Good to know**

- Names are the ones of the **Switches** list. The Core and Platform tier of each is shown there.
- A few features are not listed here. Features of comfort (help hints, animations, navigation style, regional formats) have no table row: they work the moment they are on.

**See also:** [Who does what](help:setup.before.who) · [Switch features on and off](help:user.features.processes)
