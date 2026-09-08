# Admin guide — configuring the space

For the owner who sets the space up: what every parameter decides, in the
order the questionnaire asks, then the master data, then the floor plan
and its images. The technical side is in the
[technical guide](Admin-Technical-Guide); moving a configuration between
a development and a production space is in the
[environments guide](Environments-Guide).

<!-- anchor: config.setup.questionnaire -->
## The setup questionnaire

The web questionnaire asks, in order, only what your earlier answers make
possible, and produces the space file the app imports. Every question
there exists as a parameter in the app, and every parameter in the app
exists there — that symmetry is a rule, not a coincidence.

<!-- image: config-setup-questionnaire -->

<!-- anchor: config.identity.legal -->
## Identity and legal mentions

*Workspace settings → Legal identity & e-invoicing.* Fill this before
the first document leaves the building: an invoice that names no seller
properly is not an invoice.

The **organisation type** — company or association — decides which
clause defaults print. The late-payment penalty, the recovery indemnity
and the early-payment discount are obligations *between professionals*,
so an association's documents drop those defaults while still printing
anything you type yourself.

Then, in order: the **legal form and capital** printed under the name;
the **register** a reader can check you with (RCS and city for a
company, RNA W… plus SIRET for an association); the **VAT regime**,
which decides whether the norm wants a VAT number or a company
registration number from you; the **structured address**, which is what
an e-invoice carries because a machine cannot split one line reliably;
and the eight invoice mentions.

Every one of those fields is documented, field by field, in the
[user guide](User-Guide#11a-legal-identity-vat--mentions) — the help
symbol beside each opens exactly its paragraph.

**Payment instructions** (the bank block a document prints) are a
separate entity, so they deploy between a development and a production
space on their own.

<!-- anchor: config.vat.overview -->
## VAT

The rate a supply carries is decided by three things, never by one: what
it is (**the group**), who buys it (**the treatment**), and when it
happened (**the tax point**). That is the ERP shape, and it is why a
rate change never rewrites an old document.

**Rates** are named, carry a percentage and a fiscal group, and one is
the default. A rate is **versioned by date**: changing 20 % to 21 %
adds a version valid from a date, it does not edit the old one. Every
document already issued keeps the version that was in force when it was
issued, frozen on the document itself; only supplies dated on or after
the new version's start use it.

**Groups** are what a supply *is* — standard, reduced, zero, exempt,
out of scope. A service, a tariff, an accessory and a package each
carry a group, not a percentage, so a country's rate table can change
underneath them without touching the catalogue.

**Treatments** are what the counterparty makes of it: domestic,
intra-EU business (reverse charge, the customer self-assesses under
art. 196), intra-EU consumer, export. A customer's country and VAT
number decide which applies, and the e-invoice check refuses to send a
reverse-charge document until that VAT number is present, because it is
what proves the tax is theirs.

**When VAT falls due** is a workspace setting: *on invoices* (due when
you issue) or *on receipts* (due the day the customer pays). France
puts services on receipts unless you opt out; Germany calls it
*Ist-Versteuerung*, Italy *IVA per cassa*. On receipts, a declaration
period covers the payments received inside it, a part payment carries a
share of every rate in the document in proportion, and the rounding
goes to the widest rate so the total matches what was received exactly.

**Declarations** are built for a period from the documents (or the
payments) it contains, mapped to the boxes your country's form uses —
CA3 in France, UStVA in Germany — and produced as PDF and XML. A
declaration goes draft → submitted, and a submitted one is never
recomputed.

A country's full rate catalogue ships with the app (EU27, CH, NO, CA);
keeping it current when a government changes a rate is yours.

<!-- anchor: config.tariffs.overview -->
## Tariffs and billing rules

A **tariff** is a subscription percentage with a monthly fee: 25 %,
50 %, 100 % of the working half-days in a month, each with its own
price and its own VAT group. A member holds one tariff; the percentage
becomes an allowance of half-days, and the fee is what the month costs
whether or not the allowance is used.

**A half-day** is the unit everything counts in. What counts as one is
decided by the opening hours and the granularity: a morning, an
afternoon, or a slot on the grid you set.

**Overage** is what happens past the allowance. Either the extra
half-days are refused, or they are charged at the overage price per
half-day, which is a separate price with its own VAT group. Extra
half-days may also be requested and granted per member.

**When a month bills** is a rule, not a habit: the subscription line is
issued *ahead* of the month it covers, and the usage lines follow it.
Each subscription line names its month — *September 100 %* — so an
invoice is always tied to the period it pays for.

A **month's arithmetic is frozen on the document.** Changing a tariff's
price changes what the next month costs; it never changes an invoice
already issued, and it never re-opens a month already settled.

<!-- anchor: config.services -->
## Services

Anything sold that is not a seat: a meeting room hour, a printing
bundle, a locker, a coffee subscription. A service has a name, a price,
a VAT group and a unit, and it can be put on an invoice by an
administrator or attached to a package.

Services deploy between a development and a production space as their
own entity — and because they carry a VAT group rather than a
percentage, the VAT rates travel with them.

<!-- anchor: config.packages -->
## Day packages

A day sold as one thing: a desk plus a locker plus two hours of meeting
room, at one price. A package bundles services and a seat allowance,
carries its own VAT group, and appears on the invoice as one line with
its parts listed underneath when the design asks for them.

Use a package where a member should not have to assemble the day
themselves, and a tariff where the month is the unit.

<!-- anchor: config.accessories -->
## Accessories

Equipment attached to a place rather than sold on its own: a second
screen, a docking station, a standing desk converter, a whiteboard. An
accessory has a name, an optional price with its VAT group, and it is
placed on the plan against a seat, a desk or an office.

On the plan, an accessory is part of what a booking gets. When it
carries a price, booking the place adds its own invoice line at its own
rate — which is why the accessory catalogue and the VAT rates deploy
together.

<!-- anchor: config.sites -->
## Sites

Several addresses under one organisation: which one a document names,
which registration it carries, and how a member is attached to one.

<!-- anchor: config.availability -->
## Availability and booking rules

*Workspace settings → Availability.* Every rule here is enforced by the
server, not by the screen, so a rule you set is a rule that holds even
against a stale app.

**Opening days and hours** define the working day and, with the
granularity, what a half-day is. **Closure days** are dates the space
is shut: a booking touching one is refused with that reason named.

**Granularity** is what a booking may be — a half day, a full day, or a
slot on a grid of N minutes. A booking that does not sit on the grid is
refused and told the step.

**The horizon** is how far ahead bookings open. **Minimum and maximum
duration** bound a single booking. **Simultaneous reservations** bound
how many a member may hold open at once, per workspace and overridable
per member. A booking always ends on the day it starts.

**Past bookings** are refused unless you allow them; a same-day
retroactive booking is legal because someone who sat down at nine
should be able to say so at ten.

**Outside the opening hours** has three modes: *off* (refused),
*walk-up only* (a spontaneous check-in is possible, booking ahead is
not), or *charged* (allowed and counted). Each has its own refusal
sentence, so a member learns which door is closed.

**Validation rules** decide which acts need a human decision — see
below.

<!-- anchor: config.plan.overview -->
## The floor plan

The plan is what members book on. It is built from three nested shapes
over a background image, on a grid whose cell is the unit of placement.
Build it in this order: the level and its background first, then the
offices, then the desks and seats. Everything below is traced over the
image, never drawn from memory.

<!-- anchor: config.plan.levels -->
### Levels

A level is a floor, or a set of rooms treated as one. It carries its
**site** (which address it belongs to), its **background image**, and,
when it is bookable as a whole, its **price per half-day** and its VAT
group.

*Bookable as a whole* is a switch on the level itself. Without it, a
request to reserve the whole level is refused and says which switch is
missing — the refusal names the toggle rather than blaming the member.

<!-- anchor: config.plan.offices -->
### Offices, desks and seats

**An office** is a room inside a level. **A desk** is a table inside an
office or standing free on the level. **A seat** is a place at a desk —
what a member actually books. Each has a footprint on the grid; a seat
occupies six cells across and four deep, which is what sets the scale
of everything else.

A seat carries its **orientation** (which way the chair faces, so the
plan reads like the room), its **equipment and accessories**, and its
**tags** — a badge or NFC tag makes the seat scannable at the door.

**Bookable as a whole** exists on the desk and the office too: turn it
on and the desk or the room can be reserved in one booking instead of
seat by seat. A whole booking blocks its children for the period, and a
child booking blocks the whole.

**Blocking** a place takes it out of service for maintenance without
deleting it: it stays on the plan, greyed, and every booking attempt is
refused with that reason. Blocks never travel between a development and
a production space, because a maintenance block is a fact about one
building on one day.

<!-- anchor: config.plan.background -->
### The background image

A plan reads best over a drawing of the actual room. The image is
per level, sits under the grid, and never moves once the places are
traced over it.

<!-- image: config-plan-background -->

<!-- anchor: config.plan.ai-image -->
### Making that image from photographs, with an AI

You do not need an architect's drawing. Photograph the room, ask an image
model for a top-down plan, and use its answer as the background.

**Photograph it well.** Stand in each corner, hold the camera at chest
height, and take one picture per corner plus one along each long wall.
Include the whole floor in at least two of them. Measure one thing —
a table's length, a door's width — and write the number down: that is
what will set the scale.

**Ask for a plan, not a picture.** The prompt that works asks for an
orthographic top-down view, flat colours, no perspective, no shadows, no
people, and furniture as simple footprints:

> From these photographs of one room, draw a top-down orthographic floor
> plan of it. Straight walls, true right angles, no perspective and no
> shadows. Show only the fixed elements: walls, doors with their swing,
> windows, radiators, pillars, kitchen and sanitary blocks, and the
> footprint of each large piece of furniture as a plain outlined shape.
> Muted, light colours on a white ground; no text, no labels, no
> dimensions, no people, no decoration. The [table] in the room is
> [1.60] m long — draw everything to that scale. Output a single image,
> [4:3], at least 1600 pixels wide.

**Check the scale before you trace.** Import the image as the level's
background, then measure the object you noted against the grid: a seat
occupies six cells across and four deep, and a cell is the app's unit of
placement. Scale the image until the real object matches its true size on
the grid; everything traced afterwards is then honest.

**Trace, do not draw.** Place offices, desks and seats over the image.
The background is a guide for the eye; what the app books are the places
you place.

**What not to accept.** A perspective view, a rendering with shadows, a
plan with invented rooms, or one where the furniture does not match the
photographs. Ask again with a tighter prompt rather than correcting a
wrong plan by hand.

<!-- anchor: config.plan.images -->
### Plan images

Pictures placed *on* the plan rather than under it — a logo by the
entrance, a sign, a photograph of a corner — each with its own position
and size on the grid. They are decoration: nothing is booked on them,
and they sit above the background and below the places.

They travel with the plan when it deploys, and they are carried in the
space file on export.

<!-- anchor: config.documents -->
## Document library

Files the space keeps and shows to the people entitled to see them: the
house rules, an insurance certificate, a floor evacuation plan, a
member agreement template. Each document carries the roles that may
read it, so the library is one place with per-role visibility rather
than several folders.

Document *designs* — the layout of an invoice or a letter — are a
different thing, and live in the
[technical guide](Admin-Technical-Guide#documents-and-reports).

<!-- anchor: config.roles -->
## Roles and permissions

*Settings → Roles.* A matrix: the roles down one side, the permissions
across. Owner, co-owner, administrator, member — and every permission
is a cell you can turn on or off, except the ones an owner always has.

A permission is asked by the server through one function, so a
permission you revoke is revoked everywhere at once: the screen hides
the button, and the RPC behind it refuses anyway.

The environment permissions live here too — *Enter the production
workspace*, *Deploy to development*, *Deploy to production* — and are
explained in the
[environments guide](Environments-Guide#who-may-do-what).

<!-- anchor: config.validation -->
## Validation rules

Which acts need a human decision before they take effect, and who
decides. Each domain has its own rule: a member joining, a reservation
being deleted, an invoice being written off, extra half-days being
granted, and the rest.

Per domain you choose whether a request is raised at all, and whether
an administrator's or an owner's own request is **auto-validated** — in
which case the event is recorded already settled rather than pinging a
validator to approve their own action.

A decision is always an event: who decided, when, and on what. Nothing
is validated silently, and a decision taken by the system says so.

<!-- anchor: config.features -->
## Features

Every functionality is a switch. What a switch turns off, what it never
turns off (the arithmetic already applied), and the requirement graph
that decides which switches are available at all.
