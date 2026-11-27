// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4466 -- the Demo business's till board: the ideaspark board at the front counter, as its QR code reads (the board
// the firmware's host test pins).
import 'package:meta/meta.dart' show visibleForTesting;

import '../../../features/money/domain/device_code.dart';

/// The QR code the Demo's till board shows (the tests scan it).
@visibleForTesting
const demoTillBoardQr =
    'deskilo-device:v1?id=11111111-1111-4111-8111-111111111111&board=ideaspark_st7789_v1&fw=1.0.3&fp=AB12-CD34';

/// The Demo's till board, read from its QR code.
DeviceCode demoTillBoard() => switch (readDeviceCode(demoTillBoardQr)) {
  DeviceCodeOk(:final code) => code,
  DeviceCodeRefused(:final reason) => throw StateError('the Demo board QR is refused: $reason'),
};
