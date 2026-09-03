// SPDX-License-Identifier: 0BSD
//
// The Play availability tool and the workflow that drives it live in two
// files that nothing else keeps in step, and both were written to answer
// one question: why a tester who IS on the list still gets "item not
// found". A flag that silently stops existing turns that answer into
// `unrecognized arguments` on a runner, minutes after someone asked.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The markets DesKilo is offered in: the EU 27, then the four named
/// non-EU ones. Written out here so a change to the tool's list has to
/// be a change to this list too.
const _eu27 = [
  'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE',
  'GR', 'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 'PT',
  'RO', 'SK', 'SI', 'ES', 'SE',
];
const _nonEu = ['US', 'CA', 'JP', 'KR'];

void main() {
  final tool = File('tools/upload_to_play.py').readAsStringSync();
  final workflow =
      File('.github/workflows/play-availability.yml').readAsStringSync();

  test('both modes are real flags, not just functions nobody can reach', () {
    // The failure this guards against is not hypothetical: the wiring
    // was written twice and silently landed neither time, because a
    // no-op text replacement looks exactly like a successful one.
    for (final flag in ['--status', '--set-countries']) {
      expect(tool, contains('parser.add_argument("$flag"'),
          reason: '$flag must be declared on the parser');
    }
    expect(tool, contains('if args.status:'));
    expect(tool, contains('if args.set_countries is not None:'));
    expect(tool, contains('_report_status(edits'));
    expect(tool, contains('_set_countries(edits'));
  });

  test('neither mode needs a build — they inspect the store, they do not '
      'produce anything for it', () {
    expect(tool, contains('read_only = args.status or args.set_countries'));
    expect(tool, contains('if not read_only and not aab.is_file():'),
        reason: 'the AAB guard must not fire for a read-only run');
  });

  test('the markets are the EU 27 plus the four named ones, and the rest '
      'of the world is excluded on purpose', () {
    for (final country in [..._eu27, ..._nonEu]) {
      expect(tool, contains('"$country"'), reason: country);
    }
    expect(tool, contains('DEFAULT_COUNTRIES = EU_27 + ["US", "CA", "JP", "KR"]'));
    expect(tool, contains('"includeRestOfWorld": False'),
        reason: 'a market list that quietly includes everywhere is not one');
    // 27 + 4, counted from the source rather than trusted.
    final block = RegExp(r'EU_27 = \[(.*?)\]', dotAll: true)
        .firstMatch(tool)!
        .group(1)!;
    expect(RegExp('"[A-Z]{2}"').allMatches(block).length, 27);
  });

  test('setting the markets carries the live release over instead of '
      'replacing it', () {
    // The API has no "set the track's countries" call: availability is a
    // property of the RELEASE. Re-sending a release without its version
    // codes would roll back whatever is live.
    expect(tool, contains('edits.tracks().get('),
        reason: 'the current release has to be read before it is re-sent');
    expect(tool, contains('updated = dict(target)'));
  });

  test('the workflow reads by default and only writes when asked', () {
    expect(workflow, contains('--status'));
    expect(workflow, contains('--set-countries'));
    expect(workflow, contains(r'if: ${{ inputs.set_countries }}'),
        reason: 'writing must be gated on the input, never unconditional');
    expect(workflow, contains('default: false'),
        reason: 'and it must be off unless somebody ticks it');
    expect(workflow, contains(r'rm -f "$PLAY_KEY_PATH"'),
        reason: 'the service-account key never survives the job');
  });
}
