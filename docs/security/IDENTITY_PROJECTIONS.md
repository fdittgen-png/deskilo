# Identity projections — who reads which field of a person (#1833)

A person's identity lives on `profiles` (one row per account) plus a few
private tables. Another person never needs the row: they need the fields
of one **purpose**. This file is the field/audience matrix; the server is
the authority (`member_profiles`, migration 0319) and the Dart reader is
`lib/features/profile/domain/profile_projection.dart`. A column that is
not listed here is projected to nobody.

## Purposes

| Purpose | Who holds it for subject S, in space W | Carried as |
|---|---|---|
| **community** | a current (active/paused) member of W, when S is a current member of W | group `community` |
| **operational** | the same, AND the reader holds `viewPersonalData` or `issueInvoices` in W | group `operational` |
| **self** | S themselves, with or without any membership | both groups |
| **account** (#1823) | anyone, per S's own audience choice — outside spaces | `visible_account` / `preview_my_account` (0315) |
| **private auth** | nobody; only definer functions | own table |

Being an administrator, a co-owner or a member does not grant
`operational` by itself: only the two permissions do, in that space.
Naming another space the caller belongs to lends nothing (the subject must
be a member of the space named). Pending and exited members read nothing
and are read by nobody but themselves.

## Fields

| Field (`profiles` column) | Purpose | Notes |
|---|---|---|
| `display_name`, `avatar_path` | community | photo bytes: storage policy (checkpoint B) |
| `whatsapp` | community | opt-in, '' = not shared (#224) |
| `status_text`, `last_seen_at` | community | directory presence |
| `courtesy`, `first_name`, `last_name`, `company`, `street`, `postal_code`, `city`, `country_code`, `phone`, `email`, `vat_id`, `legal_id` | operational | `PersonalInfo` — what invoices and letters print |
| `address` | operational | legacy free-text postal block |
| `preferred_locale` | operational | the language documents to S are printed in |
| `format_locale`, `clock`, `time_zone_mode`, `default_workspace_id`, `privacy_accepted_*` | self only | read by `fetchMyProfile` |
| `pin_hash`, `pin_set_at` | private auth | moved to `account_badge_pins` (0319); the columns are held empty |
| `person_id`, `company_id`, `site_id`, system columns | none | technical |
| profession, bio (`account_about`) | account | 0315 audiences |

Issued invoices keep their own snapshot of the buyer (`create_invoice`);
editing a profile never rewrites them.

## Readers

| Reader | Path | Status |
|---|---|---|
| `memberProfilesProvider` → directory, member page, contact card, plans, kiosk, conversation avatars, invoice proforma, reminder/agreement language | `fetchProfiles` → `member_profiles` | **projection (checkpoint A)** |
| Excel export | `fetchProfiles` → `member_profiles` | **projection (checkpoint A)**; address/VAT columns only with the permissions |
| "How others see me" | `preview_my_member_profile('space_mate' \| 'personal_data')` | server ready; the Me screen (#1823) wires it |
| Own profile | `fetchMyProfile` → `profiles` row, `id = auth.uid()` | self |
| Member names on maps and lists | `fetchMemberNames` → `member_profiles`: display name for a space mate, "First LAST" only from the `operational` group | **projection (checkpoint B)** |
| Raw table | `profiles_select` = `id = auth.uid() or profile_row_readable(id)` (0351) | **closed (checkpoint B)**: readable by the person and by the operational audience only |
| Realtime `profiles` changes | rows the subscriber's policy admits | **closed (checkpoint B)**: a space mate receives nobody else's row |
| Avatar bytes | `avatars` bucket, `shares_workspace_with` | community audience: space mates read the photo object, strangers and exited members do not |
| External/network schema | #1847 | checkpoint B of #1847 |

### The direct read by a released client (0351)

No server-side client-version gate exists: an older app on a newer schema
is "supported" (`schema_compatibility.dart`, OPERATIONS.md). A released
client still reads space mates with `select * from profiles`; filtering it
silently would empty its directory and names. So a **direct** PostgREST
read (`GET`/`HEAD /profiles`) of a space mate's row is refused with
SQLSTATE `PT426`, which PostgREST answers as **HTTP 426 Upgrade Required**
with a message naming the fix. The refusal fires only on that route: a
self read, a self update, a stranger's absent row, Realtime (no request
path) and definer functions (table owner) never see it. Current clients
read other people only through `member_profiles`.

**Residual.** A reader holding `viewPersonalData` or `issueInvoices` in a
shared space still reads the whole row directly (released invoice
preview, Excel, letters depend on it). That audience may read those
fields through `member_profiles` anyway; closing the direct route for it
too waits for the last released reader to move.

### Indirect readers (audited, checkpoint B)

Definer functions that return `profiles` fields to a caller other than
the subject: `member_profiles` (the projection itself, per group),
`create_invoice` (the buyer snapshot, `issueInvoices`), `workspace_owners`
(platform owner, audited). Everything else is self-only. Avatars use the
community audience (`shares_workspace_with`).

Proof: `supabase/tests/database/104_member_profile_projection.sql`
(authenticated-role pgTAP, one canary per private field),
`supabase/tests/database/134_profiles_peer_read_closed.sql` (peer, admin
without the permissions, billing clerk, owner, stranger, exited member,
role revocation, PT426 on the direct route and nowhere else, avatars),
`test/features/profile/identity_purpose_projection_test.dart` (the app
asks for the projection and reads each field only from its group) and
`test/features/workspace/member_names_projection_test.dart` (names come
from the projection; legal names only from the operational group).
