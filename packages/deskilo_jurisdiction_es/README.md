# deskilo_jurisdiction_es

The Spanish VAT filing add-on (#3333 of #3328): the Modelo 303 in the AEAT's
"diseño de registro" (pages 01 and 03), behind the contract of
`deskilo_jurisdiction_api`. It reads the context it is given -- the period, the
declarant, the facts, the form boxes the host filled from its tax reference and
the instant of generation -- and nothing else. The layout tables are exported so
the application can read the AEAT's own design row by row against them.
