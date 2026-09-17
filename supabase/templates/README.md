# Builtin workspace templates

One JSON file per builtin, named by its key. This is the reviewable source;
the migration that inserts or updates the builtin carries the same payload.
`test/lint/template_contract_test.dart` holds both to one contract (#1282):

- the file and the migration agree (a drift gate: a builtin edited in one
  place only fails);
- every builtin passes the contract: key shape, feature profile consistent
  with `featureManifest` (a child never on without its parent), working
  hours in order, known granularity and weekdays, non-negative prices, fee
  bands that neither overlap nor strand an offered subscription level, VAT
  labels that exist, lexicon overrides that keep their placeholders, entities
  that exist, and nothing from the publication deny-list.

Shape:

```json
{
  "key": "tiny", "name": "…", "description": "…", "sort_order": 0,
  "visibility": "builtin", "schema_version": 1, "tags": [],
  "entities": ["floor_plan"],
  "configuration": {"workspace": {}, "tables": {}},
  "floor_plan": []
}
```
