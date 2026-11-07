# deskilo_jurisdiction_standards

The pure helpers that more than one country add-on shares (#3333 of #3328),
and that the application uses too: `csvCell`, `monthOrQuarter`, `ymd`/`hhmm`/
`twoDigits`, and the registration numbers a return checks and prints. A helper
lands here only when at least two countries use it; it is a neutral utility
package -- it knows no contract, no add-on and no application type. The
contract itself (`deskilo_jurisdiction_api`) exports contract types only.
