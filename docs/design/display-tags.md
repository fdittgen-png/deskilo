# E-paper display tags — concept

Battery e-paper tags on the furniture, driven over WiFi by DesKilo,
showing what is reserved: a seat, a desk, an office door, a floor.

Status: **concept**. Nothing is built. This exists to be argued with
before an issue is filed.

---

## 1. What it is for

Someone walks into the space looking for somewhere to sit. Today the
answer is on their phone, in the plan view. That works, and it will keep
working — but the person standing in front of a desk is looking at the
desk, not at their phone, and the desk says nothing.

A tag answers the question where the question is asked:

> **Bureau 1 · A3** — Réservé jusqu'à 13:00 · G.D.

The scope is deliberately narrow. A tag **displays**; it never books,
never authenticates anybody, never accepts input. The moment a tag can
take a booking it needs an identity model, an audit trail and a
threat model, and it stops being a label.

## 2. What already exists

Almost all of the hard part is in the schema already.

| Piece | Where | What it gives us |
|---|---|---|
| The four-level hierarchy | `levels` → `offices` → `desks` → `seats` (0003) | a tag binds to any of them |
| Whole-space booking | `bookable_as_whole` on levels (0050), offices (0057), desks (0059) | an office can be booked entire, and the tag must say so |
| The state computation | `seatStateAt` in `seat_state_logic.dart` | coverage by seat, desk, office **and** level is already resolved in one pure function |
| A stateless token device | `kiosk_act` + `badge_token_hash` (0043) | the exact authentication shape a tag needs, already precedented |
| Hardware id on a plan object | `seats.nfc_uid` (0114) | a nullable, format-checked, uniquely indexed column — the shape to copy |

**The state logic is the thing not to rebuild.** `seatStateAt` already
knows that a level reservation occupies every seat on the plan, and that
a whole-desk booking covers each of its seats. A tag that computed its
own answer would drift from the plan view within a release, and the
failure would be invisible: the desk and the phone would simply disagree
and nobody would know which was lying.

## 3. The one architectural decision

**The server renders. The tag draws.**

`display_tag_state(p_token)` returns finished lines — headline,
subline, state, timestamp — already in the workspace's language, already
formatted. The firmware contains no business logic at all: fetch, draw,
sleep.

The reason is operational, not aesthetic. A server function is deployed
once. Fifty tags screwed to fifty desks are a weekend with a USB cable.
Every decision that might change — wording, language, what a half-booked
desk says, whether initials or a full name appear — belongs on the side
that can be changed.

The corollary: **the response carries the next poll time.** The server
decides the rhythm, because the server knows the booking granularity and
the tag does not.

## 4. What each level shows

| Bound to | Size | Content |
|---|---|---|
| **Seat** | 2.13″ | *Free* · or *Reserved until 13:00 · G.D.* |
| **Desk** | 2.13″ | *3 of 4 free* · or *Booked whole until 17:00* when `bookable_as_whole` |
| **Office** (door) | 4.7″ | *Office 1 · 6 of 8 free* · next occupancy |
| **Floor** (stairwell) | 6″–9.7″ | *Floor 1 · 12 of 30 free* — counts only, never names |

Size follows reading distance. You stand at a seat; you read a floor
board walking past.

Aggregate levels solve the privacy question by themselves: a floor board
has nothing to leak because it shows only numbers.

## 5. Data model

```sql
create table display_tags (
  id            uuid primary key default gen_random_uuid(),
  workspace_id  uuid not null references workspaces(id) on delete cascade,
  token_hash    text not null unique,        -- badge_token_hash(), 0043
  target_kind   text not null check (target_kind in
                  ('level','office','desk','seat')),
  target_id     uuid not null,
  label         text,                        -- "door of office 1", for humans
  size          text,                        -- '2.13' | '4.7' | '6' | '9.7'
  last_seen     timestamptz,
  battery_pct   int,
  firmware      text,
  -- plus the six system columns (ADR 0018)
);
```

`target_id` is deliberately **not** a foreign key to four different
tables — it is resolved by `target_kind`. A polymorphic reference is
the lesser evil against four nullable columns of which exactly one may
be set.

`last_seen` and `battery_pct` are not decoration. **A dead tag shows a
stale reservation and tells nobody.** Someone puts their bag down on a
desk that has been free for two hours. The admin list must show which
tag has been silent since Tuesday, or the whole thing is worse than no
tag at all.

## 6. The RPC

```sql
display_tag_state(p_token text) returns jsonb
```

Read-only, returns exactly one object's state, resolves the state
through the same predicate `seatStateAt` uses.

```json
{ "kind": "seat",
  "headline": "Bureau 1 · A3",
  "state": "reserved",
  "line1": "Réservé jusqu'à 13:00",
  "line2": "G.D.",
  "next_poll_seconds": 1800,
  "firmware": "1.2.0",
  "as_of": "2026-09-09T09:12:03Z" }
```

**`SeatState` has five values but a tag can only render four.** `mine`
is relative to the viewer, and a desk has no viewer. The RPC must never
return it.

## 7. Refresh rhythm follows granularity, not a timer

This is where e-paper earns its place. `BookingGranularity` is
`halfDay`, `fullDay`, or a grid of 5–60 minutes. **A half-day workspace
changes state four times a day.** There is no reason to wake every five
minutes.

So the server computes `next_poll_seconds` from the granularity and the
next boundary: wake shortly before the next half-day begins, not on a
fixed interval.

The dominant power cost is not the display — it is the WiFi association.
Store the BSSID and channel, use a static IP, skip the DHCP wait, and a
wake costs well under a second of radio instead of five. At a handful of
wakes a day a 2000 mAh cell lasts a very long time.

**Measure this before believing it.** Every number in this section is an
estimate.

## 8. OTA belongs in version 1

This is the only thing that cannot be retrofitted. A tag without OTA,
screwed to a wall, is a tag you unscrew.

The response already carries `firmware`. If it names a version newer
than the running one, the tag fetches and flashes it. Even if no second
firmware is ever built, the capability costs almost nothing now and
everything later.

## 9. Security and privacy

**A tag has no session.** The token is the authentication, hashed with
the existing `badge_token_hash()`, issued once and never shown again —
exactly the badge model from 0043.

That means the RPC needs `grant execute … to anon`, and **the repository
has never done that.** It is defensible for a strictly read-only
function returning one object, but it is a real decision and belongs in
an **ADR**, not slipped into a migration.

**Initials by default.** A door tag hangs in public; whoever walks past
reads it. DesKilo already treats "show who is here" as its own choice —
`planMemberPhotos` is a separate flag — and this follows the same rule:
initials or nothing unless the owner turns full names on.

## 10. What does not travel

Tags are **not** a deployable entity. The binding is physical and
belongs to one building, exactly like badges and maintenance blocks,
which already never travel between the DEV and PROD twins.

A tag paired against the development workspace must be visibly marked as
such — the same instinct as the development watermark on documents. A
test tag that looks like a real one is how someone ends up trusting the
wrong number.

## 11. Devices

Prices seen 2026-09-09; **verify before ordering**, they move.

### Ready-made, with battery

| Device | Size | Price | Role | Where |
|---|---|---|---|---|
| **Inkplate 2** | 2.13″, 3-colour | **€34.90** | seat, desk | [soldered.com](https://soldered.com/products/inkplate-2) · [welectron.com](https://www.welectron.com/Soldered-Inkplate-2_1) |
| **LilyGO T5 2.13″** | 2.13″ | ~€20 | seat, desk | [wiki.lilygo.cc](https://wiki.lilygo.cc/products/t5-series/t5-epaper-2.13inch/) |
| **LilyGO T5 4.7″ V2.3** | 4.7″, ESP32-S3 | ~€30–40 | office door | [lilygo.cc](https://lilygo.cc/products/t5-4-7-inch-e-paper-v2-3) |
| **LilyGO T5 E-Paper S3 Pro** | 4.7″, RTC, USB-C | ~€45 | office door | [lilygo.cc](https://lilygo.cc/products/t5-e-paper-s3-pro) |
| **M5Paper S3** | 4.7″, touch, enclosure | ~€70–90 | office door | [m5stack.com](https://m5stack.com) |
| **Inkplate 6** | 6″ | ~€99 | office, small floor | [soldered.com](https://soldered.com/products/inkplate-6-6-e-paper-board) |
| **Inkplate 10** | 9.7″ | **€179.00** | floor board | [soldered.com](https://soldered.com/products/inkplate-10) · [welectron.com](https://www.welectron.com/Soldered-Inkplate-10-97-e-paper-board) |

### Cheaper at volume

**Waveshare ESP32 e-Paper Driver Board** plus a separate panel — one
board, swap the panel per level (2.9″ / 4.2″ / 7.5″). Roughly €25–45
together, but no battery, no enclosure, and the wiring is yours.
→ [waveshare.com](https://www.waveshare.com)

### Shipping

- **Soldered / Inkplate** — Croatia, **inside the EU**. No customs, no
  three-week wait, and support answers. For a pilot in France this is
  the least friction, which at two units matters more than the price.
- **welectron.com** — Germany, EU, stocks Inkplate.
- **LilyGO / Waveshare** — China direct. Materially cheaper and
  technically equivalent; thinner documentation and slower delivery.
  Worth it at fifty units, not at two.

### The route that wins at scale — and its blocker

[**OpenEPaperLink**](https://openepaperlink.de/)
([GitHub](https://github.com/OpenEPaperLink/OpenEPaperLink)) reflashes
cheap supermarket shelf labels and drives dozens of them from **one**
ESP32 access point. Years of battery, tags for a few euro each: exactly
this problem, already solved.

**Its licence is CC BY-NC-SA 4.0 — non-commercial use only.** DesKilo is
0BSD and runs a commercial coworking space. That is a legal blocker, not
a technical one, and it is the kind that surfaces after fifty tags are
already on the wall. For an association or private use, look hard at it;
commercially, clear it with the authors first or stay away.

It would also change the shape here: OpenEPaperLink tags speak IEEE
802.15.4 to the access point, and only the access point is on WiFi. One
gateway instead of fifty clients is *easier* for the app — worth
remembering if the licence question is ever resolved.

## 12. What to buy first

**Two Inkplate 2 (~€70) and one LilyGO T5 4.7″.** Both size classes in
hand, EU shipping for the part that matters, and enough to build the
server side against real hardware before committing to a quantity.

**Hold the floor board.** €179 for a display whose content is one number
is not the first thing to buy.

**And before any of it: the paper test.** Print the intended text at the
tag's exact active area, tape it to a desk, and walk up to it the way
someone looking for a free seat would. Ten minutes, and it decides
whether the size is right — which is the only question the datasheet
cannot answer.

## 13. Open questions

- **Provisioning fifty tags.** WiFiManager captive portal per device is
  fine for three and miserable for fifty. Worth looking at ESP-NOW
  handoff or a QR-based enrolment from the app before the count grows.
- **Enclosures.** A bare development board on a desk reads as a
  prototype. Acceptable at two, not at fifty. 3D print, and that is
  design work nobody has started.
- **Power at every desk.** With e-paper and a sane wake rhythm this may
  genuinely be battery-only — but that assumption is unmeasured, and if
  it fails the real rollout cost is a USB cable per desk, not the €35.
- **Does the app write, or does a gateway?** The RPC shape assumes tags
  poll DesKilo directly. A gateway would change the security model
  entirely (one credential instead of fifty) and is the only sane shape
  if OpenEPaperLink ever becomes usable.

---

*Not decided here: whether to build it at all. The paper test and the
battery measurement come before the first migration.*
