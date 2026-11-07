# deskilo_jurisdiction_fr

The French VAT filing add-on (#3332 of #3328): the CA3 as an EDI-TVA
interchange (`UNA/UNB/UNH ... UNT/UNZ`, message INFENT, syntax UNOC 3), written
behind the contract of `deskilo_jurisdiction_api`. It reads the context it is
given -- the period, the declarant, the form boxes the host filled from its tax
reference and the instant of generation -- and nothing else.

A change to the French file touches this package, its tests and the composition
metadata; the application's goldens (`test/parity/`) pin the bytes.
