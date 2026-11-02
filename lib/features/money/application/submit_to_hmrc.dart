// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — submitting a prepared UK VAT return to HMRC: ONE command, whose
// nine boxes are the ones the bridging CSV writes (`mtd_boxes.dart`), so the
// file and the submission cannot disagree. The server recomputes them from the
// prepared return and refuses any difference.
import '../domain/hmrc_submission.dart';
import '../domain/mtd_boxes.dart';
import '../domain/vat_declaration.dart';

class SubmitToHmrc {
  const SubmitToHmrc(this._repository);

  final HmrcRepository _repository;

  Future<HmrcOutcome> call({
    required VatDeclaration declaration,
    required HmrcConnection connection,
    required HmrcClientValues client,
  }) => _repository.submit(
    declarationId: declaration.id,
    connectionId: connection.id,
    boxes: mtdBoxPounds(declaration),
    client: client,
  );
}
