// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2079 — the names of the regions the holiday source lists.
//
// Nager.Date names a regional holiday by its ISO 3166-2 subdivision code
// ("DE-BY"). An owner picks a region by its name, so this is the checked-in
// table of every code the source returns for AT, CH, DE, ES, GB, IT, PT, US
// and CA (collected from the 2026 and 2027 calendars; a test pins the
// fixture against this table). Names are the official or native ones:
// Bayern, Genève, Catalunya, Québec. A code the table does not know is
// shown as the code itself.
//
// Pure Dart: no Flutter, no l10n.
library;

/// ISO 3166-2 code → region name.
const holidayRegionNames = <String, String>{
  // Austria
  'AT-1': 'Burgenland',
  'AT-2': 'Kärnten',
  'AT-3': 'Niederösterreich',
  'AT-4': 'Oberösterreich',
  'AT-5': 'Salzburg',
  'AT-6': 'Steiermark',
  'AT-7': 'Tirol',
  'AT-8': 'Vorarlberg',
  'AT-9': 'Wien',
  // Canada
  'CA-AB': 'Alberta',
  'CA-BC': 'British Columbia',
  'CA-MB': 'Manitoba',
  'CA-NB': 'New Brunswick',
  'CA-NL': 'Newfoundland and Labrador',
  'CA-NS': 'Nova Scotia',
  'CA-NT': 'Northwest Territories',
  'CA-NU': 'Nunavut',
  'CA-ON': 'Ontario',
  'CA-PE': 'Prince Edward Island',
  'CA-QC': 'Québec',
  'CA-SK': 'Saskatchewan',
  'CA-YT': 'Yukon',
  // Switzerland
  'CH-AG': 'Aargau',
  'CH-AI': 'Appenzell Innerrhoden',
  'CH-AR': 'Appenzell Ausserrhoden',
  'CH-BE': 'Bern',
  'CH-BL': 'Basel-Landschaft',
  'CH-BS': 'Basel-Stadt',
  'CH-FR': 'Fribourg',
  'CH-GE': 'Genève',
  'CH-GL': 'Glarus',
  'CH-GR': 'Graubünden',
  'CH-JU': 'Jura',
  'CH-LU': 'Luzern',
  'CH-NE': 'Neuchâtel',
  'CH-NW': 'Nidwalden',
  'CH-OW': 'Obwalden',
  'CH-SG': 'St. Gallen',
  'CH-SH': 'Schaffhausen',
  'CH-SO': 'Solothurn',
  'CH-SZ': 'Schwyz',
  'CH-TG': 'Thurgau',
  'CH-TI': 'Ticino',
  'CH-UR': 'Uri',
  'CH-VD': 'Vaud',
  'CH-VS': 'Valais',
  'CH-ZG': 'Zug',
  'CH-ZH': 'Zürich',
  // Germany
  'DE-BB': 'Brandenburg',
  'DE-BE': 'Berlin',
  'DE-BW': 'Baden-Württemberg',
  'DE-BY': 'Bayern',
  'DE-HB': 'Bremen',
  'DE-HE': 'Hessen',
  'DE-HH': 'Hamburg',
  'DE-MV': 'Mecklenburg-Vorpommern',
  'DE-NI': 'Niedersachsen',
  'DE-NW': 'Nordrhein-Westfalen',
  'DE-RP': 'Rheinland-Pfalz',
  'DE-SH': 'Schleswig-Holstein',
  'DE-SL': 'Saarland',
  'DE-SN': 'Sachsen',
  'DE-ST': 'Sachsen-Anhalt',
  'DE-TH': 'Thüringen',
  // Spain
  'ES-AN': 'Andalucía',
  'ES-AR': 'Aragón',
  'ES-AS': 'Asturias',
  'ES-CB': 'Cantabria',
  'ES-CL': 'Castilla y León',
  'ES-CM': 'Castilla-La Mancha',
  'ES-CN': 'Canarias',
  'ES-CT': 'Catalunya',
  'ES-EX': 'Extremadura',
  'ES-GA': 'Galicia',
  'ES-IB': 'Illes Balears',
  'ES-MC': 'Región de Murcia',
  'ES-MD': 'Comunidad de Madrid',
  'ES-NC': 'Navarra',
  'ES-PV': 'Euskadi',
  'ES-RI': 'La Rioja',
  'ES-VC': 'Comunitat Valenciana',
  // United Kingdom
  'GB-ENG': 'England',
  'GB-NIR': 'Northern Ireland',
  'GB-SCT': 'Scotland',
  'GB-WLS': 'Wales',
  // Italy
  'IT-32': 'Trentino-Alto Adige / Südtirol',
  // Portugal
  'PT-20': 'Açores',
  'PT-30': 'Madeira',
  // United States
  'US-AK': 'Alaska',
  'US-AL': 'Alabama',
  'US-AZ': 'Arizona',
  'US-CA': 'California',
  'US-CO': 'Colorado',
  'US-CT': 'Connecticut',
  'US-DE': 'Delaware',
  'US-GA': 'Georgia',
  'US-HI': 'Hawaii',
  'US-IA': 'Iowa',
  'US-ID': 'Idaho',
  'US-IL': 'Illinois',
  'US-IN': 'Indiana',
  'US-KS': 'Kansas',
  'US-KY': 'Kentucky',
  'US-LA': 'Louisiana',
  'US-MA': 'Massachusetts',
  'US-MD': 'Maryland',
  'US-ME': 'Maine',
  'US-MI': 'Michigan',
  'US-MN': 'Minnesota',
  'US-MO': 'Missouri',
  'US-MS': 'Mississippi',
  'US-MT': 'Montana',
  'US-NC': 'North Carolina',
  'US-ND': 'North Dakota',
  'US-NE': 'Nebraska',
  'US-NH': 'New Hampshire',
  'US-NJ': 'New Jersey',
  'US-NM': 'New Mexico',
  'US-NY': 'New York',
  'US-OH': 'Ohio',
  'US-OK': 'Oklahoma',
  'US-OR': 'Oregon',
  'US-PA': 'Pennsylvania',
  'US-RI': 'Rhode Island',
  'US-SC': 'South Carolina',
  'US-SD': 'South Dakota',
  'US-TN': 'Tennessee',
  'US-TX': 'Texas',
  'US-UT': 'Utah',
  'US-VA': 'Virginia',
  'US-VT': 'Vermont',
  'US-WI': 'Wisconsin',
  'US-WV': 'West Virginia',
};

/// The name of [code], or [code] itself when the table does not know it.
String holidayRegionName(String code) => holidayRegionNames[code] ?? code;

const _folds = {
  'ä': 'a', 'ö': 'o', 'ü': 'u', 'é': 'e', 'è': 'e', 'á': 'a', 'í': 'i',
  'ó': 'o', 'ç': 'c', 'ñ': 'n', 'ô': 'o', 'à': 'a', 'ê': 'e', //
};

String _sortKey(String name) {
  final lower = name.toLowerCase();
  final b = StringBuffer();
  for (final r in lower.runes) {
    final c = String.fromCharCode(r);
    b.write(_folds[c] ?? c);
  }
  return b.toString();
}

/// [codes] ordered by their region name (accents and case ignored), the
/// code breaking a tie. A code without a name sorts by the code.
List<String> sortHolidayRegions(Iterable<String> codes) {
  final list = codes.toSet().toList();
  list.sort((a, b) {
    final byName = _sortKey(holidayRegionName(a))
        .compareTo(_sortKey(holidayRegionName(b)));
    return byName != 0 ? byName : a.compareTo(b);
  });
  return list;
}
