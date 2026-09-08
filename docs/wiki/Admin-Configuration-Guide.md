# Admin guide — configuring the space

For the owner who sets the space up: what every parameter decides, in the
order the questionnaire asks, then the master data, then the floor plan
and its images. The technical side is in the
[technical guide](Admin-Technical-Guide); moving a configuration between
a development and a production space is in the
[environments guide](Environments-Guide).

*This guide is being written; sections carry their outline and grow with
each release.*

<!-- anchor: config.setup.questionnaire -->
## The setup questionnaire

The web questionnaire asks, in order, only what your earlier answers make
possible, and produces the space file the app imports. Every question
there exists as a parameter in the app, and every parameter in the app
exists there — that symmetry is a rule, not a coincidence.

<!-- image: config-setup-questionnaire -->

<!-- anchor: config.identity.legal -->
## Identity and legal mentions

The organisation's form, its registrations, its addresses, and every
mention its invoices must print.

<!-- anchor: config.vat.overview -->
## VAT

Regime, rates, groups, dated rate versions, the counterparty dimension,
declarations. The rate a supply carries is decided by what it is (the
group), who buys it (the treatment) and when it happened (the tax point).

<!-- anchor: config.tariffs.overview -->
## Tariffs and billing rules

Subscription percentages and their fee bands, overage, what a half-day
is, what a month bills, and when it bills it.

<!-- anchor: config.services -->
## Services

<!-- anchor: config.packages -->
## Day packages

<!-- anchor: config.accessories -->
## Accessories

<!-- anchor: config.sites -->
## Sites

Several addresses under one organisation: which one a document names,
which registration it carries, and how a member is attached to one.

<!-- anchor: config.availability -->
## Availability and booking rules

Opening days and hours, closure days, granularity, horizons, limits, and
what happens outside the opening hours.

<!-- anchor: config.plan.overview -->
## The floor plan

<!-- anchor: config.plan.levels -->
### Levels

A level is a floor or a room set. It carries its site, its background
image, its price when it is bookable whole.

<!-- anchor: config.plan.offices -->
### Offices, desks and seats

The three nested shapes, their footprints on the grid, the orientation a
seat faces, and what makes each of them bookable on its own.

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

Pictures placed on the plan itself — a logo, a sign, a photograph of a
corner — with their own position and size.

<!-- anchor: config.documents -->
## Document library

<!-- anchor: config.roles -->
## Roles and permissions

<!-- anchor: config.validation -->
## Validation rules

<!-- anchor: config.features -->
## Features

Every functionality is a switch. What a switch turns off, what it never
turns off (the arithmetic already applied), and the requirement graph
that decides which switches are available at all.
