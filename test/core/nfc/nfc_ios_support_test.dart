// SPDX-License-Identifier: 0BSD
//
// #657 — an iPhone reads NFC tags, and the tag-configuration forms must
// let it. The reader used to answer `unsupported` for every non-Android
// platform:
//
//     if (defaultTargetPlatform != TargetPlatform.android) {
//       return NfcStatus.unsupported;
//     }
//
// which hid the "Read a tag now" button on iOS, leaving an owner to type
// a hex UID by hand off a chair sticker — the exact thing the feature
// exists to avoid.
//
// The reasoning in the old comment conflated two flows: a WALL KIOSK
// polling all day (which really would want careful thought about Core
// NFC session lifetime) and an OWNER holding their phone to a chair for
// one foreground scan. Only the second is what these forms do.
//
// iPads have no NFC hardware — `checkAvailability()` says so, so they
// still hide the tap path without us hard-coding a platform.
import 'dart:io';

import 'package:deskilo/core/nfc/nfc_uid_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the reader no longer excludes iOS by platform', () {
    late String source;

    setUpAll(() {
      source = File('lib/core/nfc/nfc_uid_reader.dart').readAsStringSync();
    });

    test('the platform guard admits iOS as well as Android', () {
      expect(
        source,
        contains('defaultTargetPlatform != TargetPlatform.android &&\n'
            '        defaultTargetPlatform != TargetPlatform.iOS'),
        reason: 'both platforms fall through to checkAvailability(), which '
            'is what distinguishes an iPhone from an iPad',
      );
    });

    test('the UID is read from the iOS tag technologies too', () {
      // Core NFC splits the identifier per protocol; Android hands back
      // one id for all of them. A chair tag is normally MiFare
      // (NTAG/Ultralight) or ISO 15693.
      for (final tech in [
        'MiFareIos',
        'Iso15693Ios',
        'Iso7816Ios',
        'FeliCaIos',
      ]) {
        expect(source, contains(tech),
            reason: 'an unread tag technology is indistinguishable from a '
                'broken reader to whoever is holding the phone');
      }
      expect(source, contains('NfcTagAndroid.from(tag)?.id'),
          reason: 'the Android path must keep working unchanged');
    });
  });

  group('the iOS build carries what Core NFC requires', () {
    test('the entitlement requests TAG format', () {
      final entitlements =
          File('ios/Runner/Runner.entitlements').readAsStringSync();
      expect(
        entitlements,
        contains('com.apple.developer.nfc.readersession.formats'),
        reason: 'without the entitlement Core NFC refuses to start a '
            'session at all',
      );
      expect(entitlements, contains('<string>TAG</string>'),
          reason: 'NDEF format does not expose the tag identifier, and the '
              'identifier IS the badge credential the server stores');
    });

    test('every Runner build configuration points at it', () {
      final pbxproj =
          File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      final refs = RegExp(
        r'CODE_SIGN_ENTITLEMENTS = Runner/Runner\.entitlements;',
      ).allMatches(pbxproj).length;
      expect(refs, 3,
          reason: 'Debug, Release and Profile — a missing one signs a build '
              'without the entitlement, and the failure only shows up on a '
              'device, at the chair, with no error');
    });

    test('Info.plist explains the scan to the user', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('NFCReaderUsageDescription'),
          reason: 'iOS terminates the app if the usage string is missing '
              'when a reader session starts');
    });
  });

  group('normalizeUid is the shared badge-credential contract', () {
    test('lowercase hex, no separators, zero-padded', () {
      expect(
        NfcUidReader.normalizeUid(Uint8List.fromList([0x04, 0xa2, 0x0f, 0x00])),
        '04a20f00',
        reason: 'mirrors register_nfc_badge server-side normalization, so a '
            'tag read on an iPhone must produce the same string as the '
            'same tag read on Android',
      );
    });
  });
}
