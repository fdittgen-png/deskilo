# The messenger lives in Me — visibility matrix and strategy

Status: decided 2026-10-05 (ADR 0034). The workspace keeps its **alerts**; every
**discussion** lives in the messenger of the Me space, labelled by the context
it started in. What others may see of a person, and who may write to them, is
one matrix, edited in Me › Me and previewed "as seen by".

## 1. Who is looking (the relationship, not the role)

| # | Viewer | Meaning |
|---|---|---|
| V0 | Me | the account itself |
| V1 | Co-member | shares at least one workspace with me (either environment of a pair) |
| V2 | Chosen space | member of a space I picked for that field |
| V3 | External workspace | a person only known through another workspace or a connected installation, no space in common — judged by the server that holds my account as a signed-in person (V4), see §1.1 |
| V4 | Signed-in stranger | any signed-in account on this installation |
| V5 | Public visitor | not signed in: the public workspace page, the public directory |
| V6 | Space operator | admin/owner of a space I belong to — governed by the space's own rules, below |

### 1.1 The external tier is V4, judged by my own server (#2211, 0392)

There is no server-to-server federation. A connected installation is the
app signed in to another DesKilo server with that server's own account
(`connected_installations.dart`); no server ever asks another one what to
show. So a person reached through another installation is, on the server
that holds my account, simply a signed-in account with no space in common
with me, and the matrix's "V3 via V4" is literally how it is decided.
What I show there is what I set on that server.

Two rules make that tier safe, and the server enforces both (0392):
contact channels and presence can never be set wider than my spaces
(`set_visibility` refuses it, and older wider rows were narrowed); and an
ignored or still-pending message request gives the sender no right to keep
writing (`visible_account.can_message` counts only an accepted
conversation).

## 2. What can be seen (the field)

| Field | V0 | V1 co-member | V2 chosen space | V3 external | V4 signed-in | V5 public | Default |
|---|---|---|---|---|---|---|---|
| Name and photo (identity) | always | choice | choice | choice (via V4) | choice | **never** unless I publish a public profile (future tier) | V1 |
| Profession and bio (about) | always | choice | choice | choice (via V4) | choice | never | nobody |
| WhatsApp and e-mail (contact channels) | always | choice | choice | never | never | never | nobody |
| Presence ("in the space today") | always | choice (only inside the space it concerns) | choice | never | never | never | nobody |
| Which spaces I belong to | always | only the spaces we share | choice | never | never | never | shared spaces only |
| Who may start a conversation (reachability) | always | choice | choice | request only | request only | never | V1 |
| A conversation's content | participants only — never a space operator, never the platform |

The ladder of audiences for one field is ordered from narrow to wide:
**Only me < Chosen spaces < My spaces < Signed-in people**. Three rules
protect the ladder: contact channels and presence never go wider than *my
spaces*; the public visitor sees nothing of a person except what the person
publishes on a public page on purpose; widening a field asks for a
confirmation naming the audience ("every signed-in person will see your name
and photo").

## 3. Governance data is not social visibility (V6)

A workspace operator sees what running the space needs — membership, role,
subscription, bookings, invoices — because the member joined under that
space's terms. That never includes private conversations, the person's other
spaces, or profile fields the person did not share. Leaving a space ends the
operator's access to everything except evidence the space must keep (invoices).

## 4. Strategy

1. **One matrix, one place.** The person edits it in Me › Me (field × audience)
   and sees "as seen by" a co-member, a signed-in person, and themselves.
2. **Private by default.** Defaults are the table's last column; an account
   that never chose shows only its name and photo to people it shares a space
   with, and can be written to by them.
3. **Reachability is separate from visibility.** Being visible does not mean
   being writable. A first message from someone outside my reachability is held
   as a *request* (accept / ignore / block); an accepted request becomes a
   conversation and keeps working if either side later leaves a space.
4. **Context is a label, not a container.** A conversation records where it
   started (workspace, discovery inquiry, direct) and shows it as a chip; it
   lives in one inbox in Me. Alerts about the workspace itself stay in the
   workspace.
5. **Block wins.** A block removes reachability and presence for that person
   everywhere, without telling them.
6. **Preview before widening.** Every change that widens an audience previews
   the result for that audience before it is saved.
7. **The server decides.** `visible_account`, `my_visibility`, `set_visibility`
   (#1822) answer for every viewer; the client never filters hidden data, it
   receives it already left out.

## 5. Where this stands

Delivered: the four audiences, the five fields, the preview, the server
functions, the unified inbox in Me, and — with this change — the workspace
Messages destination reduced to alerts plus one door to the messenger.

Delivered since (#2211): message requests (0388) and blocks (0387); the
public-profile tier for V5 with an explicit publish step (0389/0390); the
widen confirmation naming the audience; the external tier (§1.1, 0392).

Follow-up: porting pin / mute / archive / search from the legacy workspace
conversation list into the Me inbox, then deleting that list.

## 6. Conversations: levels and what may be shared

A conversation is classified by WHO is in it, and that decides what its messages
may carry. The rule is enforced in the database on every insert (migration 0381),
so sending, forwarding and any future path obey it.

| Level | Who is in it | Text, emoji, quote, forward | References (reservation, space, invoice, payment, alert) |
|---|---|---|---|
| L1 — one workspace | everyone belongs to the same workspace (direct or group) | yes | yes, to THAT workspace |
| L2 — shared workspace | two people (or more, later) with a workspace in common | yes | only to a workspace every participant belongs to |
| L3 — no workspace in common | people with no common workspace | yes | **never** |
| Inquiry | an outside person and a space's hosts | yes | **never** |
| Workspace broadcast | the whole workspace | yes | only that workspace's own |

What a person shares is what they choose to attach: a reference carries a label
the sender sees and confirms in the picker; nothing is attached automatically, and
opening a reference still goes through that workspace's own permissions.

Group operations (create, rename, add and remove people, admins, leave) follow the
level: a workspace group is managed by workspace rules; groups across workspaces
(L2/L3) are text-only and need their own server model (tracked separately).
