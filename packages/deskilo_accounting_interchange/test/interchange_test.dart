// SPDX-License-Identifier: AGPL-3.0-or-later
// #3376 -- the contract stands on the kernel alone: a format declares its
// writer family and what it reads, and the envelope refuses what is unfit to
// write. The detailed envelope and registry tests stay in the application.
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:test/test.dart';

void main() {
  test('a format declares its family, its claim and what it reads', () {
    const format = AccountingFormat(
      id: 'x',
      claim: FormatClaim.exchange,
      extension: 'csv',
      kind: ExportKind.genericJournal,
      sources: SourceRequirements.postedOnly,
    );
    expect(format.kind, ExportKind.genericJournal);
    expect(format.sources, SourceRequirements.postedOnly);
    expect(format.needsAccounts, isFalse);
  });
}
