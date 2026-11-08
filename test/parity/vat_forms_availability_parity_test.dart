// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3330 (of #3328) -- the parity baseline of what a jurisdiction offers,
// captured before anything moves: the VAT form catalogue (form, layout date,
// every box with its label, file keys, rounding and flags -- the arithmetic
// of the boxes is pinned by `vat_form_boxes_golden`), which form a country
// files for a period, and which features ADR 0043 makes available in which
// country. Rewrite only with `UPDATE_PARITY_GOLDENS=1`, never under CI.
import 'package:deskilo/features/money/domain/vat_form_catalogue.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parity_golden.dart';

const _dir = 'test/parity/golden/forms_availability';

String _box(VatBoxSpec b) => [
  b.code,
  b.label,
  b.baseKey,
  b.taxKey,
  b.formBox ?? '-',
  b.baseRounding.name,
  b.taxRounding.name,
  if (b.always) 'always',
  if (b.clampAtZero) 'clampAtZero',
  if (b.absolute) 'absolute',
].join(' | ');

void main() {
  test('the form catalogue, the form a country files and the features by '
      'country are what they were', () {
    final catalogue = StringBuffer();
    for (final f in vatFormCatalogue) {
      catalogue.writeln('## ${f.country} | ${f.name} | ${isoDay(f.validFrom)}');
      for (final b in f.boxes) {
        catalogue.writeln(_box(b));
      }
    }

    final picked = StringBuffer();
    for (final country in [
      'DE',
      'FR',
      'GB',
      'UK',
      'CH',
      'CA',
      'ES',
      'IT',
      'US',
      '',
    ]) {
      for (final end in [
        DateTime(2023, 12, 31),
        DateTime(2024, 12, 31),
        DateTime(2026, 3, 31),
      ]) {
        final spec = vatFormSpecFor(country, end);
        picked.writeln(
          '${country.isEmpty ? '(none)' : country} | ${isoDay(end)} | '
          '${spec == null ? '-' : '${spec.country} ${spec.name} ${isoDay(spec.validFrom)}'}',
        );
      }
    }

    final countries = [
      'DE',
      'FR',
      'GB',
      'CH',
      'CA',
      'ES',
      'IT',
      'US',
      'BE',
      '',
    ];
    final availability = StringBuffer(
      'feature | availableIn | ${countries.map((c) => c.isEmpty ? '(none)' : c).join(' ')}\n',
    );
    for (final f in WorkspaceFeature.values) {
      final set = featureManifest[f]?.availableIn;
      availability.writeln(
        '${f.name} | ${set == null ? 'everywhere' : (set.toList()..sort()).join(',')} | '
        '${countries.map((c) => featureAvailableIn(set, c) ? 'y' : 'n').join(' ')}',
      );
    }

    expectParity(
      dir: _dir,
      text: {
        'catalogue.txt': catalogue.toString(),
        'form_by_country.txt': picked.toString(),
        'feature_availability.txt': availability.toString(),
      },
    );
  });
}
