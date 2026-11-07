# deskilo_tax_reference

The data model of the tax reference (#3401 of #3328): `TaxReferenceSet`, its
rows and typed values (`TaxDomain`, `TaxValue`...), resolution by date, and the
pure questions asked of a set (`TaxReferenceQueries`). It imports the money
kernel and nothing else. The *installed* snapshot -- `ActiveTaxReference`, the
global the application installs at start-up -- is not here and cannot be named
here: a format that needs the reference is handed a set. The old paths in the
application are one-line re-exports until the sweep (#3403).
