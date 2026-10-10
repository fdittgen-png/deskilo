<!-- anchor: setup.people.overview -->
## People, roles and decisions

A space is its people. Before you invite the first of them, decide three things: who may do what, how someone gets in, and which acts need a second person to say yes. They are quick to set and awkward to repair once forty people rely on them.

In this chapter:
- [Who does what in a real organisation](help:setup.people.organisation)
- [The role matrix: least privilege](help:setup.people.matrix)
- [Co-owners: more than one person who can act](help:setup.people.coowner)
- [How people join](help:setup.people.join)
- [The invitation message, language by language](help:setup.people.invitation)
- [Managed profiles](help:setup.people.managed)
- [Validation: what a rule is made of](help:setup.people.validation)
- [Three presets to copy](help:setup.people.presets)
- [Avoid requests that wait for ever](help:setup.people.stuck)
- [The first week of your members](help:setup.people.first-week)

The running example is *Atelier du Marché*. Imagine it is run by an association: Ada is the president, Chiara the secretary, Bruno the treasurer. Every step below is shown on that space.

<!-- anchor: setup.people.organisation -->
### Who does what in a real organisation

**Audience:** Owner · Co-owner

You want to map the people of your organisation onto the roles DesKilo has, so that nobody holds more than their job needs.

<p><img src="images/setup-people-members.en.jpg" width="280"></p>

*The four base roles*

| Role | What it is for | In the association |
|---|---|---|
| **Owner** | The person who answers for the space and holds every permission. Only an owner can grant ownership. | Ada, the president. |
| **Co-owner** | A second key. Holds every permission by default, and can take over when the owner leaves. | The vice-president, if the board has one. |
| **Administrator** | Runs the day: members, bookings of others, the kiosk, documents, services. Holds what the matrix gives and no more. | Chiara, the secretary. |
| **User** | The person who uses the space. Holds only the everyday permissions you give. | Bruno, a member like the others. |

Everyone has exactly one base role. A role the space defines, such as *Host* or *Accountant*, is added on top of it and never takes anything away.

*A treasurer without being an administrator*

Bruno keeps the books but should not edit the floor plan or approve new members. Give him the base role **User** and add a role of your own, for instance *Accountant*, with four permissions: **View workspace finances**, **Issue invoices & match payments**, **Export accounting and data** and **Read the workspace figures**. Nothing more. No such role is built in; you create it with the steps below.

<p><img src="images/setup-people-roles-space.en.jpg" width="280"></p>

**Steps**

1. Open [Roles this space defines](app:/settings/roles-of-this-space) and tap **Add a role**. See [Roles this space defines](help:user.roles.space).
2. Name the role, choose **What it adds**, tap **Save the role**.
3. Open the person in [Members & plans](app:/members), find **Roles** and tap **Add a role**.

**Good to know**

- **Roles this space defines** is a feature of its own and is off in a new space. Switch it on in [Features](app:/features).
- Nobody can give a role to themselves. Giving a role needs **Manage roles & permissions**, and only an owner can give a role that carries it.
- A role the space defines takes effect at once and is recorded. Only making someone an administrator, or taking it away, follows the **Role change** validation rule.

**Result** Each person of the board holds the permissions of their job, and the owner remains the only one who can change that.

**See also:** [The role matrix](help:user.roles.matrix)

<!-- anchor: setup.people.matrix -->
### The role matrix: least privilege

**Audience:** Owner · Co-owner

You want each role to hold what it needs and nothing else. That is the principle of least privilege: start small, add when someone asks, because a permission given is rarely taken back with grace.

<p><img src="images/setup-people-roles-matrix.en.jpg" width="280"></p>

**Steps**

1. Open [Roles](app:/roles). There is one card per role: **Owner**, **Co-owner**, **Administrator** (the owner can rename it) and **User**.
2. Read the card of the **Administrator** first. It shows what an administrator holds in your space today.
3. Untick what you do not want to delegate. Tick the everyday permissions the **User** card needs (see below).

*What an administrator holds by default*

| Group | Permissions |
|---|---|
| People | **Manage members**, **Read members' personal data** |
| Bookings and the place | **Manage reservations of others**, **Operate the kiosk and badges**, **Manage sites and edit the floor plan** |
| Money, read and approve | **View workspace finances**, **Approve expenses**, **Manage services & packages**, **View commercial agreements**, **Manage commercial agreements**, **Request payment-condition changes**, **Export accounting and data** |
| Documents and figures | **Manage the document library**, **Read the workspace figures** |
| Two sides of a space | **Deploy to development**, **Enter the production workspace** |

An administrator does not hold **Manage roles & permissions**, **Configure validation policies**, **Edit workspace settings**, **Manage tariffs and billing rules**, **Design the documents**, **Manage integrations**, **Manage the configuration** or **Deploy to production**. A co-owner holds all of them until you untick some. The owner always holds all of them.

> **Careful** In a new space the **User** card is empty. The six everyday permissions (**Use the messenger**, **Book and use reservations**, **See the calendar**, **See the member directory**, **See their own account and invoices**, **See the shared documents**) are held only through the matrix or a role. Until you tick them, a member who joins cannot open the plan. The demo shows them already ticked, which hides this. Tick them for the **User** card, and for the **Administrator** card if administrators also book, then test with a second account.

**Good to know**

- By default an administrator can read all finances and the personal data of every member. If your administrators are volunteers, think about whether they should.
- **Admins issue invoices** (a feature, off by default, under **Invoices**) gives administrators **Issue invoices & match payments** whatever the matrix says. Prefer the tick in the matrix, or a role of your own, which is more precise.
- Unticking a permission removes it everywhere at once; the server checks it, not only the menu.
- Every change of the matrix is recorded as an event. The **Role management** feature only shows the screen; switched off, the matrix you saved still applies, you just cannot edit it.

**Result** A matrix you can explain in one sentence per role.

**See also:** [The role matrix](help:user.roles.matrix) · [Who does what](help:setup.before.who)

<!-- anchor: setup.people.coowner -->
### Co-owners: more than one person who can act

**Audience:** Owner · Co-owner

You want the space to keep working when you are ill, away or gone. Every space needs more than one person who can act. By default only owners and co-owners hold the permissions that change features, roles, validation rules and the workspace ID, and only an owner can make another owner.

<p><img src="images/setup-people-coowner.en.jpg" width="280"></p>

*The two kinds*

| Kind | What it does | Choose it when |
|---|---|---|
| **Active co-owner** | Holds the owner's permissions now, and takes over if the owner leaves. | You share the work: the vice-president, a partner. |
| **Successor** | Waits. Becomes owner when you promote them or when you leave. | You only want an heir. |

**Steps**

1. Switch on the **Co-owners** feature in [Features](app:/features). It is off in a new space.
2. Open the person in [Members & plans](app:/members), go to **Manage** and tap **Co-ownership**.
3. Choose **Active co-owner** or **Successor**. To hand over now, choose **Promote to owner now**.

**Good to know**

- If the last owner leaves, the best co-owner becomes owner on their own, an active one before a successor.
- Two administrators are not the same thing: an administrator holds only what the matrix gives and can never hand ownership on.
- A rule that says **Owner must always validate** asks for an owner. Check on your test side that your co-owner can still decide what you expect.

**Result** The space has a second person who can act.

**See also:** [Co-owners](help:user.roles.co-owners) · [Co-ownership](help:user.members.co-ownership)

<!-- anchor: setup.people.join -->
### How people join

**Audience:** Owner · Administrator

You want to choose how people reach your space and who lets them in. Four ways exist, and every one of them ends in the same place: a person asking to join, and someone deciding.

<p><img src="images/setup-people-workspace-code.en.jpg" width="280"></p>

| Way | What the person receives | What they become |
|---|---|---|
| The workspace ID | A short word, typed in the app. | A member, after approval. |
| The QR code | The same ID as a picture to print or post (**Share as PNG**). | A member, after approval. |
| An invitation message | A text with a personal code, valid for one person, in the language you pick. | The role you offer, after approval. |
| An administrator code | A one-person code from the **Administrator invite** tab. | An administrator, once. |

**Steps**

1. Open [Workspace ID & QR](app:/workspace-code). Choose an ID people can remember with **Change workspace ID**: 4 to 20 letters or digits, unique across DesKilo.
2. For a named person, tap **Invite someone**. Fill in the name, tick **Roles on arrival** if they should receive a role, pick the **Message language** and send.
3. When someone asks to join, their row in [Members & plans](app:/members) says **Pending**. Open it and choose **Approve membership** or **Reject membership**.

**Good to know**

- Nobody gets in without a decision. Until it is taken, the newcomer sees a waiting screen and nothing else.
- The decision follows the rule of **New member** in [Validation rules](app:/validation): by default one owner or administrator suffices; if you require two, the first approval leaves the person pending.
- If you change the workspace ID, the old one stops working. Print the QR code again.
- There is no owner invite. Ownership is given in **Members & plans**.

**Result** People can find you, and you decide who stays.

**See also:** [The workspace ID](help:user.workspace.code) · [Join a workspace](help:user.start.join) · [Pending and paused members](help:user.members.pending)

<!-- anchor: setup.people.invitation -->
### The invitation message, language by language

**Audience:** Owner · Administrator

You want an invitation that sounds like your space, in the language of the person who gets it. Each language has its own text; the one you do not write falls back to the built-in message.

<p><img src="images/setup-people-invite.en.jpg" width="280"></p>

<p><img src="images/setup-people-invitation-message--message.en.jpg" width="280"></p>

**Steps**

1. Open [Workspace](app:/workspace-settings) and go to **Community & invitations**.
2. Under **Message language** choose the language you write for. The row opens on your workspace language.
3. Write the text. Tap a tag to insert it where the cursor is. The limit is 2000 characters.
4. Repeat for each language your members use, then tap **Save**.

*The tags*

| Tag | Filled in with |
|---|---|
| `{firstName}` `{lastName}` `{phone}` | What you typed in **Invite someone**. Empty if you typed nothing. |
| `{workspaceName}` | The name of your space. |
| `{workspaceId}` | The personal invitation code of this message (not the public workspace ID). |
| `{inviteLink}` | A link that opens the app on the right server with the code filled in. |
| `{downloadUrl}` | The store page of the app. |
| `{role}` | The role the invitation offers, in the language of the message. |

**Good to know**

- Leave the box empty and the app writes its own message in that language. It explains the steps: download, create an account, join with the code.
- Do not paste a code or a link yourself. Each send creates its own code, valid for one person.
- A tag you misspell stays visible in the sent text: read the preview before you send.
- The built-in message tells the person the code is single-use and valid for 14 days.

**Result** An invitation your members can follow without asking you.

**See also:** [Invitation message](help:user.workspace.settings.invitation-message) · [Invite someone by message](help:user.workspace.code.invite)

<!-- anchor: setup.people.managed -->
### Managed profiles

**Audience:** Owner · Administrator

You want to book, invoice and manage for someone who has no account yet: a visitor, an elderly member, a person who prefers paper.

**Steps**

1. Switch on **Managed profiles** in [Features](app:/features).
2. In [Members & plans](app:/members), tap **Add a managed profile** and fill in the identity.
3. When the person is ready, open their page and choose **Hand over to the person**. It creates a personal code bound to the profile.

**Good to know**

- Whoever redeems the code takes over the profile with its bookings, invoices and subscription, once you approve the membership.
- Take the handover back with **Revoke handover** if the code was not used yet.

**See also:** [Add a managed profile](help:user.members.managed)

<!-- anchor: setup.people.validation -->
### Validation: what a rule is made of

**Audience:** Owner

You want to choose, act by act, whether a second person must agree. A validation domain is one kind of act with its own rule: *a payment*, *an expense*, *a new member*, *a booking deletion*. In **Validation rules** the domains sit in three groups.

<p><img src="images/setup-people-validation-overview.en.jpg" width="280"></p>

| Group | Domains, in plain words | While it waits |
|---|---|---|
| **Money** | A payment, an expense, a service, an invoice matched to its payment, an invoice issued or cancelled, a refund, a write-off, a price agreement, a shared expense, a scheduled expense, a payment-condition change, an early departure, a usage record removed | The amount does not count on anybody's statement. |
| **Bookings** | **Extra half-days** a member asks for, **Whole-space reservations**, a booking made for a member by an administrator, a **Booking deletion** | The seat stays as it was. |
| **People and roles** | **New member**, a role change, a change of status, a subscription change, a change of the permission matrix | The person keeps the access they have now. |

Every domain starts with **Inherits default**: one validation by any administrator or owner. **Default policy** is the rule all the others inherit. A domain you open and save becomes **Customized**.

*The knobs of a rule*

| Setting | What it means | Needs |
|---|---|---|
| **Required validations** | How many people must say yes. | |
| **Who validates** | **Admins**, **Listed persons** or **All members**. The owner always may. | **Validators by role or person**: without it the choice is not shown and administrators validate. After switching it off, check again the rules that named **Listed persons** |
| **Admins may validate** | Off, only owners validate. | |
| **Owner must always validate** | One of the yes answers must come from an owner. | |
| **The owner may validate their own** | The owner's own request is not left waiting for someone else. An administrator never gets this. | **Chained validations** |
| **One after another** | The second is asked once the first has said yes. | **Chained validations** |
| **Only above this amount** | Below it, the act applies at once. Money domains only. | **Chained validations** |
| **Admins delete without validation** / **Owners delete without validation** | Their own **Booking deletion** settles itself and stays marked as auto-validated. Off by default. | |

<p><img src="images/setup-people-validation-sheet.en.jpg" width="280"></p>

**Steps**

1. Open [Validation rules](app:/validation). Tap **Default policy** and decide what everything else inherits.
2. Tap a domain, set the knobs, tap **Save**.
3. Keep few exceptions. Each exception is one more thing you must remember when someone says "why is this waiting?".

**Good to know**

- Nobody validates their own act. It waits for someone else, unless the owner exception is switched on.
- Every decision is recorded: who, when, on what.
- A request nobody answers expires after seven days, swept the next time anyone opens Events. An act an administrator did for a member is confirmed automatically instead.

**See also:** [Validation rules, domain by domain](help:user.validation.overview) · [Who may validate](help:user.validation.who-may) · [Auto-validate](help:user.validation.auto-validate-admin)

<!-- anchor: setup.people.presets -->
### Three presets to copy

**Audience:** Owner

You want a rule set you can copy today and refine later. Choose one; each relies on the default scope, owner and administrators, so no extra feature is needed.

| Preset | Choose it when | What you set | Validators you need |
|---|---|---|---|
| *Open join* | You know the people who will scan your code. | Nothing. Every domain inherits the default: one validation by any owner or administrator. A join is still never automatic. | 1 (you) |
| *Approve joins* | A board decides who enters. | **New member**: **Required validations** 2, **Owner must always validate** on. | 2: an owner and one administrator |
| *Approve joins and bookings* | Seats or whole rooms are scarce, or booking deletions need a witness. | *Approve joins*, plus on **Whole-space reservations**, **Extra half-days** and **Booking deletion**: **Required validations** 1. | 2 at least, 3 to be comfortable |

In the association: Ada is the owner, Chiara an administrator. With *Approve joins*, Ada and Chiara both approve each newcomer. With the third preset a whole room Bruno books is blocked for him at once, but Ada or Chiara can still refuse it, and a deletion Chiara asks for is decided by Ada, not by Chiara.

**Steps**

1. Open [Validation rules](app:/validation).
2. Tap **New member**, set what the table says, tap **Save**.
3. For the third preset, repeat on the other three domains.
4. Open **Members & plans** and count your active owners and administrators. It must be at least the number in the last column.

**Good to know**

- An ordinary booking by a member is never held for approval by these presets. What waits is a whole room, extra half-days, a deletion and the join.
- A preset is a starting point. Raise a number only when you have enough people to answer.

**See also:** [Required validations](help:user.validation.required-count) · [An owner is required](help:user.validation.owner-required)

<!-- anchor: setup.people.stuck -->
### Avoid requests that wait for ever

**Audience:** Owner · Co-owner

You want to be sure that every request you create a rule for can be answered. A rule that needs more validators than exist is not refused everywhere: the request is created, nobody can complete it, and it expires after seven days.

> **Careful** The editor counts one extra validator for the person concerned, so it lets you save **Required validations** one above the people you have. That extra yes exists only for a booking an administrator made for a member, and for some payments. For a join or a money request it does not exist. Do not rely on the editor to count for you.

*Count before you require*

| You require | You need, besides the person who asks |
|---|---|
| 1 | One active owner or administrator |
| 2 | Two active owners or administrators |
| 2 with **Owner must always validate** | An owner and one more |
| A **Listed persons** list | Each person on it must be active; a new administrator is not added automatically |

*How to check*

1. Open [Validation rules](app:/validation) and read each customised card: "All admins — any 2" means two people.
2. Open [Members & plans](app:/members). Count the active owners and administrators. Paused and exited people do not count.
3. Open **Setting up this space** in [Workspace](app:/workspace-settings). The area **Roles and who validates requests** says "A policy asks for more validators than this space has" when it counts too few. It holds up the first booking only when the rule is for reservations.
4. Open [Events](app:/events). **Waiting for your confirmation** shows what is waiting, and a row shows "1/2 validations".

**Good to know**

- The editor itself says **Not enough eligible validators.** when a count clearly exceeds the people available. It does not catch every case.
- A solo owner who asks for something for themselves is waiting for someone else: either add an administrator, or switch on **The owner may validate their own** under **Chained validations**.
- Pausing or removing an administrator can leave a rule short. Recount after every change of team.

**Result** Every rule can be answered by people who exist.

**See also:** [Required validations](help:user.validation.required-count) · [Keep it consistent](help:setup.consistent.overview)

<!-- anchor: setup.people.first-week -->
### The first week of your members

**Audience:** Owner · Administrator

You want your first members to succeed without asking you. What you tell them in the first week decides how much you answer in the second.

*Before you invite anyone*

1. Sign in as a second person on a test account and join your space. Check that you can open the plan and book a seat.
2. Approve that account as a member, and have the second validator approve too if you require two.

**Steps**

1. Send the invitation message. It tells people how to download the app, create an account and join. See [Join a workspace](help:user.start.join).
2. Approve each newcomer the same day. A person waiting for a day starts with a doubt.
3. Tell them the three first things: the plan and booking ([Reserve a place](help:user.reserve.book)), checking in ([Check in and out](help:user.reserve.check-in)), and where their requests wait ([Events](help:user.collaborate.events)).
4. Tell them what you see about them and what they control ([Who can see my data](help:user.privacy.visibility)).
5. Name one person to ask, and where: the messenger, or the desk.

**Good to know**

- When an administrator does something for a member, it stays pending until the member confirms. Warn them, or the first booking you make for someone will look like a mistake.
- Members who do not use push notifications still find everything under **Events**.
- On the first Reserve visit the **Get started** card shows owners what is still missing. Members have their own short tips. See [The Get started card and the tips](help:user.start.get-started).

**Result** People who know how to book, how to check in and whom to ask.

**See also:** [Week 0 to week 4](help:setup.training.overview) · [How members are told](help:setup.notify.members)
