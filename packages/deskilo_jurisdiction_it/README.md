# deskilo_jurisdiction_it

The Italian VAT filing add-on (#3333 of #3328): the LIPE (Comunicazione
liquidazioni periodiche IVA) as the XML of the Agenzia delle Entrate's
fornitura IVP18, behind the contract of `deskilo_jurisdiction_api`. It reads the
context it is given -- the period, the declarant, the quadro VP boxes the host
filled from its tax reference and the facts -- and nothing else.
