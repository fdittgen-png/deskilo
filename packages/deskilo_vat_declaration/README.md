# deskilo_vat_declaration

The VAT declaration model (#3405 of #3328): `VatDeclaration` and its lines, the
form definitions of every country and year (data), the filling of a form's
boxes (`fillVatForm`) and the XML export. It depends on the money kernel, the
tax-reference package and `xml`. Every function that reads the tax reference
takes a `TaxReferenceSet` as a required parameter: the installed snapshot
(`ActiveTaxReference`) is the application's global and cannot be named here (a
lint pins it). The application keeps thin wrappers, at the old paths, that pass
the global; they are the only code that reads it. The old paths otherwise
re-export until the sweep (#3403).
