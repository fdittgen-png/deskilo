<!-- anchor: setup.place.overview -->
## Build the place

This chapter makes the first level, **Open**: where the space is, what it looks like, when it is open and what the rules of booking are. In about twenty minutes the space can be booked. The example is *Atelier du Marché*, an association in Pézenas with two floors and a room.

In this chapter:
- [Country, currency, time zone and language](help:setup.place.where)
- [The floor plan](help:setup.place.plan)
- [Opening times and booking rules](help:setup.place.times)
- [Closing days and public holidays](help:setup.place.closure)
- [Check your space](help:setup.place.check)

<!-- anchor: setup.place.where -->
### Country, currency, time zone and language

**Audience:** Owner · Administrator

You want the space to know where it lives. These four choices drive more than they seem to.

<p><img src="images/setup-place-country.en.jpg" width="280"></p>

*What each choice drives*

| Choice | What it decides |
|---|---|
| **Country** | The currency and time zone it proposes, and the public holidays offered as closure days (see below). |
| **Currency** | How every amount is shown and counted. |
| **Time zone** | What a working day, a half-day boundary and a closure day mean; a member abroad sees the space's day. |
| **Workspace language** | The language invitations and shared message references are written in by default. |

**Steps**

1. Open [Workspace](app:/workspace-settings) and go to **General details**.
2. Pick the **Country**; the **Currency** and **Time zone** follow, and you can correct them. For Atelier du Marché: France, EUR, Europe/Paris.
3. Pick the **Workspace language**, then tap **Save**.

> **Careful** Choose country and currency right on day one. Amounts are stored as plain numbers, so changing the currency after money exists would mislabel everything already counted.

**Good to know**

- The app lists many countries, but issuing invoices inside DesKilo works for France and Germany only today. Elsewhere you keep statements and issue invoices outside the app.
- The workspace language is not your own app language, which is in your personal settings.

**See also:** [Country](help:user.workspace.settings.country) · [Currency and time zone](help:user.workspace.settings.currency-timezone) · [Workspace language](help:user.workspace.settings.language)

<!-- anchor: setup.place.plan -->
### The floor plan

**Audience:** Owner · Administrator

You want the plan on screen to look like the real place. It is built in four layers: levels, then offices (rooms), then desks, then seats. A member books a seat; a seat is what the readiness list counts.

<p><img src="images/setup-place-rooms.en.jpg" width="280"></p>

**Steps**

1. Sketch on paper: floors, rooms, desks, seats.
2. Open [Workspace editor](app:/editor) and add the floors with **Add level**.
3. Open a floor and draw each room with **Office**, then **Desk** and **Seat** inside it.
4. If a team may take a room or a floor for a day, switch on whole-room booking in its properties.

**Good to know**

- Start small: a first floor, one room, a few seats. Everything can be added afterwards.
- A whole floor, office or desk can be booked only if **Desk, office & level reservations** is on and the member has the permission.
- The built-in template A tiny space gives you two levels, four desks and eight seats to adjust.
- Deleting a floor removes everything on it, and a plan import is refused once reservations exist.

**See also:** [Add, rename and delete floors](help:user.space.editor.levels) · [Draw rooms, desks and seats](help:user.space.editor.rooms) · [Let members book a whole floor](help:user.space.editor.level-booking)

<!-- anchor: setup.place.times -->
### Opening times and booking rules

**Audience:** Owner · Administrator

You want bookings to follow the rhythm of your place. One screen, **Availability**, holds the days, the shape of a booking, the working hours and the rules. The server applies them everywhere: plan, booking sheet, scanned codes and kiosk.

<p><img src="images/setup-place-availability--times.en.jpg" width="280"></p>

**Steps**

1. Open [Availability](app:/availability).
2. Choose the **Open weekdays** (at least one) and the **Booking granularity**.
3. Set the **Working hours**: **Day starts**, **Half-day boundary**, **Day ends**.
4. Under **Booking policies**, decide on **Allow past bookings**, **Outside the opening hours** and the **Booking limits**.

<p><img src="images/setup-place-availability--rules.en.jpg" width="280"></p>

*Recommended starting points (suggestions, not rules; the default for **Outside the opening hours** is **Charged**, and the association template does not change it)*

| Scenario | Granularity | Hours | Outside hours | Past bookings | Limits |
|---|---|---|---|---|---|
| A few shared desks | **Free time period** or **1-hour slots** | Day 8:00–17:00 | **Free** | Off | One booking at a time; horizon 30 days |
| An association room (Atelier du Marché) | **Half days (morning & afternoon)** | 7:00, boundary 13:00, end 19:00 | **Off** | Off | One booking at a time; horizon 90 days |
| A coworking with half-days | **Half days (morning & afternoon)** | 8:00, boundary 12:00, end 18:00 | **Charged** | Off | One or two at a time; horizon 90 days |

**Good to know**

- Outside the opening hours, **Off** refuses everything, **Spontaneous only** allows walk-ups, **Free** allows without counting, **Charged** counts like ordinary usage except on a day the member already holds a regular booking.
- The day must run in order: start, then boundary, then end; the minimum duration cannot exceed the maximum.
- A booking ends on the day it starts. Past bookings are off by default; booking an earlier window on the same day is always allowed.
- Half-day and full-day windows also drive check-in and invoicing, so settle the hours before you set prices.

**See also:** [Open weekdays](help:user.workspace.availability.open-weekdays) · [Granularity](help:user.workspace.availability.granularity) · [Working hours](help:user.workspace.availability.working-hours) · [Outside the opening hours](help:user.workspace.availability.outside-hours) · [Booking limits](help:user.workspace.availability.limits)

<!-- anchor: setup.place.closure -->
### Closing days and public holidays

**Audience:** Owner · Administrator

You want the space to be shut on holidays without anyone booking them by mistake.

<p><img src="images/setup-place-availability--closure.en.jpg" width="280"></p>

**Steps**

1. In [Availability](app:/availability), go to **Closure days**.
2. Tap **Add public holidays** (if you do not see it, switch on the feature *Public holidays* first; it is off by default) to create a whole year in one go, or **Add closure day** for a single date such as an inventory day.
3. Check the list and remove any day you actually work.

**Good to know**

- Built-in holiday lists exist for France and Germany. For other countries switch on *Public holidays* and *Import public holidays* (open data, needs a connection). Nothing is created before you confirm.
- A booking on a closure day is refused, and the plan shows the day as closed with its reason.
- Months that are already invoiced are skipped, so add closure days before the month closes.

**See also:** [Closure days](help:user.workspace.availability.closure-days) · [Public holidays](help:user.workspace.availability.public-holidays)

<!-- anchor: setup.place.check -->
### Check your space

**Audience:** Owner · Administrator

You want proof that the space is ready, before you invite anyone. Two cards say so.

<p><img src="images/setup-place-get-started--card.en.jpg" width="280"></p>

**Steps**

1. Open [Workspace](app:/workspace-settings): the card **Setting up this space** lists each area with its state, and the next step.
2. Open [Reserve](app:/reserve). Owners and administrators with the configuration permission see the card **Get started in** your space. If something is missing it says **Before anyone can book here**, with **Finish setting up**.
3. Book one seat yourself as a test, then cancel it.

**Good to know**

- Ready means ready for a first booking: opening days, time zone, currency, at least one seat, and enough validators.
- Anything optional, such as tariffs or payments, can be set aside with **Later** and does not block opening.
- Both cards depend on the feature *Get started card*.
- **Not now** hides the card on this device; the view menu on the plan brings it back with **Get started**.

**Result** A space that members can book. Next: invite the first people, then the roles and tariffs of the second level.

**See also:** [The Get started card and the tips](help:user.start.get-started) · [Invite people with the workspace ID](help:user.workspace.code) · [Roles](help:user.roles.matrix)
