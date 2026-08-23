// SPDX-License-Identifier: 0BSD
//
// Non-web half of the Web NFC seam (#604): every probe reports
// unsupported so `NfcUidReader` falls through to the nfc_manager path.

bool webNfcSupported() => false;

Future<bool> webNfcStartRead(void Function(String uid) onUid) async =>
    false;

Future<void> webNfcStop() async {}
