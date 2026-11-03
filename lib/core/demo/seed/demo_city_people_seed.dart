// SPDX-License-Identifier: AGPL-3.0-or-later
// Invented names; email addresses remain under example.test.
const _first = [
  'Avery',
  'Blair',
  'Casey',
  'Devon',
  'Ellis',
  'Finley',
  'Harper',
  'Indigo',
  'Jules',
  'Kai',
  'Lane',
  'Morgan',
  'Noel',
  'Oakley',
  'Parker',
  'Quinn',
  'Reese',
  'Sasha',
  'Taylor',
  'Val',
];
const _last = ['Ashford', 'Bellamy', 'Cedar', 'Dale', 'Ellery', 'Fairwood'];

String demoCityPersonName(int index) =>
    '${_first[index % _first.length]} ${_last[index ~/ _first.length]}';
