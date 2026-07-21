// SPDX-License-Identifier: 0BSD
//
// #209: semantic snackbars. The three variants must float and carry their
// severity color (error = colorScheme.error, success = the #196 status
// token, info = theme default), and `replace: true` must keep the
// pre-#209 clearSnackBars semantics (newest message wins).
import 'package:deskilo/core/theme/status_colors.dart';
import 'package:deskilo/core/ui/app_snack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a minimal host whose button runs [show] with a live context.
Future<void> pumpHost(
  WidgetTester tester,
  void Function(BuildContext context) show, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => show(context),
            child: const Text('show'),
          ),
        ),
      ),
    ),
  );
}

Future<void> showAndSettle(WidgetTester tester) async {
  await tester.tap(find.text('show'));
  // Entry animation only — snackbars auto-dismiss later.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

SnackBar snackOf(WidgetTester tester) =>
    tester.widget<SnackBar>(find.byType(SnackBar));

Text contentTextOf(WidgetTester tester, String text) => tester.widget<Text>(
      find.descendant(of: find.byType(SnackBar), matching: find.text(text)),
    );

void main() {
  testWidgets('error: floating, error background, onError text',
      (tester) async {
    await pumpHost(tester, (context) => AppSnack.error(context, 'nope'));
    final scheme =
        Theme.of(tester.element(find.text('show'))).colorScheme;

    await showAndSettle(tester);

    final snack = snackOf(tester);
    expect(snack.behavior, SnackBarBehavior.floating);
    expect(snack.backgroundColor, scheme.error);
    expect(contentTextOf(tester, 'nope').style?.color, scheme.onError);
  });

  testWidgets('success: floating, light-theme status token and on-color',
      (tester) async {
    await pumpHost(tester, (context) => AppSnack.success(context, 'saved'));

    await showAndSettle(tester);

    final snack = snackOf(tester);
    expect(snack.behavior, SnackBarBehavior.floating);
    expect(snack.backgroundColor, AppStatusColors.success);
    expect(
      contentTextOf(tester, 'saved').style?.color,
      AppStatusColors.onSuccess,
    );
  });

  testWidgets('success: dark theme uses the dark tint and its on-color',
      (tester) async {
    await pumpHost(
      tester,
      (context) => AppSnack.success(context, 'saved'),
      brightness: Brightness.dark,
    );

    await showAndSettle(tester);

    expect(snackOf(tester).backgroundColor, AppStatusColors.successDark);
    expect(
      contentTextOf(tester, 'saved').style?.color,
      AppStatusColors.onSuccessDark,
    );
  });

  testWidgets('info: floating, theme-default look (no color override)',
      (tester) async {
    await pumpHost(tester, (context) => AppSnack.info(context, 'notice'));

    await showAndSettle(tester);

    final snack = snackOf(tester);
    expect(snack.behavior, SnackBarBehavior.floating);
    expect(snack.backgroundColor, isNull);
    expect(contentTextOf(tester, 'notice').style, isNull);
  });

  testWidgets('replace: true clears the queue — the newest message wins',
      (tester) async {
    await pumpHost(tester, (context) {
      AppSnack.info(context, 'first');
      AppSnack.info(context, 'second', replace: true);
    });

    await showAndSettle(tester);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
  });
}
