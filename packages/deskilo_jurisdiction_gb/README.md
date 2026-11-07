# deskilo_jurisdiction_gb

The GB VAT filing add-on (#3333 of #3328), behind the contract of
`deskilo_jurisdiction_api`. It reads the context it is given -- the period, the
declarant, the form boxes the host filled from its tax reference, the facts and
the instant of generation -- and nothing else. The application's goldens
(`test/parity/`) pin the bytes.
