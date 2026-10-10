<!-- anchor: setup.notify.overview -->
## Tell people

For owners who want members and administrators to hear about what matters, and only that. This chapter describes what DesKilo really sends, who receives it, what you configure and what you leave to the operator of the installation.

In this chapter:
- The channels, in plain words
- A table: what happens, who is told, by which channel, what a member can change
- What you configure, and what the operator must do for push
- A test plan with two accounts
- How to avoid both overload and silence

<!-- anchor: setup.notify.channels -->
### The channels, in plain words

**Audience:** Owner · Administrator

You want a clear picture of the ways DesKilo can reach a person, before you promise anything to your members.

<p><img src="images/setup-notify-features.en.jpg" width="280"></p>

**Before you start**

There are six ways, and they are not equal. Most of the work is done inside the app.

| Channel | What it is | What it needs |
|---|---|---|
| The events feed and the bell | Everything that happens in the space is written to a feed. The bell counts new updates and the decisions waiting for you. | **Events tab**; **Notification feed grouping** is an option on top |
| Messages | Private and group conversations between members, with read receipts and links to a booking or a space. | **Member notifications** |
| Push | A short notification on a phone or computer, even when the app is closed. The text is generic: no names, no times. | **Push notifications** on, **and** a push set-up by the operator; see [the operator's part](help:setup.notify.operator) |
| The check-in reminder | A notification on the member's own device, 15 minutes before a booking they have not yet checked in to. | The member's system permission. Not in the browser version. |
| Payment reminders | An alert in the feed and a push to the member whose invoice is overdue. | **Payment reminders** and **Automatic payment reminders**; see [Payment reminders](help:setup.money.reminders) |
| WhatsApp | A group link you publish, and the WhatsApp number a member chooses to share. The app opens WhatsApp; nothing is sent from the server. | **WhatsApp integration** |

**Good to know**

- DesKilo sends no e-mail of its own beyond the account e-mails (sign-up confirmation, password reset). Invitations are texts you share from your own phone.
- There is no per-event subscription: a member cannot pick "tell me about expenses but not about bookings".
- A notification may be delayed or lost like any push; the feed and the message list are the record.

**See also:** [Notifications](help:user.collaborate.notifications) · [Events & confirmations](help:user.collaborate.events)

<!-- anchor: setup.notify.table -->
### Who is told what

**Audience:** Owner · Administrator

You want to know, event by event, who hears about it and how.

<p><img src="images/setup-notify-events.en.jpg" width="280"></p>

**Before you start**

Push is sent only for the five lines marked "push" below. Every other event (a booking made, a payment recorded, a member joining) appears in the feed and nowhere else.

| Source | Event | Who is told | Channel | What the member can change |
|---|---|---|---|---|
| Validation rules | A request needs a confirmation | The people the rule names (feed, **Waiting for your confirmation**); the push goes only to the member the request is about, never to the person who made it, so validators are pushed only when they are that member. Text: "Someone needs your confirmation." | Feed, bell; push | Switch push off on the device |
| Reservations | An administrator removes or overrules a booking | The member displaced, and every active administrator and owner except the one who acted. Text: "A reservation was removed by an admin." | Feed; push | Switch push off on the device |
| Payment reminders | An invoice is past its term and a reminder level falls due | The member the invoice is for. An owner's own invoice reaches the owner. Text: "A payment reminder is waiting for you." | Feed alert; push | Switch push off on the device |
| Member notifications | A new message | Direct message: the recipient. Group: the participants except the sender. A conversation muted by a member stays silent for that member. Text: "You have a new message." | Messages, bell; push | Mute, pin or archive a conversation; switch push off |
| Message mentions | A group message names someone | The people named, even in a muted conversation. Text: "You were mentioned in a conversation." | Messages; push | Switch push off |
| Reservations | A booking is ahead | The member who booked, on their own device, 15 minutes before it starts, for bookings in the next seven days | Local notification | Refuse the system permission |
| WhatsApp integration | Nothing is sent | The group link is shown in the directory; a member may share their number | Opens WhatsApp | Share or hide the number |

**Good to know**

- When the app is open, a removed-booking push is replaced by a notification in the member's language. For messages, mentions, confirmations and payment reminders the open app currently shows its generic text ("Someone needs your confirmation."). The generic English texts of the table appear when the app is in the background or closed.
- An administrator is told only about what they act on or what a rule gives them; there is no "everything" digest.
- Members see their own events; administrators and owners see everyone's.

**See also:** [Validation rules](help:user.validation.overview) · [Messages](help:user.collaborate.messages)

<!-- anchor: setup.notify.configure -->
### What you configure

**Audience:** Owner

You decide which of these channels exist in your space and who is asked to decide what.

<p><img src="images/setup-notify-validation.en.jpg" width="280"></p>

**Steps**

1. Open [Features](help:user.features.switch) and check the notification switches: **Push notifications**, **Member notifications**, **Events tab**, **Notification feed grouping**, **Payment reminders**, **Automatic payment reminders** and **WhatsApp integration**.
2. Set the [validation rules](help:user.validation.overview): for each kind of request, how many validations are required and who may give them. This decides who is asked, and so who sees a decision waiting.
3. Decide whether an administrator's or an owner's own request settles itself; see [Auto-validate an administrator's own request](help:user.validation.auto-validate-admin) and [Auto-validate an owner's own request](help:user.validation.auto-validate-owner). A request that is settled already never pings anyone.
4. Write the invitation message members receive, and paste the community group link; see [Invitation message](help:user.workspace.settings.invitation-message) and [WhatsApp group](help:user.workspace.settings.whatsapp-group).
5. Switch on **Booking deletion requests** if members may ask to delete a past or checked-in booking: someone then has to answer.

**Good to know**

- Defaults for a new space: the events tab, member notifications and grouping are on; **Payment reminders** and **Automatic payment reminders** are on as features, but no reminder is sent until you switch **Automatic reminders** on in the reminder rules.
- **Push notifications** is on by default, but it delivers nothing until the operator has set it up.
- Switching a feature off stops new activity of that kind. It does not delete what exists.
- Roles decide who can see and answer what; see [The role matrix](help:user.roles.matrix).

**See also:** [Who may validate](help:user.validation.who-may) · [Required validations](help:user.validation.required-count)

<!-- anchor: setup.notify.operator -->
### The operator's part: making push work

**Audience:** Operator · Owner

You want push on members' phones, and you need to know who does what.

**Before you start**

Push does not come with the app by itself. If you run your space on the shared reference installation, ask its operator whether push is configured. If you run your own installation, you or your technical person are the operator.

**Steps**

1. Create a Firebase project and build the app with it. Without this the app stays on local notifications only, and a member sees **This build has no push notifications**. The build distributed through the F-Droid store has no push at all.
2. For iPhone and Mac, add an Apple push key to the Firebase project.
3. Store the Firebase service-account key as a secret of the server and deploy the push function.
4. On your own installation, point the `push_config` row of your database at your own push function URL and key. It is seeded with the address of the reference installation.
5. Test it with two accounts, as described in [the test plan](help:setup.notify.test).

**Good to know**

- Without steps 1 to 4, nothing is pushed, whatever the switches say. The feed, the bell and the messages still work.
- The detailed checklist is for the operator: see [Platforms](help:user.advanced.platforms) and [Your own server](help:user.advanced.own-server).
- Push text never carries a name or a time: this is deliberate, for privacy.

**See also:** [Push notifications on this device](help:user.privacy.push)

<!-- anchor: setup.notify.members -->
### What members control

**Audience:** Owner · Administrator

You want to tell your members honestly what they can switch off.

<p><img src="images/setup-notify-push.en.jpg" width="280"></p>

**Steps**

1. A member opens [Privacy & data](app:/privacy) and uses **Push notifications on this device** to stop or resume push on that device.
2. In [Messages](app:/me?tab=messages), a member presses and holds a conversation to **Pin to top**, **Mute notifications**, **Mark as unread** or **Archive**.
3. In the system settings of the phone, a member can refuse notifications altogether, check-in reminders included.
4. In their profile, a member decides whether to share a WhatsApp number.

**Good to know**

- A muted conversation stays silent but is still counted; a mention overrides a mute.
- A member who turns push off on one device is not affected on another.
- There are no per-category switches. If a member needs less noise, mute conversations; if they need none, switch push off.

**See also:** [Notifications](help:user.collaborate.notifications) · [Your data, your rights](help:user.privacy.consent)

<!-- anchor: setup.notify.test -->
### A test plan: send yourself one of each

**Audience:** Owner · Administrator · Operator

You make sure each channel works before your members depend on it.

**Before you start**

Do this in a test space (see [a safe dry run](help:setup.money.dry-run)). You need two accounts: yours as owner, and a second one as a member, on another phone, another browser, or the same phone after signing out. The demo space lets you see the screens with its personas, but it sends no real push.

**Steps**

1. Message: from the member account, write to the owner in [Messages](app:/me?tab=messages). On the owner account, the bell counts it and the conversation shows unread. Open it: the member's message shows a read receipt.
2. Mention: in a group conversation, name the owner (the mentions feature of messaging must be on). If push is set up, the owner's phone shows "You were mentioned in a conversation."
3. Decision: as the member, ask to delete a past booking (the **Booking deletion requests** feature must be on). The owner sees it under **Waiting for your confirmation** in [Events](app:/events); answer it and watch the member's feed change.
4. Removal: as the owner, remove a future booking of the member. The member's feed shows it, and a phone with push shows "A reservation was removed by an admin."
5. Reminder: as the member, book a place that starts in about 20 minutes (a booking starting in under 15 minutes gets no reminder). About 15 minutes before it starts, the member's phone shows the check-in reminder.
6. Payment reminder: with **Payment reminders** on, switch **Automatic reminders** on in the reminder rules with a short first-reminder delay, issue a trial invoice that has a payment term, wait past the delay, then open Finances as an owner or co-owner; the member's feed shows the alert.
7. Mute: as the member, mute the conversation, send another message from the owner, and check that nothing rings but the unread count rises.

**Good to know**

- Steps 2 and 4 show a push only if the operator's set-up is complete. If they fail while the others work, the fault is in the set-up, not in your rules.
- On the browser version of the app, there is no check-in reminder.
- A phone that blocks notifications shows nothing at all; check the system settings first.

**Result**

You have seen, with your own eyes, every channel a member will rely on.

**See also:** [The channels](help:setup.notify.channels) · [Start a conversation or a group](help:user.collaborate.messages-new)

<!-- anchor: setup.notify.silence -->
### Avoid overload, and avoid silence

**Audience:** Owner · Administrator

You want people to be told what needs them, and not drowned.

**Steps**

1. Keep **Notification feed grouping** on: members and administrators can fold the feed by type, day or member.
2. Ask for validation only where a decision is real: every rule that requires validation creates a request somebody must answer. See [Validation rules](help:user.validation.overview).
3. Use the auto-validation switches for requests where the answer is obvious.
4. Look at [What needs you](help:user.collaborate.attention) from time to time: it ranks what is waiting.

**Good to know**

- Overload comes from rules that ask too often or from too many administrators on one rule.
- Silence comes from a rule with nobody to answer it: requiring two validations when only the owner exists, or listing administrators who have left, leaves requests waiting for ever. The setup readiness card can flag a booking rule with too few validators.
- Silence also comes from push without set-up, from members who turned push off, and from a system that blocks notifications.
- Automatic payment reminders are not a substitute for looking at the open invoices from time to time.

**See also:** [Who may validate](help:user.validation.who-may) · [Required validations](help:user.validation.required-count)
