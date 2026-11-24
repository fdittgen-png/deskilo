# Embedded till contract — diagnostic profile checkpoint

## Status and authority

This is the first bounded producer/consumer checkpoint of #4452. It produces a
default key profile from the existing `TillKey` model and validates the same bytes
in the native LCDWiki E32R40T firmware. The profile is **diagnostic only**:
`financial_actions_enabled` must be `false`; no sale, authorization, cash
session, offline payment or drawer operation is enabled by this format.

The existing [counter receipt contract](counter-receipt-contract.md) remains the
financial authority. The firmware does not execute Dart or reinterpret a till
session as an electrical drawer command. The later connected protocol, operator
leases, complete envelope/digest interoperability and published-layout projection
remain separate unfinished checkpoints. This document does not claim that those
capabilities, hardware commissioning or fiscal support have been delivered.

## Producer and actual consumer

`lib/features/money/domain/embedded_till_profile.dart` projects the current
`TillKey` list in its existing order, with eight keys per page. It preserves item
IDs, labels, units and available cached gross amounts. It creates one empty page
for an empty catalogue. Oversize input, duplicate IDs, invalid text or unsupported
metadata are refused; nothing is silently truncated. The producer owns no item
catalogue, layout store or financial rule.

The command-line consumer accepts a JSON export shaped like
`contracts/embedded_till/v1/fixtures/profile_source.json`:

```bash
dart run tool/embedded_till_profile.dart source.json profile.json
```

It constructs the real `TillKey` objects, invokes the production projection and
writes compact UTF-8 JSON plus one trailing newline. Amounts in its source are
decimal strings. Validation finishes before the command writes the output;
the command exits nonzero on refusal.

The diagnostic firmware component embeds the shared `profile_valid.json` bytes
at CMake configure time. `validate_profile_json` checks them before the diagnostic
screen can report a valid profile. Embedded data is not a private second fixture:
changing the shared fixture regenerates the compiled byte array. Diagnostics
show validation status; the profile cannot activate checkout.

## Wire shape and evolution

The schema is `contracts/embedded_till/v1/profile.schema.json`; protocol ceilings
are recorded in `limits.json` and pinned by producer/consumer tests. Required
fields are protocol major/minor, board/display, profile UUID/revision, diagnostic
mode, disabled financial actions, required capabilities, currency/minor digits
and the ordered pages. A key names an item UUID, label, unit, exact quantity and
optional cached `gross_minor` string. Only `profile.v1` and `diagnostics` are
implemented required capabilities.

The firmware reader accepts **1.0 exactly**. It rejects unknown versions, fields,
actions/capabilities and duplicate object keys rather than guessing at future
meaning. Later additive compatibility must be deliberately specified and tested
before raising the version; there is no silent minor-version upgrade today.
Profile revisions are positive signed-32-bit integers. UUIDs are lowercase text.
Pages are numbered sequentially from one and item IDs are unique across pages.
The Dart projection validates already-decoded values; its `fromJson` entry point
cannot detect duplicate keys discarded by an earlier JSON parser. Raw incoming
payload validation belongs to the firmware decoder, not this producer API.

| Technical limit | Value |
|---|---:|
| Board identifier | `lcdwiki_e32r40t` |
| Display orientation | 480 × 320 landscape from the native 320 × 480 panel |
| Response/profile payload | 16,384 UTF-8 bytes, including whitespace |
| Reserved future request ceiling | 8,192 bytes |
| Keys per page / pages | 8 / 12 |
| Label / unit text | 96 / 32 UTF-8 bytes |
| JSON container depth | 12 |

These are conservative memory/protocol ceilings, not business sale limits.
Their actual device cost is measured by the board diagnostic checkpoint before
connected payments are enabled. A caller must bound the incoming buffer before
calling the decoder. The decoder checks the byte limit and nesting before
allocating a cJSON tree. It rejects malformed UTF-8, embedded NUL, duplicate
fields, invalid references and trailing JSON. It only accepts printable label
and unit text. JSON Schema's character-length checks do not replace the byte,
uniqueness, page-order and numeric-range checks in the consumers.

## Exact monetary primitives

Signed-64-bit minor amounts are canonical decimal strings: `0`, a positive
integer without leading zeros, or a negative integer without leading zeros.
`-0`, scientific notation, `+`, whitespace and JSON numeric amounts are refused.
Parsing bounds are `-9223372036854775808` through `9223372036854775807`.
Cached key prices must additionally be nonnegative. Currency is a three-letter
uppercase code with an explicit supported exponent of zero, two or three.

Quantity follows the established wire grammar: one to twelve decimal whole
digits, optional decimal point and one to six fraction digits, greater than
zero. No comma or exponent travels on the wire; localized input conversion
belongs to the later UI. The parser preserves exact millionths.

The pure testable gross-line helper performs half-up rounding once per line,
then checks signed-64-bit overflow. C++ divides the unit amount into quotient
and remainder before multiplying the fractional quantity, so the 32-bit target
needs neither floating point nor `__int128`. Dart uses `BigInt`. This helper is
not used to price online sales, and implements no VAT, stock or fiscal engine.

## Verification

Shared `decimal_cases.json` covers the `2^53` neighbors, both signed-64-bit
endpoints, overflow, malformed representations, exact fractional quantities and
half-minor rounding. `profile_cases.json` covers valid profiles and unsafe
metadata, money, quantities and references. The host decoder suite additionally
exercises byte/depth boundaries, invalid UTF-8, duplicate fields, truncated and
concatenated JSON, invalid numeric tokens, and maximum page/key capacity. The producer suite proves that
the actual projection reproduces the canonical fixture and that mutating caller
data cannot enable an already-validated profile.

```bash
dart run firmware/till/tests/host/terminal_contract_test.dart
cmake -S firmware/till/tests/host -B firmware/till/build-host
cmake --build firmware/till/build-host
ctest --test-dir firmware/till/build-host --output-on-failure
```

The host build uses the same pinned managed cJSON source as ESP-IDF. Run
`idf.py reconfigure` in `firmware/till` first to resolve that dependency, or pass
`-DCJSON_SOURCE_DIR=/path/to/resolved/cJSON` to CMake. No firmware SDK is needed
to compile the portable C++ tests after that source is available.

Host tests compile the same C++ sources as ESP-IDF. Compiler/fixture success is
software evidence only. Display calibration, live heap budget, physical GPIO
behavior and on-board power-loss evidence remain explicitly unverified until
their hardware commissioning is observed.
