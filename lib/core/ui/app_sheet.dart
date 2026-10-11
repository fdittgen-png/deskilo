// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

/// The one way the app opens a bottom sheet (#2388).
///
/// Every sheet goes through here, so a decision about sheets — a drag
/// handle, a maximum width on a desktop window, the safe area, the
/// keyboard — is taken once instead of in each of the hundred callers. The
/// parameters and their defaults are `showModalBottomSheet`'s, so moving a
/// caller here changes nothing it shows; the body of a form sheet is a
/// `SheetShell` (form_sheet.dart), which scrolls and clears the keyboard
/// and the system bar.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool? showDragHandle,
  bool useSafeArea = false,
  BoxConstraints? constraints,
  AnimationStyle? sheetAnimationStyle,
}) => showModalBottomSheet<T>(
  context: context,
  builder: builder,
  isScrollControlled: isScrollControlled,
  showDragHandle: showDragHandle,
  useSafeArea: useSafeArea,
  constraints: constraints,
  sheetAnimationStyle: sheetAnimationStyle,
);
