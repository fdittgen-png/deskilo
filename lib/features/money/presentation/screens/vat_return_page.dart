// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3616 (desk M3) — a VAT return as a long task (#3608) at its address,
// `/vat-declarations/<id>`: the form's boxes on the left, as the
// jurisdiction package lays them out and names them; on the right the
// documents of the box chosen, "documents of this period at this rate",
// under one line that compares them with the box (the decision on #3616):
// equal, nothing more; different, both figures and the difference in
// words. Every amount is in the return's currency. A box made of purchases,
// a category or a correction lists no sum it cannot hold, and says so.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart'
    show Invoice, VatTaxPointAmount;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/adaptive/long_task_page.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/vat_return_documents.dart';
import '../../providers/money_providers.dart';
import '../../providers/vat_declaration_providers.dart';

/// The return [declarationId] at its address.
class VatReturnPage extends ConsumerStatefulWidget {
  const VatReturnPage({super.key, required this.declarationId});

  final String declarationId;

  @override
  ConsumerState<VatReturnPage> createState() => _VatReturnPageState();
}

class _VatReturnPageState extends ConsumerState<VatReturnPage> {
  /// The box whose documents are shown.
  final ValueNotifier<String?> _chosen = ValueNotifier(null);

  @override
  void dispose() {
    _chosen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final read = ref.watch(vatReturnBoxesProvider(widget.declarationId));
    final found = read.value;
    final Widget body = switch (read) {
      AsyncError() => Center(child: Text(l.accountingStatusNotRead)),
      AsyncData(value: null) => Center(
        child: Text(
          l.searchRecordUnreadable,
          key: const ValueKey('vat-return-unreadable'),
        ),
      ),
      AsyncData(value: final r?) => _Boxes(
        boxes: r.boxes,
        chosen: _chosen,
        currency: r.declaration.currency,
      ),
      _ => const LoadingView(),
    };
    final money = appFormatOf(context).moneyIn(found?.declaration.currency);
    return LongTaskPage(
      title: l.vatDeclTitle,
      fallbackAddress: '/vat-declarations',
      form: body,
      summary: found == null
          ? null
          : ValueListenableBuilder(
              valueListenable: _chosen,
              builder: (context, code, _) => _Documents(
                box: found.boxes.where((b) => b.box.code == code).firstOrNull,
                money: money,
              ),
            ),
    );
  }
}

/// The form's boxes; a tap shows a box's documents.
class _Boxes extends StatelessWidget {
  const _Boxes({
    required this.boxes,
    required this.chosen,
    required this.currency,
  });

  final List<VatBoxDocuments> boxes;
  final ValueNotifier<String?> chosen;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final money = appFormatOf(context).moneyIn(currency);
    final beside = LongTaskLayout.maybeOf(context)?.summaryBeside ?? true;
    return ValueListenableBuilder(
      valueListenable: chosen,
      builder: (context, code, _) => ListView(
        key: const ValueKey('vat-return-boxes'),
        padding: AppSpacing.mdAll,
        children: [
          for (final b in boxes)
            ListTile(
              key: ValueKey('vat-return-box-${b.box.code}'),
              selected: b.box.code == code,
              title: Text(b.box.label),
              leading: Text(b.box.code),
              trailing: Text(money.formatMinor(b.declared)),
              onTap: () => chosen.value = b.box.code,
            ),
          // Below the expanded class the documents follow the boxes.
          if (!beside)
            _Documents(
              box: boxes.where((b) => b.box.code == code).firstOrNull,
              money: money,
            ),
        ],
      ),
    );
  }
}

/// The documents of [box], under the line comparing them with it.
class _Documents extends ConsumerWidget {
  const _Documents({required this.box, required this.money});

  final VatBoxDocuments? box;
  final MoneyFormat money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final b = box;
    if (b == null) {
      return Padding(
        padding: AppSpacing.mdAll,
        child: Text(l.vatReturnChooseBox),
      );
    }
    final invoices = {
      for (final i
          in ref.watch(invoicesProvider).value ??
              const <
                Invoice
              >[]) // empty-ok: a number is a label; an unread one is left blank
        i.id: i,
    };
    return Column(
      key: ValueKey('vat-return-documents-${b.box.code}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: AppSpacing.mdAll,
          child: Text(
            l.vatReturnDocumentsTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        // Equal says nothing more; a difference, or a box not added up
        // here, is said in one line.
        if (_comparison(l, b, money) case final line?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(line, key: const ValueKey('vat-return-comparison')),
          ),
        if (b.today != null)
          for (final p in b.documents)
            _document(context, p, invoices[p.invoiceId]),
      ],
    );
  }

  Widget _document(BuildContext context, VatTaxPointAmount p, Invoice? i) =>
      ListTile(
        key: ValueKey('vat-return-document-${p.invoiceId}-${p.percent}'),
        title: Text(i?.number ?? ''),
        subtitle: Text(i?.memberName ?? ''),
        trailing: Text(money.formatMinor(p.netCents)),
      );

  /// The one line under a box: what its documents say against it.
  static String? _comparison(
    AppLocalizations l,
    VatBoxDocuments b,
    MoneyFormat money,
  ) {
    final difference = b.difference;
    if (difference == null) return l.vatReturnNotCompared;
    if (difference == 0) return null;
    return l.vatReturnDocumentsDiffer(
      money.formatMinor(b.declared),
      money.formatMinor(b.documented!),
      money.formatMinor(difference.abs()),
      difference > 0 ? 'more' : 'less',
    );
  }
}
