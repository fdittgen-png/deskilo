# deskilo_invoice_model

The invoice model (#3402 of #3328): `Invoice` and its lines, the frozen legal
snapshot and clauses (`invoice_clauses`, `invoice_legal`), the VAT regimes,
rates and tax-point rules, and the place-of-supply decision. It depends on the
money kernel, the tax-reference package, the VAT declaration package and
`deskilo_jurisdiction_standards`. Every function that reads the tax reference
takes a `TaxReferenceSet` as a required parameter, and the tax-point engine
takes the day-of function (`dayOf`): the installed snapshot
(`ActiveTaxReference`) and the workspace clock are the application's and cannot
be named here (a lint pins it). The application keeps thin wrappers at the old
paths that pass them; they are the only code that reads the global (#3403
sweep: callers switch to WorkspaceContext, then the wrapper goes). The old
paths otherwise re-export until the sweep.

`invoice.freezed.dart` is generated inside this package; the generated-code
gate runs `build_runner` here too (#3421).
