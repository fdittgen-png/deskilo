<!-- anchor: user.space.overview -->
## Your space, set up by you (Workspace settings)

This chapter is for the people who run a space: owners, co-owners and the administrators they trust with the settings. Here you draw the floors, decide who may come in and when, choose which features exist, give the space its look and its words, and take a copy of everything.

In this chapter:
- [Draw your floors, rooms and desks](help:user.space.editor.levels)
- [Invite people with the workspace ID](help:user.workspace.code)
- [Say when the space is open](help:user.workspace.availability.open-weekdays)
- [Switch features on and off](help:user.features.processes)
- [Fill in the workspace settings](help:user.workspace.settings.country)
- [Give the space its colours and words](help:user.workspace.settings.wording)
- [Decide who may do what](help:user.roles.matrix)
- [Run a wall tablet and badges](help:user.kiosk.mode)
- [Keep a library of documents](help:user.documents.add)
- [Export and import the space](help:user.workspace.export.space-xml)

> **Tip** Most screens in this chapter sit in the menu under **Workspace**, **Availability**, **Features** and **Roles**. Each entry only appears for people who hold the permission it needs, and some only while their feature is switched on. An administrator sees these screens only if the owner has given them the permission in the role matrix.

<!-- anchor: user.space.editor.levels -->
### Space editor: add, rename and delete floors

**Audience:** Owner · Administrator

You want to give the building its floors, in the order people expect them. The **Workspace editor** lists every floor of the space.

<p><img src="images/user-space-editor-levels.en.jpg" width="280"></p>

**Steps**

1. Open [Workspace editor](app:/editor), or tap **Edit workspace** on the Reserve screen.
2. Tap **Add level**, type the name and tap **Save**.
3. Drag the handle at the left of a floor to change the order.
4. Tap the three dots (**Level actions**) to **Rename** or **Delete** a floor.
5. Tap a floor to draw on it.

**Good to know**

- Deleting a floor removes every office, desk and seat on it. The confirmation says what becomes of bookings that point at them.
- The line under each floor tells you whether it is **Bookable as a whole** or **Not bookable as a whole**.
- Without any floor the editor says **No levels yet. Add the first floor of your workspace.**

**See also:** [Book a whole floor](help:user.space.editor.level-booking) · [Draw rooms, desks and seats](help:user.space.editor.rooms)

<!-- anchor: user.space.editor.level-booking -->
### Let members book a whole floor

**Audience:** Owner · Administrator

You want one team to be able to take a complete floor for a day.

<p><img src="images/user-space-editor-level-booking.en.jpg" width="280"></p>

**Steps**

1. In the [Workspace editor](app:/editor), tap the layers button on the floor's row.
2. Switch on **Bookable as a whole**.
3. Type the **Price per half-day**.
4. Tap **Save**.

**Good to know**

- The layers button is filled when the floor is bookable as a whole.
- Booking a whole floor, office or desk also needs the **Desk, office & level reservations** feature. Each member needs the level-reservation right; administrators have it automatically. See [A feature switch](help:user.features.switch).

**See also:** [Office and desk properties](help:user.space.editor.office)

<!-- anchor: user.space.editor.rooms -->
### Draw rooms, desks and seats

**Audience:** Owner · Administrator

You want the plan on screen to look like the real floor. Everything sits inside a room: you draw a room, put desks in it, then put seats on the desks.

<p><img src="images/user-space-editor-rooms.en.jpg" width="280"></p>

**Steps**

1. Open a floor from the [Workspace editor](app:/editor). An empty floor offers **Draw the first room**.
2. Tap **Office** and drag on the grid to draw a room.
3. Tap **Desk** and drag inside the room to draw a desk.
4. Tap **Seat**, then tap a desk to add a seat to it.
5. Tap **Image**, then tap where an illustration should go.
6. Tap an element to select it. The bar at the bottom offers **Duplicate**, **Properties** and **Delete**.

**Good to know**

- Tapping the armed tool a second time puts it down again, and the canvas goes back to selecting.
- The app refuses a shape that is **Overlaps an existing element.** or **Must be fully inside an office.** Seats can only be placed on a desk, and a desk that is full says **No room left on this desk.**
- The picture button at the top right sets, replaces or removes the **Background image** of the floor, for example a scan of the real plan.
- Deleting a room takes its desks and seats with it.

**See also:** [Seat properties](help:user.space.editor.seat) · [Desk transparency](help:user.workspace.settings.desk-transparency)

<!-- anchor: user.space.editor.office -->
### Name an office or a desk and put a price on it

**Audience:** Owner · Administrator

You want a room or a desk to carry its own name, and to be bookable in one piece.

<p><img src="images/user-space-editor-office.en.jpg" width="280"></p>

**Steps**

1. Select the office or the desk on the floor and tap **Properties**.
2. Change **Office name** (or **Desk name**).
3. Switch on **Bookable as a whole** if somebody may reserve it entire, with everything inside it.
4. Type the **Price per half-day** that appears.
5. Tap **Save**.

**Good to know**

- The price field only appears while the switch is on.
- A room that is bookable as a whole can only be reserved while nothing inside it is booked.

**See also:** [Book a whole floor](help:user.space.editor.level-booking) · [Seat properties](help:user.space.editor.seat)

<!-- anchor: user.space.editor.seat -->
### Set up a seat

**Audience:** Owner · Administrator

You want a seat to say which way the chair faces, what comes with it and when it is out of service.

<p><img src="images/user-space-editor-seat.en.jpg" width="280"></p>

**Steps**

1. Select the seat on the floor and tap **Properties**.
2. Change **Seat name**.
3. Pick the **Sitting direction**: the arrow shows which way the chair faces on the plan.
4. Choose a **Chair type**.
5. Tap the **Accessories** that belong to this seat. A price shown beside one is a supplement per half-day.
6. If the seat carries a tag, type its number into **NFC/RFID tag**, or use **Read a tag now**. The tag field appears when the **NFC/RFID chair tags** feature is on, and reading needs a device that can read tags.
7. Switch on **Blocked (maintenance)** to take the seat out of service, then tap **Save**.

**Good to know**

- A tag number can only belong to one chair: **This tag is already linked to another chair.**
- With no accessory yet, the sheet offers **No accessories yet — set them up**.

**See also:** [NFC badge check-in](help:user.badges.nfc)

<!-- anchor: user.workspace.code -->
### The workspace ID

**Audience:** Owner · Administrator

You want people to find your space and ask to join. The **Workspace ID & QR** screen shows the member invite: a QR code and the ID behind it.

<p><img src="images/user-workspace-code.en.jpg" width="280"></p>

**Steps**

1. Open [Workspace ID & QR](app:/workspace-code). The **Member invite** tab is shown.
2. Tap **Copy ID** to paste the ID anywhere, or **Share as PNG** to print or post the QR code.
3. To choose an ID people can remember, tap **Change workspace ID**, type 4 to 20 letters or digits and tap **Save**.

**Good to know**

- The ID is unique across DesKilo. If it is taken, or not 4 to 20 letters or digits, the app says **That ID was rejected**.
- Anyone who scans the code or types the ID asks to join as a member. Nobody gets in without approval.
- Once you change the ID, the old one stops working. Print the QR code again.
- The **Administrator invite** tab is for owners and co-owners.

**See also:** [Administrator invite](help:user.workspace.code.admin) · [Invite someone](help:user.workspace.code.invite)

<!-- anchor: user.workspace.code.admin -->
### Invite an administrator

**Audience:** Owner

You want to bring in a person who will help run the space. The **Administrator invite** tab gives you a code for exactly one person.

<p><img src="images/user-workspace-code-admin.en.jpg" width="280"></p>

**Steps**

1. Open [Workspace ID & QR](app:/workspace-code) and tap **Administrator invite**.
2. Give the code, or its QR, to the person it is meant for.
3. For the next administrator, tap **New administrator code**.

**Good to know**

- The code admits one person as an administrator, then it expires.
- There is no owner invite. Only an owner can grant ownership, in **Members & plans**.

**See also:** [The workspace ID](help:user.workspace.code) · [The role matrix](help:user.roles.matrix)

<!-- anchor: user.workspace.code.invite -->
### Invite someone by message

**Audience:** Owner · Administrator

You want to send a friendly, ready-made invitation instead of a bare code.

<p><img src="images/user-workspace-code-invite.en.jpg" width="280"></p>

**Steps**

1. On [Workspace ID & QR](app:/workspace-code), tap **Invite someone**.
2. Fill in **First name (optional)**, **Last name (optional)** and the phone number if you want.
3. Under **Roles on arrival**, tap any role this person should receive when they join.
4. Pick the **Message language**.
5. Send it with **WhatsApp**, **SMS** or **Share…**.

**Good to know**

- The message explains the steps: download, create an account, join. It is written in the language you pick, and starts from the one set as [Workspace language](help:user.workspace.settings.language).
- Each message carries its own personal code. You can write your own text under [Invitation message](help:user.workspace.settings.invitation-message).

**See also:** [The workspace ID](help:user.workspace.code)

<!-- anchor: user.workspace.availability.open-weekdays -->
### Open weekdays

**Audience:** Owner · Administrator with the permission

You want the space to be open only on the days you work. The **Availability** screen starts with the days of the week.

<p><img src="images/user-workspace-availability--open-weekdays.en.jpg" width="280"></p>

**Steps**

1. Open [Availability](app:/availability).
2. Under **Open weekdays**, tap a day to open or close it.

**Good to know**

- At least one weekday must stay open.
- A booking that touches a closed weekday is refused, and the plan draws that day as closed.

**See also:** [Closure days](help:user.workspace.availability.closure-days) · [Granularity](help:user.workspace.availability.granularity)

<!-- anchor: user.workspace.availability.granularity -->
### Granularity

**Audience:** Owner · Administrator with the permission

You want bookings to follow a rhythm that suits your space: half days, full days, or any time you like.

<p><img src="images/user-workspace-availability--granularity.en.jpg" width="280"></p>

**Steps**

1. Open [Availability](app:/availability).
2. Under **Booking granularity**, choose the shape of a booking.

**Good to know**

- The choices are **Free time period**, **5-minute slots**, **15-minute slots**, **30-minute slots**, **1-hour slots**, **Half days (morning & afternoon)**, **Full days only** and **Real hours (exact from–to, half/full days as shortcuts)**. **Real hours** appears when the **Working hours** feature is on.
- The plan, the booking sheet, a scanned code and the kiosk all offer only what the granularity allows.

**See also:** [Working hours](help:user.workspace.availability.working-hours)

<!-- anchor: user.workspace.availability.working-hours -->
### Working hours

**Audience:** Owner · Administrator with the permission

You want a morning, an afternoon and a day to mean the same thing everywhere.

<p><img src="images/user-workspace-availability--working-hours.en.jpg" width="280"></p>

**Steps**

1. Open [Availability](app:/availability).
2. Under **Working hours**, tap **Day starts**, **Half-day boundary** and **Day ends** and set each time.
3. With **Real hours** granularity, also set **Hours billed as a half day** and **Hours billed as a full day**.

**Good to know**

- Half-day and full-day windows in reservations, check-in and invoicing follow these hours.
- The small tag under the title says whether the hours are the product default, come from a template or are your own. **Reset to template** and **Reset to product default** take them back.
- The day must run in order: start, then the half-day boundary, then the end.
- This section is part of the **Working hours** feature.

**See also:** [Outside the opening hours](help:user.workspace.availability.outside-hours)

<!-- anchor: user.workspace.availability.closure-days -->
### Closure days

**Audience:** Owner · Administrator with the permission

You want a holiday, a week in August or a day for the plumber to close the space without anyone booking it.

<p><img src="images/user-workspace-availability--closure-days.en.jpg" width="280"></p>

**Steps**

1. Open [Availability](app:/availability) and go to **Closure days**.
2. Tap **Add closure day**, pick the date and, if you like, a **Reason (optional)**.
3. To remove one, tap the bin beside it.

**Good to know**

- A booking on a closure day is refused and the reason is shown.
- Days that are already invoiced cannot be turned into closure days by the public holidays generator.

**See also:** [Public holidays](help:user.workspace.availability.public-holidays)

<!-- anchor: user.workspace.availability.public-holidays -->
### Public holidays

**Audience:** Owner · Administrator with the permission

You want a whole year of public holidays as closure days in one go.

**Steps**

1. In [Availability](app:/availability), under **Closure days**, tap **Add public holidays**.
2. Use the arrows to choose the year. The sheet lists the dates that would become closure days.
3. Tap the button at the bottom to create them.
4. Prefer an open-data list? Tap **Import public holidays (open data)**, pick the region and confirm.

**Good to know**

- Nothing is created before you confirm, and days that already exist are marked.
- Months that are already invoiced are skipped.
- These entries appear when the **Public holidays** feature is on. **Import public holidays (open data)** also needs the **Import public holidays** feature.

**See also:** [Closure days](help:user.workspace.availability.closure-days)

<!-- anchor: user.workspace.availability.policies -->
### Booking policies

**Audience:** Owner · Administrator with the permission

You want to relax or tighten the rules of booking. Whatever you set here holds on every way of booking: the app, a scanned code and the kiosk.

<p><img src="images/user-workspace-availability--policies.en.jpg" width="280"></p>

**Steps**

1. Open [Availability](app:/availability) and go to **Booking policies**.
2. Switch the policies you want on or off.
3. Under **Outside the opening hours** and **Booking limits**, set the rest.

**Good to know**

- The two switches are off by default.
- This section is part of the **Booking policies** feature.
- The line **What the plan tells apart** below it explains the states members see on the plan.

**See also:** [Allow past bookings](help:user.workspace.availability.allow-past) · [Admins may check members out](help:user.workspace.availability.admin-checkout) · [Booking limits](help:user.workspace.availability.limits)

<!-- anchor: user.workspace.availability.allow-past -->
### Allow past bookings

**Audience:** Owner · Administrator with the permission

You want members to record a booking after the fact, for a space that notes attendance later.

**Steps**

1. In [Availability](app:/availability), under **Booking policies**, switch on **Allow past bookings**.

**Good to know**

- Off, a booking that already ended on an earlier day is refused.
- Booking an earlier window on the same day is always allowed.

**See also:** [Booking policies](help:user.workspace.availability.policies)

<!-- anchor: user.workspace.availability.admin-checkout -->
### Administrators may check out

**Audience:** Owner · Administrator with the permission

You want staff to close the room in the evening and end the check-ins people forgot.

**Steps**

1. In [Availability](app:/availability), under **Booking policies**, switch on **Admins may check members out**.

**Good to know**

- Off, check-out is strictly personal.
- With it on, an administrator can end a member's running check-in.

**See also:** [Booking policies](help:user.workspace.availability.policies)

<!-- anchor: user.workspace.availability.outside-hours -->
### Outside the opening hours

**Audience:** Owner · Administrator with the permission

You want to say what happens when somebody arrives early or stays late. One answer applies to every granularity.

<p><img src="images/user-workspace-availability--outside-hours.en.jpg" width="280"></p>

**Steps**

1. In [Availability](app:/availability), find **Outside the opening hours**.
2. Choose **Off**, **Spontaneous only**, **Free** or **Charged**.

**Good to know**

- **Off**: nothing outside the hours, no booking ahead, no walk-up.
- **Spontaneous only**: walk-up check-ins stay possible, evening overtime included, but booking ahead outside the hours is refused.
- **Free**: allowed, never counted and never charged.
- **Charged**: allowed and counted like ordinary usage, except on a day when the member already holds a regular booking.
- A booking that touches the working hours is an ordinary booking.

**See also:** [Working hours](help:user.workspace.availability.working-hours)

<!-- anchor: user.workspace.availability.limits -->
### Booking limits

**Audience:** Owner · Administrator with the permission

You want to say how far ahead people may book, how short or long a booking may be, and how many they may hold at once.

<p><img src="images/user-workspace-availability--limits.en.jpg" width="280"></p>

**Steps**

1. In [Availability](app:/availability), find **Simultaneous reservations per member** and use the minus and plus buttons.
2. Under **Booking limits**, set **Advance booking horizon**, **Minimum duration** and **Maximum duration**.

**Good to know**

- **Simultaneous reservations per member** is how many overlapping bookings one member may hold. 1 keeps one place at a time.
- A booking ends on the day it starts, so a full day is the longest it can be.
- The minimum cannot exceed the maximum, otherwise no booking would be accepted. The screen warns you.
- Every refusal names the limit and its value.

**See also:** [Booking policies](help:user.workspace.availability.policies)

<!-- anchor: user.features.processes -->
### Switch whole processes on or off

**Audience:** Owner · Co-owner

You want a bird's-eye view of what the space can do, and to switch a whole area on at once. The **Features** screen opens on one card per business process.

<p><img src="images/user-features-processes.en.jpg" width="280"></p>

**Steps**

1. Open [Features](app:/features). The **Processes** view is shown.
2. Read each card: its state, how many subprocesses are active and how many features are on.
3. Open a card and tap **Switch on** or **Switch off** for the whole process or one subprocess.
4. Read the preview, then confirm.

**Good to know**

- A card is **Active** when all its features work, **Partial** when some do, **Available** when none is on yet, and **Needs attention** when a feature is on but waits for a prerequisite that is off.
- The chips **All**, **Active**, **Available** and **Needs attention** narrow the cards, and **Search processes and features** reaches everything.
- The preview lists what is switched on, what is **Also needed** from another process and what is already on. Switching something off that other features need is refused until you choose what happens to them.

**See also:** [A feature switch](help:user.features.switch)

<!-- anchor: user.features.switch -->
### A feature switch

**Audience:** Owner · Co-owner

You want to turn one single feature on or off.

<p><img src="images/user-features-switches.en.jpg" width="280"></p>

**Steps**

1. Open [Features](app:/features) and tap **Switches**.
2. Find the feature with **Search features**, or narrow the list with **Changed** or **Maturity**.
3. Flip its switch.

**Good to know**

- Switch a feature on and every part of it appears: the tab, the button, the link. Switch it off and none remains, even a saved link.
- A feature that needs another sits under it with **Requires…** and says **Waiting on the feature above** while the parent is off. Its own choice is kept.
- Switching a feature on can also switch on what it needs. The app tells you.
- A feature not yet reviewed as stable asks you to confirm first: it may change and has known limits.
- Something already done stays done. An invoice issued while a feature was on keeps what it says.

**See also:** [Switch whole processes on or off](help:user.features.processes)

<!-- anchor: user.workspace.settings.country -->
### Country

**Audience:** Owner · Administrator with the permission

You want the space to know where it is established. **Workspace** opens on **General details**.

<p><img src="images/user-workspace-settings--country.en.jpg" width="280"></p>

**Steps**

1. Open [Workspace](app:/workspace-settings).
2. Under **General details**, pick the **Country**.
3. Tap **Save** at the bottom.

**Good to know**

- The country proposes the currency and the time zone, and decides which VAT rates are offered.
- Once the space has issued a document or recorded money, the country can no longer be changed: saving says "The currency and the country are fixed once this space has issued a document or recorded money. Nothing was saved."
- **Save** writes the whole form together. If someone changed these settings meanwhile, nothing is saved and what you typed stays on screen.

**See also:** [Currency and time zone](help:user.workspace.settings.currency-timezone)

<!-- anchor: user.workspace.settings.currency-timezone -->
### Currency and time zone

**Audience:** Owner · Administrator with the permission

You want prices and days to be counted the way your space counts them.

<p><img src="images/user-workspace-settings--currency-timezone.en.jpg" width="280"></p>

**Steps**

1. In [Workspace](app:/workspace-settings), under **General details**, pick the **Currency**.
2. Search for the **Time zone** and choose it.
3. Tap **Save**.

**Good to know**

- The currency is proposed from the country. You can override it until the space has issued a document or recorded money; after that it is fixed.
- The time zone is not cosmetic: a working day, a half-day boundary and a closure day are all counted in it, so a member abroad sees the space's day rather than their own.

**See also:** [Country](help:user.workspace.settings.country)

<!-- anchor: user.workspace.settings.language -->
### Workspace language

**Audience:** Owner · Administrator with the permission

You want invitations and documents to speak the language of your community.

<p><img src="images/user-workspace-settings--language.en.jpg" width="280"></p>

**Steps**

1. In [Workspace](app:/workspace-settings), under **General details**, open **Workspace language**.
2. Pick a language, or **Sender's app language**.
3. Tap **Save**.

**Good to know**

- Invitations are written in this language by default.
- It is not your own app language. That one only changes what you see, and lives in your personal settings.

**See also:** [Invitation message](help:user.workspace.settings.invitation-message)

<!-- anchor: user.workspace.settings.address -->
### Letterhead address

**Audience:** Owner · Administrator with the permission

You want your postal address on the paper the space sends out.

<p><img src="images/user-workspace-settings--address.en.jpg" width="280"></p>

**Steps**

1. In [Workspace](app:/workspace-settings), under **General details**, fill in **Workspace address**.
2. Tap **Save**.

**Good to know**

- It is free text, printed as it is on letters and invoices.
- The structured address that an e-invoice needs is a separate entry, under the legal identity.

**See also:** [Country](help:user.workspace.settings.country)

<!-- anchor: user.workspace.settings.whatsapp-group -->
### WhatsApp group

**Audience:** Owner · Administrator with the permission

You want members to find your community's WhatsApp group.

<p><img src="images/user-workspace-settings-community--whatsapp-group.en.jpg" width="280"></p>

**Steps**

1. In [Workspace](app:/workspace-settings), open **Community & invitations**.
2. Paste the group's invite link into **WhatsApp group link**.
3. Tap **Save**.

**Good to know**

- The link must be a chat.whatsapp.com invite link, otherwise the field says so.
- Leave it empty to show nothing.

**See also:** [Invitation message](help:user.workspace.settings.invitation-message)

<!-- anchor: user.workspace.settings.invitation-message -->
### Invitation message

**Audience:** Owner · Administrator with the permission

You want invitations to sound like you, in every language you use.

<p><img src="images/user-workspace-settings-community--invitation-message.en.jpg" width="280"></p>

**Steps**

1. In [Workspace](app:/workspace-settings), open **Community & invitations**.
2. Under **Message language**, choose which language's text you are editing.
3. Write the text. Tap a tag such as {firstName} or {inviteLink} to insert it where the cursor is.
4. Tap **Save**.

**Good to know**

- Leave the box empty to use the built-in message in that language.
- The **Message language** row only says which draft is on screen. It is not saved, and it opens on the workspace language each time.
- The tags are filled in when you send an invitation. The code and the link come from the app, so do not paste them yourself.

**See also:** [Invite someone by message](help:user.workspace.code.invite)

<!-- anchor: user.workspace.settings.new-members -->
### Start new members the same way

**Audience:** Owner · Administrator with the permission

You want everyone who joins to begin with the same subscription and the same rule for when their days run out.

<p><img src="images/user-workspace-settings-members--defaults.en.jpg" width="280"></p>

**Steps**

1. In [Workspace](app:/workspace-settings), open **New members**.
2. Set the **Subscription** percentage with the minus and plus buttons.
3. Choose **Blocked once used up**, **Pay as you go** or **Must buy a package**.
4. Tap **Save**.

**Good to know**

- Until you choose, new members start at 100% with bookings blocked once the entitlement is used.
- A member's own subscription is set later, on the member's page.

**See also:** [A member's subscription](help:user.members.subscription)

<!-- anchor: user.workspace.settings.wording -->
### Wording

**Audience:** Owner · Administrator with the permission

You want the app to use your words: another name for a seat, for a status on the plan, for a tab.

<p><img src="images/user-workspace-settings-wording.en.jpg" width="280"></p>

**Steps**

1. In [Workspace](app:/workspace-settings), open **Appearance & wording** and tap **Wording**.
2. Find a word with **Search a word**, or tap **Changed only** to see what you renamed.
3. Tap the pencil beside it and type your word, per language.

**Good to know**

- The product's word stays shown beneath yours, so you see what you replace.
- **Reset** removes your word instead of copying the product's. The term then follows the product when its wording changes.
- Terms are grouped by where they appear: **Legend**, **The space**, **Navigation**, **Booking**.

**See also:** [Colours](help:user.workspace.settings.colours)

<!-- anchor: user.workspace.settings.colours -->
### Colours

**Audience:** Owner · Administrator with the permission

You want the app to wear your colour. Pick one and the app derives its light and dark themes from it.

<p><img src="images/user-workspace-settings-colours--colours.en.jpg" width="280"></p>

**Steps**

1. In [Workspace](app:/workspace-settings), open **Appearance & wording** and tap **Colours**. The row is there while **Workspace colours** is on in the features.
2. Tap one of the colours, or type a code such as #0F766E into **Colour**.
3. Check **What it looks like**, in **Light** and **Dark**.
4. Tap **Save**. **Product colours** removes yours.

**Good to know**

- The app keeps its own contrast. If a colour would be unreadable somewhere, it is refused and the screen names the pair.
- Under **Room colours** you can add up to eight colours of your own for the rooms on the plan.
- The DesKilo mark, the colours of the seat states and the production banner are never restyled.

**See also:** [Pattern](help:user.workspace.settings.pattern) · [Symbol and emblem](help:user.workspace.settings.branding)

<!-- anchor: user.workspace.settings.pattern -->
### Pattern

**Audience:** Owner · Administrator with the permission

You want your space easy to tell apart from the others a person belongs to.

<p><img src="images/user-workspace-settings-colours--pattern.en.jpg" width="280"></p>

**Steps**

1. Open [Colours](app:/settings/colours).
2. Under **Pattern**, tap **Plain**, **Stripes**, **Dots**, **Grid** or **Waves**.

**Good to know**

- The pattern draws your colour on this space's card in Me, on its chip and while the space opens.
- It saves as soon as you tap it.

**See also:** [Colours](help:user.workspace.settings.colours)

<!-- anchor: user.workspace.settings.branding -->
### Symbol and emblem

**Audience:** Owner · Administrator with the permission

You want a small mark that stands for the space: letters on a colour, or your own logo.

<p><img src="images/user-workspace-settings-colours--branding.en.jpg" width="280"></p>

**Steps**

1. Open [Colours](app:/settings/colours) and go to **Symbol**.
2. Type one or two **Letters**, pick a colour and tap **Save**.
3. Under **Emblem**, tap **Choose an image** to add your logo. **Remove** takes it away.

**Good to know**

- Letters on a colour are unique to a workspace. If another space already has the same, the app asks you to change the colour or the letters.
- The emblem is shown beneath the app's name in the menu, and while someone opens this space. It is redrawn at most 512 pixels wide, and the photo's own details, such as where it was taken, are not kept.
- The emblem never replaces the DesKilo logo.

**See also:** [Colours](help:user.workspace.settings.colours)

<!-- anchor: user.workspace.settings.desk-transparency -->
### Desk transparency

**Audience:** Owner · Administrator with the permission

You drew the plan over a photograph and want the room to show through the furniture.

<p><img src="images/user-workspace-settings-appearance--desk-transparency.en.jpg" width="280"></p>

**Steps**

1. In [Workspace](app:/workspace-settings), open **Appearance & wording**.
2. Drag the **Desk transparency** slider. The value shows as **Opacity**.
3. Tap **Save**.

**Good to know**

- Lower the opacity so a level's background photo shows through the tables.
- Turn it up to 100% when the places matter more than the room.

**See also:** [Draw rooms, desks and seats](help:user.space.editor.rooms)

<!-- anchor: user.workspace.settings.public-page -->
### Public workspace page

**Audience:** Owner

You want people outside your space to find it and see what it offers.

<p><img src="images/user-workspace-settings-public-page.en.jpg" width="280"></p>

**Steps**

1. Open [Public workspace page](app:/settings/public-page), or tap it at the top of **Workspace**.
2. Switch on **Visible in the public directory**.
3. Choose the kind of host, and complete **Description**, **Public address**, **Public email**, **Public phone** and **Website**.
4. Tap **Save and preview the external view**.

**Good to know**

- Fields marked **From workspace information** follow the workspace's own details. **Use workspace information** puts them back after you changed them.
- **Reset all public data to workspace information** replaces every field that has a workspace counterpart.
- Administrators can choose for themselves whether they are shown as public administrators.

**See also:** [Discover and the public network](help:user.collaborate.discover)

<!-- anchor: user.roles.matrix -->
### The role matrix

**Audience:** Owner · Co-owner

You want to decide which permissions each role holds. **Roles** shows one card per role with a tick for every permission it holds.

<p><img src="images/user-roles-matrix.en.jpg" width="280"></p>

**Steps**

1. Open [Roles](app:/roles).
2. On the card of a role, tick or untick a permission such as **Manage roles & permissions**, **Manage members**, **Edit workspace settings** or **Issue invoices & match payments**.

**Good to know**

- Everyone has exactly one base role: User, Administrator, Co-owner or Owner. Other roles add to it and never take anything away.
- The owner always holds every permission, so that card is locked. A co-owner may hold less.
- Anyone who may not manage roles sees the matrix read-only, with **Your role** highlighted.
- A permission is checked by the server in every place, so unticking it removes it everywhere at once.
- The **Roles** entry shows when the **Role management** feature is on.

**See also:** [Roles this space defines](help:user.roles.space) · [Co-owners](help:user.roles.co-owners)

<!-- anchor: user.roles.space -->
### Roles this space defines

**Audience:** Owner · Co-owner

You want roles that fit your space, such as a host or an accountant, on top of the basic ones.

<p><img src="images/user-roles-space.en.jpg" width="280"></p>

**Steps**

1. In [Roles](app:/roles), tap **The roles this space defines**, or open [Roles this space defines](app:/settings/roles-of-this-space). This screen appears when the **Roles this space defines** feature is on.
2. Tap **Add a role**.
3. Give the role a name, then choose **What it adds**.
4. Tap **Save the role**.
5. To give it to a member, open the member's page, find **Roles** and tap **Add a role**.

**Good to know**

- Each role adds permissions to what its holders can already do. None takes anything away, and the owner always keeps every permission.
- A role you no longer want can be put aside with **In use** switched off.
- The role's key never changes: the people who hold it point at it.
- Nobody can give a role to themselves. A role that manages roles can only be given by the owner.

**See also:** [The role matrix](help:user.roles.matrix)

<!-- anchor: user.roles.co-owners -->
### Co-owners

**Audience:** Owner

You want the space to survive if you ever step away.

**Steps**

1. Open [Members & plans](app:/members) and choose the member.
2. Under **Co-ownership**, choose an active co-owner or a successor.
3. To hand over now, choose **Promote to owner now**.

**Good to know**

- An active co-owner has the owner's permissions now. A successor, shown as **Successor**, waits and becomes owner when activated or when the owner leaves.
- If the last owner leaves, the best co-owner becomes owner automatically, active before successor.
- Co-owners are part of the **Co-owners** feature.

**See also:** [Co-ownership](help:user.members.co-ownership) · [The role matrix](help:user.roles.matrix)

<!-- anchor: user.kiosk.mode -->
### Kiosk mode: A wall tablet for check-in

**Audience:** Owner · Administrator

You want a tablet by the door where people check in with a badge.

**Steps**

1. Create an account for the tablet, join the workspace with it and, in [Members & plans](app:/members), use **Make kiosk device** on that member.
2. Make sure **Kiosk mode** is on in [Features](app:/features).
3. On the tablet, open the app. It asks **Start kiosk mode?**. Tap **Start kiosk mode**.
4. A member taps a seat, or **This level**, and presents a badge: a card, or a printed QR code.

**Good to know**

- Kiosk mode never starts by itself. **Not now — open the app normally** opens the app as usual, which is handy for setup.
- In kiosk mode the tablet only shows the plan. To leave it you restart the tablet. To make the account a normal member again, use **Kiosk device** under **Settings** on the device or **Revert kiosk to member** in **Members & plans**.
- The sheet that opens names the rule it follows. On a closed day the kiosk says **The workspace is closed today** up front.
- The badge is the confirmation: it identifies the member, carries out the action and the screen clears for the next person. A seat held by someone else shows who holds it and points you to the app.
- Badges come with their own features, **RFID / NFC badges** and QR badges, both under **Kiosk mode**.
- A wall tablet cannot be shown here: the kiosk only starts on a device marked as one.

**See also:** [NFC badge check-in](help:user.badges.nfc) · [Space QR codes (PDF)](help:user.workspace.export.space-qr)

<!-- anchor: user.badges.nfc -->
### NFC badge check-in

**Audience:** Owner · Administrator

You want members to check in by tapping a card, with no phone.

<p><img src="images/user-badges-nfc.en.jpg" width="280"></p>

**Steps**

1. Open [RFID / NFC badges](app:/nfc-config).
2. Switch on **Enable NFC badge check-in**.
3. Read the **This device** line: it says whether this device can read cards.
4. Give each member a card in [Members & plans](app:/members): open the member's badges, tap **Register card**, then hold the card to the back of the device.

**Good to know**

- You need an Android device with NFC. iPads have no NFC, and QR badges still work there.
- The badge manager also lets you issue a **New badge**, **Revoke** one, and **Save as PDF** for printing. A revoked badge can be deleted for good.
- **Signs me in** is off by default: a badge that checks you in does not log you in until the member chooses to.
- Each member can also make their own badge in their personal settings.

**See also:** [A wall tablet for check-in](help:user.kiosk.mode)

<!-- anchor: user.documents.add -->
### Add a document to the library

**Audience:** Owner · Administrator

You want to gather your statutes, guides, statements and minutes in one place for the members who need them. The library holds links, not files.

<p><img src="images/user-documents-add.en.jpg" width="280"></p>

**Steps**

1. Open [Documents](app:/documents) and tap the plus button.
2. Fill in **Title** and **Link (https://…)**.
3. Choose **Stored on**, **Category** and **Visible to**.
4. Tap **Save**.

**Good to know**

- The library needs the **Document library** feature, and the permission to manage it.
- Remove a document with its bin: it asks **Remove document?** first.
- Members who may open the library see the documents they are allowed to, grouped by category.

**See also:** [Document title](help:user.documents.title) · [Link](help:user.documents.url) · [Visible to](help:user.documents.role)

<!-- anchor: user.documents.title -->
### Document title

**Audience:** Owner · Administrator

You want members to recognise a document at a glance.

**Steps**

1. In the add-a-document form, type the **Title**.

**Good to know**

- A document needs a title and an https:// link, or **Save** is refused.
- Write it for the reader, as it is the line they see in the library.

**See also:** [Add a document to the library](help:user.documents.add)

<!-- anchor: user.documents.url -->
### Link

**Audience:** Owner · Administrator

You want the document to open where it already lives.

**Steps**

1. Paste the share link from your drive into **Link (https://…)**.

**Good to know**

- DesKilo stores the link, not the file. Access rights stay managed where the document is.
- The link must begin with https://.

**See also:** [Stored on](help:user.documents.provider)

<!-- anchor: user.documents.provider -->
### Stored on

**Audience:** Owner · Administrator

You want members to see where the document is kept.

**Steps**

1. Choose **Stored on**: Google Drive, OneDrive, SharePoint, Dropbox, Nextcloud or **Link**.

**Good to know**

- It is a label with an icon. Nothing is fetched for you.

**See also:** [Link](help:user.documents.url)

<!-- anchor: user.documents.category -->
### Category

**Audience:** Owner · Administrator

You want the library to read like a tidy shelf.

**Steps**

1. Choose a **Category**: **Statutes & legal**, **Guides & manuals**, **Financial statements**, **Meeting minutes** or **Other documents**.

**Good to know**

- The library groups documents under these headings, and only shows a heading that has a document.

**See also:** [Visible to](help:user.documents.role)

<!-- anchor: user.documents.role -->
### Visible to

**Audience:** Owner · Administrator

You want some documents for everyone and some for the board only.

**Steps**

1. Choose **Visible to**: **Every member**, **Admins and owners** or **Owners only**.

**Good to know**

- The server enforces it. A member who may not see a document does not receive it at all.

**See also:** [Add a document to the library](help:user.documents.add)

<!-- anchor: user.workspace.export.space-xml -->
### Export the space (XML)

**Audience:** Owner · Administrator with the permission

You want a file with the floor plan and settings, to keep as a backup, to reuse or to move to another space.

<p><img src="images/user-workspace-settings-tools--tools.en.jpg" width="280"></p>

**Steps**

1. Open [Workspace](app:/workspace-settings) and go to **Templates & data**.
2. Tap **Export workspace (XML)**.

**Good to know**

- It carries settings and the floor plan. It never holds members, bookings or money data, nor the invite code or payment credentials.
- With **Configuration in the space file** on, the file also carries tariffs, VAT rates, rules, roles and more.
- The file is saved on your device.

**See also:** [Import the space (XML)](help:user.workspace.export.space-import)

<!-- anchor: user.workspace.export.space-import -->
### Import the space (XML)

**Audience:** Owner · Administrator with the permission

You want to apply an exported file to a space.

**Steps**

1. In [Workspace](app:/workspace-settings), under **Templates & data**, tap **Import workspace (XML)**.
2. Choose the file and read the preview: levels, offices, desks, seats and configuration.
3. Tap **Replace and import**.

**Good to know**

- It replaces the current floor plan and overwrites the settings. This cannot be undone.
- Once a space has bookings, only the configuration is applied. The floor plan is kept, and the app says so.
- A file that is not readable, or not from DesKilo, is refused with a clear message.
- When the file carries a configuration and **Configuration in the space file** is off in this space, the app asks first: **Switch it on and apply** applies it, **Import without the configuration** imports the rest, and the preview then reads “Configuration: not applied.” Only somebody who may change the configuration is offered to switch it on.

**See also:** [Export the space (XML)](help:user.workspace.export.space-xml)

<!-- anchor: user.workspace.export.config-pdf -->
### Export the configuration (PDF)

**Audience:** Owner · Administrator with the permission

You want a document of every parameter, to read, sign or give to an accountant.

<p><img src="images/user-workspace-export-reports.en.jpg" width="280"></p>

**Steps**

1. Open [Reports](app:/reports?section=documents) and choose **Workspace documents**.
2. Tap **Export configuration (PDF)**.

**Good to know**

- It is a complete snapshot of settings, members and the floor plan. It is a record, not a backup: only the XML can be imported back.

**See also:** [Export the space (XML)](help:user.workspace.export.space-xml)

<!-- anchor: user.workspace.export.workspace-report -->
### Workspace report

**Audience:** Owner · Administrator with the permission

You want the space as a document: its places, prices and rules.

**Steps**

1. Open [Reports](app:/reports?section=documents) and choose **Workspace documents**.
2. Tap **Workspace report**.

**Good to know**

- It is made by the report editor's workspace template, so its look follows the design you chose.

**See also:** [Export the configuration (PDF)](help:user.workspace.export.config-pdf)

<!-- anchor: user.workspace.export.space-qr -->
### Space QR codes (PDF)

**Audience:** Owner · Administrator with the permission

You want a QR card on every seat, desk, office and floor, so people book or check in by scanning it.

**Steps**

1. Open [Reports](app:/reports?section=documents) and choose **Workspace documents**.
2. Tap **Space QR codes (PDF)**.
3. Choose **Card size**, **QR code size** and the **Information on the card**, then tap **Save**.
4. Print, cut and stick each card on its place.

**Good to know**

- It needs the **Space QR codes** feature.
- Scanning a card opens the same sheet the kiosk shows.

**See also:** [A wall tablet for check-in](help:user.kiosk.mode)

<!-- anchor: user.workspace.export.excel -->
### Export the data (Excel)

**Audience:** Owner · Administrator with the permission

You want your figures in a spreadsheet for your own analysis.

**Steps**

1. Open [Reports](app:/reports?section=documents) and choose **Workspace documents**.
2. Tap **Export data (Excel)**.

**Good to know**

- It arrives as one ZIP: a workbook with a tab for bookings, payments, invoices, members and the floor plan, a manifest that counts the rows, and the space's stored files.
- It needs the **Data export (Excel)** feature and the permission to export data. It is an export only: nothing reads it back.

**See also:** [Export the space (XML)](help:user.workspace.export.space-xml)

<!-- anchor: user.workspace.sites -->
### Sites

**Audience:** Owner · Administrator

You run more than one address, and want each level and member to belong to the right one.

**Steps**

1. Switch on **Sites** in [Features](app:/features).
2. Open [Sites](app:/settings/sites) and tap **Add a site**.
3. Fill in **Site name**, **Street**, **Post code**, **City** and the levels that belong to it.

**Good to know**

- The default site carries the workspace's address. A member's home site is the address on their documents.
- **Delete this site** sends its levels and members back to the default site.
- A site that is its own legal entity can carry its own registration and VAT number.
