# deskilo_jurisdiction_ch

The Swiss VAT filing add-on (#3333 of #3328): the MWST-Abrechnung as eCH-0217
version 2.0 XML, the file the ESTV ePortal takes for upload, behind the contract
of `deskilo_jurisdiction_api`. It reads the context it is given -- the period,
the declarant, the return's lines and the instant of generation -- and nothing
else. The XSD validation of its samples stays with `tool/vat_filing/validate.sh`.
