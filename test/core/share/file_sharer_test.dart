// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The share seam reports what the system sheet reported and nothing more:
// a pick is `sent`, a closed sheet `dismissed`, a platform that cannot say
// `unknown` — and a sheet that could not open is an error the caller sees,
// never a silent `sent`. The bytes, name and type handed over are exactly
// the document's; no token or URL travels with them.
import 'package:deskilo/core/share/file_sharer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

/// The platform half of share_plus, answering what a test decides.
class _FakeSharePlatform extends SharePlatform {
  ShareResultStatus status = ShareResultStatus.success;
  Exception? refusal;
  final calls = <ShareParams>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    calls.add(params);
    if (refusal case final error?) throw error;
    return ShareResult('raw', status);
  }
}

void main() {
  // `SharePlus.instance` binds the platform once, on first use: one fake
  // for the whole file, steered per test.
  final platform = _FakeSharePlatform();
  late ProviderContainer container;

  setUpAll(() => SharePlatform.instance = platform);

  setUp(() {
    platform
      ..calls.clear()
      ..refusal = null
      ..status = ShareResultStatus.success;
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<FileShareOutcome> share({String? text}) =>
      container.read(fileSharerProvider)(
        bytes: Uint8List.fromList([37, 80, 68, 70]),
        fileName: 'inv-2026-0001.pdf',
        mimeType: 'application/pdf',
        text: text,
      );

  test('the document itself reaches the sheet: bytes, type, text', () async {
    final outcome = await share(text: 'Your invoice');
    expect(outcome, FileShareOutcome.sent);
    final params = platform.calls.single;
    final file = params.files!.single;
    // cross_file's io XFile derives `name` from a path a data file does not
    // have; the name reaches the platform in the bytes' XFile all the same.
    expect(file.mimeType, 'application/pdf');
    expect(await file.readAsBytes(), [37, 80, 68, 70]);
    expect(params.text, 'Your invoice');
    expect(params.uri, isNull, reason: 'no link travels beside the bytes');
  });

  test('a closed sheet is dismissed, a mute platform is unknown', () async {
    platform.status = ShareResultStatus.dismissed;
    expect(await share(), FileShareOutcome.dismissed);
    platform.status = ShareResultStatus.unavailable;
    expect(await share(), FileShareOutcome.unknown);
  });

  test(
    'a sheet that cannot open is the caller\'s error, never a sent',
    () async {
      platform.refusal = PlatformException(
        code: 'no_activity',
        message: 'nothing to share to',
      );
      await expectLater(share(), throwsA(isA<PlatformException>()));
    },
  );
}
