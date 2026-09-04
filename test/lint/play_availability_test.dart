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
  final uploadWorkflow =
      File('.github/workflows/play-internal.yml').readAsStringSync();

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

  test('no inspecting mode needs a build — they read the store, they do '
      'not produce anything for it', () {
    expect(tool, contains('read_only = (args.status or args.set_countries'));
    expect(tool, contains('or args.move_testers is not None'));
    expect(tool, contains('or args.clear_track or args.drop_drafts)'));
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

  test('moving testers reads both sides, unions them, and never writes '
      'a group twice', () {
    expect(tool, contains('parser.add_argument("--move-testers"'));
    expect(tool, contains('if args.move_testers is not None:'));
    expect(tool, contains('_move_testers(edits'));
    expect(tool, contains('if group not in merged:'),
        reason: 'a group already testing the target must not be added twice');
    // An empty answer from this API means "no Google group", never "no
    // testers": Console e-mail lists are invisible to it, and saying so
    // is the difference between a fix and a silent no-op.
    expect(tool, contains('Console e-mail LIST'));
  });

  test('the report reads the TRACK\'s availability, not just the '
      'release\'s targeting', () {
    // The two are different resources, and reading the wrong one is why
    // a status said "countries=ALL" while a tester on that very track
    // could not find the app at all.
    expect(tool, contains('edits.countryavailability().get('));
    expect(tool, contains('NO COUNTRY'));
    expect(tool, contains('the TRACK is available in no country'));
    // And the store page itself: a closed test still renders one,
    // and without it the store answers "item not found" too.
    expect(tool, contains('edits.listings().list('));
    expect(tool, contains('there is no store page to show'));
  });

  test('the track is not restricted to the four well-known names', () {
    // Play names extra closed tracks itself (alpha1, alpha2, …) and a
    // workspace can add one at any time. A fixed choices list is how a
    // second closed track ends up holding testers and no build.
    expect(tool, isNot(contains(
        'choices=["internal", "alpha", "beta", "production"]')));
    expect(workflow, isNot(contains('--track internal --track')));
  });

  test('every commit is sent for review', () {
    // A commit that lands as "changes not sent for review" shows up in
    // the Console as a pending modification, reports success through the
    // API, and never reaches a device. Every upload this app made sat
    // there until somebody pressed the button by hand.
    final commits = 'edits.commit('.allMatches(tool).length;
    final reviewed =
        'changesNotSentForReview=False'.allMatches(tool).length;
    expect(reviewed, commits,
        reason: 'all $commits commits must send for review, $reviewed do');
  });

  test('retiring a track empties it and says what it cannot do', () {
    expect(tool, contains('parser.add_argument("--clear-track"'));
    expect(tool, contains('parser.add_argument("--drop-drafts"'));
    expect(tool, contains('_rewrite_track(edits'));
    // The API has no delete-track call and the tool must not pretend
    // otherwise: a retired track still exists, it just serves nobody.
    expect(tool, contains('only be suspended or deleted in the Console'));
  });

  test('alpha1 is retired: it can be read, never published to', () {
    // A second closed channel that held testers and no build. Its
    // testers were told they were testers and handed an empty store. It
    // is suspended in the Console; only Alpha is used.
    expect(tool, contains('RETIRED_TRACKS = {"alpha1"}'));
    expect(tool, contains('if not read_only and args.track in RETIRED_TRACKS'),
        reason: 'the refusal must gate PUBLISHING only — reads and '
            'cleanups must still be able to name a retired track, '
            'because noticing it come back is the point');
    expect(uploadWorkflow, isNot(contains('- alpha1')),
        reason: 'and it must not be offered as a track choice');
    // But the read/cleanup workflow MUST still be able to name it, or
    // the ban would also blind the report that would catch it coming
    // back, and there would be no way to empty it.
    expect(workflow, contains('alpha1'),
        reason: 'reads and cleanups must still reach a retired track');
  });

  test('the workflow reads by default and only writes when asked', () {
    expect(workflow, contains('--status'));
    expect(workflow, contains('--set-countries'));
    expect(workflow, contains(r'if: ${{ inputs.set_countries }}'),
        reason: 'writing must be gated on the input, never unconditional');
    expect(workflow, contains(r"if: ${{ inputs.move_testers_from != '' }}"),
        reason: 'and so must moving testers');
    expect(workflow, contains('default: false'),
        reason: 'and it must be off unless somebody ticks it');
    expect(workflow, contains(r'rm -f "$PLAY_KEY_PATH"'),
        reason: 'the service-account key never survives the job');
  });
}
