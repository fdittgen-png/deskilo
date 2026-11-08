// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the records-location notice of a space (Canada: ETA
// s.286 / ITA s.230 and the CRA authorisation; Germany: § 146 Abs. 2a/2b AO),
// pinned BEFORE the rule moves into the Canadian and German add-ons: for every
// issuer country of interest crossed with every hosting case, whether each
// notice applies and the exact lines the archive README states. The goldens
// are written by the code as it stands and compared byte for byte; the move
// must change none of them. Rewrite only with `UPDATE_PARITY_GOLDENS=1`,
// never under CI.
import 'package:deskilo/features/money/domain/records_location.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parity_golden.dart';

/// The hosting cases: declared nothing, Canada, an EU state (DE, FR), and
/// countries outside the EU (US, GB).
const _hostings = <String?>[null, 'CA', 'DE', 'FR', 'US', 'GB'];

/// EU membership as the tax reference answers it for these cases.
bool _eu(String? c) => const {'DE', 'FR'}.contains(c);

String _page(String issuer) {
  final out = StringBuffer();
  for (final h in _hostings) {
    for (final cra in ['', 'CRA-12345']) {
      final loc = RecordsLocation(
        issuerCountry: issuer,
        hostingCountry: h,
        craReference: cra,
        hostingInEu: _eu(h),
      );
      out.writeln(
        'hosting=${h ?? '-'} cra=${cra.isEmpty ? '-' : cra} '
        'craNotice=${loc.craNotice} aoNotice=${loc.aoNotice}',
      );
      for (final l in loc.archiveLines) {
        out.writeln('  $l');
      }
    }
  }
  return out.toString();
}

void main() {
  test('the records-location notices are what they were before the move', () {
    expectParity(
      dir: 'test/parity/golden/records_location',
      text: {
        for (final issuer in ['CA', 'DE', 'FR', 'GB', 'ES', 'IT', 'CH', ''])
          '${issuer.isEmpty ? 'none' : issuer.toLowerCase()}.txt': _page(
            issuer,
          ),
      },
    );
  });
}
