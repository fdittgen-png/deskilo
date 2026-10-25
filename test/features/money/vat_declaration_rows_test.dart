// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — a saved VAT declaration's card, decided as a table: its stage,
// whether it can be marked filed, corrections and deductible VAT, the
// balance, the filing reference and the rate label.
import 'package:deskilo/features/money/application/vat_declaration_rows.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_clock.dart';

VatDeclarationLine _line({String direction = 'output', String corrects = ''}) =>
    VatDeclarationLine(
      percent: 20,
      grossCents: 1200,
      netCents: 1000,
      vatCents: 200,
      invoiceCount: 1,
      direction: direction,
      corrects: corrects,
    );

VatDeclaration _declaration({
  String status = 'draft',
  List<VatDeclarationLine> lines = const [],
  int totalVatCents = 200,
  String number = '',
  String channel = '',
  String receipt = '',
}) => VatDeclaration(
  id: 'd-1',
  workspaceId: 'ws-1',
  periodStart: kTestNow,
  periodEnd: kTestNow,
  status: status,
  lines: lines,
  totalNetCents: 1000,
  totalVatCents: totalVatCents,
  currency: 'EUR',
  invoiceCount: 1,
  createdAt: kTestNow,
  number: number,
  submittedChannel: channel,
  submittedReceipt: receipt,
);

void main() {
  final cases =
      <
        ({
          String name,
          VatDeclaration declaration,
          VatDeclarationStage stage,
          bool canMarkFiled,
          bool corrections,
          bool input,
          bool payable,
          int balance,
          String? filed,
        })
      >[
        (
          name: 'a draft of plain sales',
          declaration: _declaration(lines: [_line()]),
          stage: VatDeclarationStage.draft,
          canMarkFiled: false,
          corrections: false,
          input: false,
          payable: true,
          balance: 200,
          filed: null,
        ),
        (
          name: 'prepared, with deductible VAT claimed back',
          declaration: _declaration(
            status: 'prepared',
            lines: [
              _line(),
              _line(direction: 'input'),
            ],
            totalVatCents: -300,
          ),
          stage: VatDeclarationStage.prepared,
          canMarkFiled: true,
          corrections: false,
          input: true,
          payable: false,
          balance: 300,
          filed: null,
        ),
        (
          name: 'filed, with a correction and its reference',
          declaration: _declaration(
            status: 'filed',
            lines: [_line(corrects: 'd-0')],
            number: 'TVA-1',
            channel: 'impots.gouv',
            receipt: 'R-9',
          ),
          stage: VatDeclarationStage.filed,
          canMarkFiled: false,
          corrections: true,
          input: false,
          payable: true,
          balance: 200,
          filed: 'TVA-1 · impots.gouv · R-9',
        ),
        (
          name: 'submitted counts as filed; empty parts are left out',
          declaration: _declaration(status: 'submitted', channel: 'EDI'),
          stage: VatDeclarationStage.filed,
          canMarkFiled: false,
          corrections: false,
          input: false,
          payable: true,
          balance: 200,
          filed: 'EDI',
        ),
      ];
  for (final c in cases) {
    test(c.name, () {
      final row = VatDeclarationRows.of([c.declaration]).single;
      expect(row.stage, c.stage);
      expect(row.canMarkFiled, c.canMarkFiled);
      expect(row.hasCorrections, c.corrections);
      expect(row.hasInputVat, c.input);
      expect(row.payable, c.payable);
      expect(row.balanceCents, c.balance);
      expect(row.filedLine, c.filed);
    });
  }

  test('a line notes what it is only when it is input VAT or a correction', () {
    expect(VatDeclarationRow.hasNote(_line()), isFalse);
    expect(VatDeclarationRow.hasNote(_line(direction: 'input')), isTrue);
    expect(VatDeclarationRow.hasNote(_line(corrects: 'd-0')), isTrue);
  });

  test('the rate label drops the decimals of a whole rate', () {
    expect(VatDeclarationRow.percentLabel(20), '20 %');
    expect(VatDeclarationRow.percentLabel(5.5), '5.5 %');
  });
}
