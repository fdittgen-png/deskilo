// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/money_face.dart';

part 'money_face_controller.g.dart';

/// Which face of the Finances tab is showing (#720). Kept alive so a
/// deep link (the calendar hub landing on a payment, an invoice row)
/// can pick the face before the screen is built, and so the tab
/// survives leaving and returning — the same idiom as the inbox tab.
@Riverpod(keepAlive: true)
class MoneyFaceController extends _$MoneyFaceController {
  @override
  MoneyFace build() => MoneyFace.statement;

  void show(MoneyFace face) => state = face;
}
