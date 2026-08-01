// SPDX-License-Identifier: 0BSD
//
// Platform-abstraction lint: `Platform.isX` belongs behind a `core/`
// seam, never inline in feature or app code.
//
// The app ships on five targets. A feature that branches on
// `Platform.isAndroid` in place makes the sixth call site the one that
// forgets a target — that is how the push connector and the file saver
// ended up as the ONLY places allowed to know what OS this is: each
// wraps the check once and degrades explicitly (`PushConnector` returns
// false off Android; `FileSaver` picks the right directory per OS).
// Feature code asks the seam, not the OS.
//
// `kIsWeb` stays permitted: it is a compile-time constant the tree-shaker
// understands, and guarding a camera or NFC call site with it is the
// documented pattern for the web target.

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  test('Platform.isX only inside core/ seams', () {
    final violations = scanLines(
      handWrittenDartFilesIn(['lib/features', 'lib/app']),
      (line) => line.contains('Platform.is'),
    );
    expect(
      violations,
      isEmpty,
      reason: 'Inline OS check outside core/:\n${violations.join('\n')}\n\n'
          'Wrap it in a core/ seam that degrades explicitly (see '
          'core/push/push_connector.dart, core/files/file_saver_io.dart) '
          'so every target is decided in one place.',
    );
  });
}
