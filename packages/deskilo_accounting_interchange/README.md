# deskilo_accounting_interchange

The contract the accounting export formats are written against (#3376 of
#3328): `AccountingInterchangeV1` (what one fiscal period of an issuer's book
hands an accounting system), and the declaration a format makes about itself --
`AccountingFormat`, its `ExportKind` (the writer family) and `SourceRequirements`
(what it reads). It depends on `deskilo_money_kernel` and on nothing else; the
formats that follow (Sage 50, the Swiss journals, the generic journal, SAF-T)
depend on this package and the kernel only. The old paths in the application
are one-line re-exports until the sweep PR deletes them.
