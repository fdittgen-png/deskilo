<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# Who may do what in the Demo, and whose name it carries (#3293)

The Demo's people are the canonical cast (`lib/core/demo/demo_dataset.dart`)
and Leipzig's (`lib/core/demo/seed/demo_second_space_seed.dart`). A persona
switch moves the signed-in member and the session actor together
(`DemoFixture.becomePersona`); permissions are always
`effectivePermissions(member, workspace)`, the function live mode calls. This
matrix is what the Demo's fakes enforce and record. It does not replace the
server's RLS and RPC tests: each refusal below names the server rule it
mirrors, and the server remains the authority.

Rows marked ✓ are asserted by `test/core/demo/demo_persona_accountability_test.dart`.

## People and memberships

| persona | Pézenas (`ws-1`) | Leipzig | London / New York / Zurich / Milan | the practice (`ws-7`, #3863) |
|---|---|---|---|---|
| owner — Ada (`member-1`) | owner | co-owner (active) | member of each city cast | owner |
| member — Bruno (`member-2`) | member | member | as seeded per city; member in Zurich and Milan | client |
| admin — Chiara (`member-3`) | administrator | no membership: Leipzig is not listed for her | as seeded per city | client |
| kiosk — front desk tablet (`member-kiosk`) | kiosk device | none | none | none |

## Actions

| action | owner | admin | member | kiosk | recorded actor / server rule |
|---|---|---|---|---|---|
| request a quota extension, a reservation deletion, a write-off, a payment-terms change | allowed | allowed | allowed | — | the acting persona, at the session clock ✓ (`request_*` RPCs) |
| decide a request | allowed unless it is her own (owner self-validation only when the rule says so) | allowed within the rule's scope, never her own | refused for a request they made or one the rule does not give them ✓ | refused ✓ | the decider, at the session clock ✓ (`respond_to_event`, 0086/0135; client mirror `WorkspaceEvent.isDecidedBy`) |
| book for oneself | allowed | allowed | allowed while holding `makeReservations` | the badge member's walk-up | the acting member (0661) |
| book for another member | allowed | allowed ✓ | refused: "not an admin of this workspace" ✓ | — | subject = the chosen member; an inactive or unknown subject is refused ✓ (`admin_create_reservation_for`) |
| cancel a booking | own or anyone's | own or anyone's | own only; another's: "not your reservation" ✓ | — | (`cancel_reservation`) |
| kiosk walk-up | — | — | — | the badge member's own booking is theirs, another member's is "already reserved" ✓ | (`kiosk_act`, 0043/0050) |
| record an invoice payment under a validation rule | per rights | per rights | per rights | — | the event's actor is the acting persona |
| set up an expense schedule | per rights | per rights | per rights | — | the schedule is the acting persona's |
| assign a custom role | allowed, never to herself | allowed, never to herself ✓ | — | — | (`assign_workspace_role`) |
| edit a role's permissions | per `manageRoles` in the space being edited ✓ | per `manageRoles` in that space | refused ✓ | — | (`set_role_permission(s)`) |
| send a messenger message | signed with her name | signed with her name | signed with his name ✓ | — | |
| send a member note | from her | from her | from him ✓ | — | |
| send a conversation message | from her, to the other person of a direct thread ✓ | from her | from him, to the other person ✓ | — | only a current participant: a third person, or a member removed from the group, is refused ✓ (`send_conversation_message`, 0313) |

## Visibility

| what | who reads it |
|---|---|
| a direct conversation and its messages | its two people only: Chiara neither lists nor reads Ada and Bruno's thread ✓; Bruno sees it with Ada as the other person ✓; each reads the other's reply ✓ (`my_conversations`, `can_read_member_note`) |
| a group conversation | its current roster: an ordinary member reads another member's message ✓; a removed member no longer lists the group, nor reads what is written after, and keeps what was written while they were in it ✓ |
| the admin broadcast (a note to nobody in particular) | the owner and the administrators |
| Leipzig's requests | Leipzig's feed, not the main space's ✓ |
| a space's requests and decisions | whoever holds, in that space, a permission that reads the event's type (`event_type_view_permissions`, 0650/0666, as `events_select` reads it through `event_types_in_view`, 0216/0613): an administrator whose matrix explicitly lacks `viewFinances` and `issueInvoices` (and without the legacy `adminInvoicing` grant) reads nobody else's payment events nor their decisions, yet still reads what `manageMembers` reads ✓. A permission given by one of the space's own active roles counts the same way while `customRoles` is on, as `has_permission_raw` adds it (0247): a plain member assigned a role holding `viewFinances` reads another member's payment, loses it when the role is revoked, and loses it when `customRoles` is switched off ✓; the event's actor or subject; the validators its rule names. A decision is read only with its event, in the event's own space ✓. A persona with no membership of the space reads none, also through the routed repository after a persona switch ✓ |
| a privacy incident | only whoever holds `managePrivacy` now (0667, restrictive): not its actor or subject without the right, not a validator a rule names, not a former holder whose custom role was revoked ✓ |
| Leipzig itself | its members: a persona without a Leipzig membership does not see the space |

## Reset and isolation

A reset rebuilds the canonical dataset at the same instant and returns to the
owner: a request made as Bruno before it is gone ✓. Nothing in the Demo
reaches a server (`test/core/demo/demo_scope_test.dart`).

## Intentional Demo limitations

- Unread counts and read receipts are the fake's per-session approximations,
  not per-person server state.
- A conversation the suite seeds with neither a roster nor a message stays
  readable to every persona; every Demo conversation has a roster.
- Approval chains beyond one quorum step (sequential rules) follow the stored
  policy rows; the Demo seeds single-step rules.
- Deployment history is the twin pair's, recorded under the acting persona's
  name; the twin itself is simulated.
