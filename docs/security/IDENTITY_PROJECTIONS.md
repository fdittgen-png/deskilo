# Identity projections — who reads which field of a person (#1833)

A person's identity lives on `profiles` (one row per account) plus a few
private tables. Another person never needs the row: they need the fields
of one **purpose**. This file is the field/audience matrix; the server is
the authority (`member_profiles`, migration 0318) and the Dart reader is
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
| `pin_hash`, `pin_set_at` | private auth | moved to `account_badge_pins` (0318); the columns are held empty |
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
| Member names on maps and lists | `fetchMemberNames` → `profiles(first_name, last_name)` | checkpoint B |
| Raw table for released clients | `profiles_select` (`shares_workspace_with`) | checkpoint B — closed once released clients read the projection |
| Realtime `profiles` changes | whole row to every space mate | checkpoint B |
| Avatar bytes | `avatars` bucket, `shares_workspace_with` | checkpoint B |
| External/network schema | #1847 | checkpoint B |

Proof: `supabase/tests/database/103_member_profile_projection.sql`
(authenticated-role pgTAP, one canary per private field) and
`test/features/profile/identity_purpose_projection_test.dart` (the app
asks for the projection and reads each field only from its group).
