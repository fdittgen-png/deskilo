# deskilo_jurisdiction_pl

The Polish invoice add-on (#3429 of #3328): the KSeF FA(3) structured invoice
(`http://crd.gov.pl/wzor/2025/06/25/13775/`, schema version 1-0E) as an invoice
profile behind the contract of `deskilo_jurisdiction_api`. It renders from the
`InvoiceDocumentContext` the host hands it -- the figures, the parties, the
period, the EU codes of the workspace's tax reference -- and reads nothing else.
It moved here from the invoice model with its bytes unchanged.
