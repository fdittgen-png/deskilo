// SPDX-License-Identifier: 0BSD
import 'package:flutter/widgets.dart';

import '../domain/invoice.dart';
import '../domain/period_label.dart';

export '../domain/period_label.dart';

/// 'yyyy-MM' → the localized month name ('July 2026', 'juillet 2026').
/// Was copy-pasted in the archive and the hub; one home now — and since
/// #1061 the pure half lives in domain/period_label.dart.
String monthLabel(BuildContext context, String period) =>
    monthLabelOf(Localizations.maybeLocaleOf(context)?.toString(), period);

/// What an invoice COVERS, in words — see [invoicePeriodLabelOf].
String invoicePeriodLabel(BuildContext context, Invoice invoice) =>
    invoicePeriodLabelOf(
        Localizations.maybeLocaleOf(context)?.toString(), invoice);
