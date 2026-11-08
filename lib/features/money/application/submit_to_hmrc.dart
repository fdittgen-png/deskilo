// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — submitting a prepared UK VAT return to HMRC: ONE command, whose
// nine boxes are the ones the bridging CSV writes (`mtd_boxes.dart`), so the
// file and the submission cannot disagree. The server recomputes them from the
// prepared return and refuses any difference.
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart' show TaxReferenceSet;
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';

import '../domain/hmrc_submission.dart';
import '../domain/mtd_boxes.dart';

class SubmitToHmrc {
  const SubmitToHmrc(this._repository);

  final HmrcRepository _repository;

  Future<HmrcOutcome> call({
    required VatDeclaration declaration,
    required HmrcConnection connection,
    required HmrcClientValues client,
    required TaxReferenceSet reference,
    String? recoveryMarker,
  }) => _repository.submit(
    declarationId: declaration.id,
    connectionId: connection.id,
    boxes: mtdBoxPounds(declaration, reference: reference),
    client: client,
    recoveryMarker: recoveryMarker,
  );
}
