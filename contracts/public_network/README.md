# Public-page writes

`operations.json` is the source of the generated OpenAPI and Dart bindings.
`publication.page.save` remains an authenticated, owner-only management call;
public discovery still reads the anonymous allow-listed projection.

The writer accepts `p_mode: "replace"` or `"patch"`. Replacement discards omitted
fields. A patch preserves omitted fields, so an editor can change a description
without rewriting fields it does not edit. In either mode, JSON `null` removes
the stored field; for an inherited field that restores following the workspace.
An empty string remains a deliberate blank value. The existing rule that the
public address follows the workspace address is unchanged.

`PublicationDraft` keeps typed writable values, and `PublicationPatch` carries
the explicit mode through the actions, repository and Demo. Coordinates are
finite JSON numbers within their geographic bounds and form a complete pair;
clearing the place removes both keys. SQL validates the resulting document
before it writes and serializes a patch with other page writes for that workspace.

For compatibility, calls without `p_mode` still replace the page and accept the
legacy string coordinates. Stored coordinates are normalized to numbers. The
public v1 projection still returns decimal strings, so older discovery clients
keep displaying their map location. No new profile facets are introduced here;
those are the next checkpoint of #2832.

## Optional profile facts

`profile_facets` advertises optional `amenities`, `accessibility` and
`opening_hours` in the public document. Catalogue arrays use the ids in
`PublicationInput`; SQL's catalogue is rendered from that same source. Inputs
reject unknown ids, duplicates, non-string items and oversized arrays. An
omitted field is unchanged, null removes it, and an empty array publishes no
listed facts. Neither absence nor an empty accessibility array is a claim that
the business is inaccessible. Older readers ignore these optional fields.

Place-business hours follow explicitly configured `booking_rules` weekdays and
start/end minutes plus the workspace timezone. Missing or malformed rules are
not published; the reader does not invent opening hours from defaults. Updating
rules or timezone refreshes the public card. This describes regular hours, not
live availability, exceptional closures or booking entitlement. Businesses
without place booking may write an `opening_hours` text note; the projection
wraps it with the workspace timezone. Place businesses cannot write a parallel
hours note. The typed editor draft extracts a note from that public projection.

Public-page content remains in the existing publication writer, separate from
workspace configuration imports. No new configurable booking rule or feature
flag is introduced; the availability editor and setup questionnaire continue
to own the existing hours settings.
