// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Non-web half of the Web NFC seam (#604): every probe reports
// unsupported so `NfcUidReader` falls through to the nfc_manager path.

bool webNfcSupported() => false;

Future<bool> webNfcStartRead(void Function(String uid) onUid) async =>
    false;

Future<void> webNfcStop() async {}
