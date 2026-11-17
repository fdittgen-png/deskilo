# deskilo_money_kernel

The pure primitives under the accounting model (#3376 of #3328): `JsonReader`,
`Currencies`, `isoDay`/`ymd`-style date text and `AccountingAmount`. It imports
nothing -- not the application, not Flutter, not a global such as the active tax
reference -- so the posting model and the export formats built on it can move
into packages of their own. The old paths in the application are one-line
re-exports (`export 'package:deskilo_money_kernel/...'`) until the sweep PR
deletes them; a lint pins that a shim only re-exports.

The accounting export prerequisites also live here: `euro_format` identifies
the currency of the euro-only file formats; `posting_fx` converts a supplied
posting at its held rate; `expense_repartition` holds and divides the supplied
shares; `number_sequence` represents the owner's saved series and its preview.
These types perform no repository read, membership lookup or number allocation.
Their existing consumers import this package directly.
