<!-- anchor: setup.training.overview -->
## Learn it in four weeks

**Audience:** Owner · Co-owner

You do not have to understand DesKilo before you start. You have to understand it in the right order, and to practise each step where a mistake costs nothing. This chapter is a four-week path of about half an hour a day, with a week of looking around first. Each week ends with a checklist: when every box is ticked, go on.

The rule of the whole path: *learn on the demo, build on a test space, and only then touch the real space.*

<!-- anchor: setup.training.week0 -->
### Week 0: look around the demo

**Audience:** Owner

You want to see the finished product before you make decisions. The demo workspace *Atelier du Marché* is invented, open to anybody and changes nothing real.

**Steps**

1. On the sign-in screen, tap **Explore the demo workspace**, then **Start exploring**. See [The demo workspace](help:user.advanced.demo).
2. Use **View as** to move between **The owner**, **An administrator** and **A member**. Do the three exercises of each person below.
3. Tap **Reset the demo** when you want it back as it started.

*As a member*

| Exercise | Expected result |
|---|---|
| Book a place for tomorrow on the plan. See [Book a place](help:user.reserve.book). | The place turns to *Reserved* on your plan and the booking is in your calendar. |
| Open your statement. See [The statement](help:user.money.statement). | You see what you owe, paid and open, for the period. |
| Send a message to another member. See [Messages](help:user.collaborate.messages). | The message appears in the conversation with a single tick (sent); a double tick appears when the other person opens it. |

*As an administrator*

| Exercise | Expected result |
|---|---|
| Open the members list and read one member's page. | You see their plan, their status and their account. |
| Answer a pending expense request (for example the printer paper). See [Validation rules](help:user.validation.overview). | The request leaves your list and its status changes for the requester. Other requests may need the owner as well and stay open. |
| Open [Invoice register](app:/invoice-register) and read one invoice. | You see the lines, the status and an integrity mark. |

*As the owner*

| Exercise | Expected result |
|---|---|
| Open [Features](app:/features) and read the cards of two processes. See [Features and processes](help:user.features.processes). | You see which capabilities are on, which are waiting for a prerequisite and why. |
| Open [Roles](app:/roles) and compare **Administrator** with **Owner**. | The owner holds every permission, the administrator a part of them. |
| Open the report editor and look at **Preview** on an invoice. See [The report editor](help:user.money.reports.editor). | You see an invoice as a member would receive it. |

*You are done when*

- [ ] You can say in one sentence what each of the three people sees that the others do not.
- [ ] You found where a request is validated, where an invoice is read and where a feature is switched.
- [ ] You wrote down three things you want in your own space and three you do not.

**See also:** [Get started](help:user.start.get-started) · [The app's words](help:user.advanced.glossary)

<!-- anchor: setup.training.week1 -->
### Week 1: Open

**Audience:** Owner

You build the place and its opening times in a test space, so that a member could book. Nothing is invoiced yet.

**Steps**

1. Create a test space of your own, or enter the test side of your space. See [Create a workspace](help:user.start.create) and [What a test space is for](help:user.advanced.test-space).
2. Set the country, currency, time zone and language. See [Country](help:user.workspace.settings.country).
3. Draw one level with one room and three seats in the [Space editor](app:/editor). See [The floor plan editor](help:user.space.overview).
4. Choose the open weekdays, the granularity and the working hours. See [Open weekdays](help:user.workspace.availability.open-weekdays).
5. Add a closure day. See [Closure days](help:user.workspace.availability.closure-days).
6. Keep the default features. Open [Features](app:/features) only to read what is on.
7. Make a booking as yourself, then check in and out. See [Check in and out](help:user.reserve.check-in).
8. In [Roles](app:/roles), tick the everyday permissions on the **User** card, then share the workspace ID with one person and let them join. See [The workspace ID](help:user.workspace.code).

**Good to know**

- A space can be booked once it has a time zone, a currency, at least one open weekday, at least one seat, and members who hold **Book and use reservations**. Everything else can wait.
- A floor plan cannot be replaced by an import once a reservation exists.

*You are done when*

- [ ] A second person found the space with its ID and booked a seat without your help.
- [ ] You can explain why the plan shows a seat as *Reserved*, *Free* or *Blocked*.
- [ ] You know your opening rules without looking: days, hours, half-day boundary.

**See also:** [Working hours](help:user.workspace.availability.working-hours) · [Booking policies](help:user.workspace.availability.policies)

<!-- anchor: setup.training.week2 -->
### Week 2: Run

**Audience:** Owner · Administrator

You decide who may do what, what each member pays, and who is told what. You do it with a second person, because rules only show themselves when someone else meets them.

<p><img src="images/setup-training-roles.en.jpg" width="280"></p>

**Steps**

1. Role-play a validation with a second person. Make them an administrator, set one required validation for bookings, then book as a member and let the administrator confirm. See [Validation rules](help:user.validation.overview) and [Roles](help:user.roles.space).
2. Raise the required number to two and watch the request wait. Then reduce it again. A rule that needs more validators than exist leaves requests waiting for ever.
3. Write the tariffs on paper first: subscription levels in per cent, the fee band of each level, the price beyond the allowance. Then enter them in Billing, and give the level to the member in Members & plans. See [Members & plans](help:user.members.subscription).
4. Give the second person a level and let them book beyond their allowance. Read the statement.
5. Test the notifications: a message, a pending request, a cancelled booking. See [Notifications](help:user.collaborate.notifications).
6. Open [Roles](app:/roles) and check what an administrator may do. Remove one permission and see what disappears for them.

**Good to know**

- In-app notifications work at once. Push notifications also need the operator's setup, so a test may show nothing on a phone. Ask your operator.
- Automatic payment reminders run once a day on the server when the installation has its scheduler, and also when an authorised person opens Finances.

*You are done when*

- [ ] You watched a request pass through the validation you configured, and one stay waiting.
- [ ] Your tariffs fit on one sheet and the statement of the test member matches your arithmetic.
- [ ] You know who is told what.

**See also:** [Validation rules](help:user.validation.overview) · [Roles and permissions](help:user.roles.matrix)

<!-- anchor: setup.training.week3 -->
### Week 3: Grow

**Audience:** Owner · Billing administrator

You make the first invoice, in two languages, in the test space, with your accountant looking over your shoulder.

**Steps**

1. Fill in your legal identity and VAT regime together with your accountant. See [Your legal identity](help:user.money.legal.identity) and [VAT regime](help:user.money.vat.regime).
2. Close a month and issue a trial invoice in the test space. See [The month-close wizard](help:user.invoicing.wizard).
3. Open the invoice with the design of **Professional**, then in a second language. See [One design per language](help:user.money.reports.languages).
4. Export the register for the period in the format your accountant uses. See [Accounting exports](help:user.invoicing.accounting-export).
5. Ask the accountant three questions: Are the mentions right? Is the treatment of VAT right? Can you read the file?
6. Write down the answers. They become the brief for the real space.

**Good to know**

- The app issues invoices in France and Germany only today. It refuses to issue when an essential is missing and names what is missing.
- Invoices in a test space carry a watermark that says so.

> **Careful** After the first issued invoice in the real space, the invoice is frozen, its number cannot be reused and that month is locked for the member. Corrections go through a void, a credit note or a refund.

*You are done when*

- [ ] One trial invoice exists, read by your accountant, in two languages.
- [ ] You exported a file for the accountant and they opened it.
- [ ] You have the written answers.

**See also:** [Documents and reports](help:setup.reports.overview) · [The invoice register](help:user.invoicing.register)

<!-- anchor: setup.training.week4 -->
### Week 4: go live

**Audience:** Owner · Co-owner

You move from rehearsal to the real space, and you do not do it alone: five people invite you to watch.

*The go-live checklist*

1. Decide whether you keep your test space as your rehearsal side or create the real space. If the space has two sides, deploy from the test side to the real one. See [Deploy between the two sides](help:user.advanced.deploy).
2. If you create the real space instead, repeat what worked: the same country, currency and time zone, the same plan, rules, tariffs and roles. A template, a configuration transfer or a deployment between the two sides carries most of it. See [Export, import and configuration](help:user.workspace.export.space-xml).
3. Enter your legal identity again in the real space. A template never carries it; a deployment between the two sides does, but never credentials. Check it either way.
4. Declare the space production only when the invoices that leave it are really owed. See [Enter the real side or the test side](help:user.advanced.enter-environment).
5. Invite five people, not fifty. See [The invitation message](help:user.workspace.settings.invitation-message).
6. Watch their first bookings. Open [Reserve](app:/reserve) and read what the **Get started** card still asks for.
7. After one week, review: which question did they ask, which rule surprised them, which setting do you now want to change.

**Good to know**

- Credentials such as e-invoice tokens or payment provider keys never travel between spaces. Enter them again.
- A recovery copy before the first invoice is cheap. See [Documents and reports](help:setup.reports.accountant).

*You are done when*

- [ ] Five real people booked without asking you how.
- [ ] You know where to look when something does not work.
- [ ] You scheduled your first month-close.

**See also:** [A space has two sides](help:user.advanced.environments)

<!-- anchor: setup.training.glossary -->
### Twenty words of the setup

**Audience:** Owner · Co-owner

The decisions you will meet have names. This is what each one means in DesKilo.

| Term | Meaning |
|---|---|
| Granularity | The unit of a booking: half-day, day, hour or minutes. It decides how the plan is cut. |
| Half-day boundary | The time that separates a morning from an afternoon, set with the start and end of the working day. |
| Overage | Use beyond a member's allowance. You choose to block it, charge it as it comes or sell packages. |
| Fee band | The price of a subscription, by the percentage of the allowance the member takes. |
| Validation domain | A kind of request with its own rule: a booking, an expense, a refund and others. |
| Quorum | The number of validators a request needs. More than the people who can validate leaves it waiting. |
| Exigibility | The moment VAT falls due — the tax point: on receipt of payment, in the month the service is performed or at the invoice, as the country's law sets, unless the business opted for another basis. |
| Numbering reset | How often the invoice number starts again. It cannot be more frequent than the date printed on the invoice. |
| Environment pair | A test side and a real side of one space. |
| Template | A saved setup (plan, rules, tariffs, roles) you can apply to a new space. It never carries identity or payment details. |
| Readiness | The checklist at the top of the workspace settings that says what is missing before people can book, and before the first invoice. |
| Held back | A feature that is on but waits for another one that is off. |
| Kiosk | A shared screen at the door where members check in and out. |
| Badge | A card or tag a member shows to check in at a kiosk. |
| Managed profile | A member you run for someone who has no account yet, handed over later with a code. |
| Closure day | A day when the space is shut, such as a holiday. |
| Wording (lexicon) | The words you replace in the app to match your place, such as how a member is called. |
| Recovery export | A copy of the settings and data you save before a big change. It shows in the readiness list. |
| Offered level | A subscription level you offer to members. It must exist before anyone picks it. |
| Seller kind | The type of organisation you are when you invoice. It decides the default mentions. |

**See also:** [The app's words](help:user.advanced.glossary)

<!-- anchor: setup.training.help -->
### Where to ask for help

**Audience:** Everyone

You are stuck on one field or one decision.

**Steps**

1. Tap the **?** next to a field. The guide opens at that field.
2. Open [Help](app:/help) and use **Contents** to jump. Tips on screens can be paged with **Next tip**.
3. When it is the app that fails, open **Support details** and send the preview. See [Support details](help:user.advanced.support).
4. For a decision about law or tax, ask your accountant. For your installation, ask its operator. For the way other owners did it, ask your community.

**Good to know**

- The guide works offline and in your language.
- Contact the support with the file from **Support details**. It holds no identity and no business record.

**See also:** [Where to get more help](help:user.advanced.help)

<!-- anchor: setup.training.cheatsheet -->
### The cheat sheet

**Audience:** Owner · Co-owner

The whole setup on one page. *Reversible* tells you whether you can change your mind after you have done it.

| Step | Where in the app | How long | Reversible? |
|---|---|---|---|
| 1. Country, currency, time zone, language | [Workspace settings](app:/workspace-settings) | 5 minutes | Yes, until the first document or payment; then the currency and the country are locked |
| 2. Floor plan | [Space editor](app:/editor) | 30 minutes | Yes, until the first reservation; then edit one object at a time |
| 3. Opening rules | Availability | 10 minutes | Yes |
| 4. Features | [Features](app:/features) | 10 minutes | Yes. Switching off stops new use and deletes nothing |
| 5. Roles and validation | [Roles](app:/roles) | 20 minutes | Yes, but a rule needing too many validators blocks requests |
| 6. Tariffs and levels | [Billing](app:/billing) (levels are assigned in Members & plans) | 1 hour | Yes for the future; issued amounts stay |
| 7. Legal identity and VAT regime | Legal identity | 1 hour with your accountant | Careful after the first invoice |
| 8. Invoice numbering and mentions | Legal identity | 20 minutes | No, after the first invoice |
| 9. Report designs | [Report editor](app:/report-editor) | 1 hour | Yes for new documents; issued ones stay |
| 10. Invitation message | Workspace settings | 10 minutes | Yes |
| 11. Notifications test | Messages, requests | 20 minutes | Yes |
| 12. Trial invoice on the test side | Invoicing | 1 hour | The test side only |
| 13. Real space or deploy | [Me](app:/me) | 1 hour | Careful: production means invoices are owed |
| 14. Invite the first five | Workspace settings | 10 minutes | Yes |

**See also:** [The sequence to follow](help:setup.reports.sequence)
