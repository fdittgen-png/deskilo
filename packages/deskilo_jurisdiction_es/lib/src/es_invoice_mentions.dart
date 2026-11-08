// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- what Spanish law adds to an invoice: a correcting
// invoice says it is one and names the invoice it rectifies (RD 1619/2012
// art. 15), with the AEAT reason code (R1-R5). Moved from the invoice model,
// text unchanged.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of the lines this add-on states.
const esInvoiceMentionsImplementationVersion = '1';

/// The correction codes of RD 1619/2012 art. 15 (AEAT TipoFactura R1-R5), as
/// the mention words them.
const spanishCorrectionReasonCodes = ['R1', 'R2', 'R3', 'R4', 'R5'];

String _reasonText(String code) => switch (code.trim().toUpperCase()) {
  'R1' =>
    'R1, error fundado en derecho y causas del art. 80 uno, dos '
        'y seis de la Ley 37/1992',
  'R2' => 'R2, concurso de acreedores (art. 80 tres de la Ley 37/1992)',
  'R3' => 'R3, cr\u00e9ditos incobrables (art. 80 cuatro de la Ley 37/1992)',
  'R4' => 'R4, resto de causas',
  'R5' => 'R5, factura simplificada',
  _ => '',
};

/// The Spanish invoice mentions.
class EsInvoiceMentions extends InvoiceMentionsContribution {
  const EsInvoiceMentions();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'es.invoice_mentions',
    implementationVersion: esInvoiceMentionsImplementationVersion,
    contractVersion: invoiceMentionsContractVersion,
    formatVersion: 'rd-1619-2012-art-15',
    capabilityId: 'invoice_mentions.ES',
  );

  @override
  List<String> get correctionReasonCodes => spanishCorrectionReasonCodes;

  @override
  List<String> mentions(InvoiceMentionContext context) {
    if (!context.correction) return const [];
    final reason = _reasonText(context.correctionReason);
    final why = reason.isEmpty ? '.' : '. Motivo: $reason.';
    final rectifies = context.rectifies.trim();
    return [
      if (rectifies.isEmpty)
        'Factura rectificativa (art. 15 del RD 1619/2012)$why'
      else
        'Factura rectificativa (art. 15 del RD 1619/2012) de la factura '
            '$rectifies$why',
    ];
  }
}
