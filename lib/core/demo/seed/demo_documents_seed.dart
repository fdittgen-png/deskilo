// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3964 — the documents of the reference business: the invoice template the
// owner saved (a letterhead with the business's name and address, the invoice
// lines with their amounts in euros, and a footer that quotes the owner's own
// thank-you text), the address window of the French envelope stock, the
// positioned layout of the usage statement, and the owner's texts. An issued
// Demo invoice prints with it; the Demo's documents stay in euros and in the
// language they were issued in.
import 'package:deskilo/features/money/domain/address_window.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/report_letter_layouts.dart';

import '../data/money_repository.dart';

/// The thank-you the footer quotes (`{{ text.thanks }}`).
const _thanks = 'Merci de votre confiance, Atelier du Marché.';

/// Saves the invoice template of the reference business.
void seedDemoInvoiceTemplate(FakeMoneyRepository money) {
  money.pdfTemplate = InvoicePdfTemplate(
    header: '# {{ workspace }}\n{{ workspace_address }}',
    body:
        '**{{ number }}** — {{ member }}\n'
        '{% for line in lines %}{{ line.label }} : {{ line.amount }}\n'
        '{% endfor %}Total : {{ total }}',
    footer: '{{ text.thanks }}',
    addressWindow: AddressWindow.right,
    layouts: {'usage': defaultLetterLayoutXml('usage', const LetterStrings())},
    texts: const {'thanks': _thanks},
  );
}
