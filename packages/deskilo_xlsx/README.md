# deskilo_xlsx

The minimal XLSX writer of the application (#395, #2861), moved out of
`lib/core/files` so the country add-ons that write a spreadsheet register
(#3429) and the application's exports share one copy. A workbook is a ZIP of
XML parts; strings go in inline, numbers as number cells, dates as real dates.
