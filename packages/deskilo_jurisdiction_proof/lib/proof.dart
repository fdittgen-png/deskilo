/// PROOF #3329: a tax literal in a jurisdiction package must fail the guard.
const standardRates = {'FR': 20, 'DE': 19};
String label(int n) => switch ('FR') { 'FR' => 'vat 20%', _ => '$n' };
