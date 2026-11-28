// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4518 -- the contacts of a supplier and what was agreed with it: each contact with its role, its e-mail and its phone, one of them the
// preferred purchasing contact a new order is addressed to; the currency its orders are placed in, the days its bills are due, the days its
// orders take. A contact is added, changed, retired and brought back; the old contact text of the supplier can be made the first contact.
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/currency_field.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/supplier_contact_commands.dart';
import '../../domain/supplier_contact.dart';
import '../../providers/supplier_contact_providers.dart';
import '../supplier_contact_names.dart';

/// What a refusal says.
String supplierContactProblemText(AppLocalizations l10n, SupplierContactProblem problem) => switch (problem) {
  SupplierContactProblem.nameTaken => l10n.supplierContactRoleNameTaken,
  SupplierContactProblem.nameRequired => l10n.supplierContactNameRequired,
  SupplierContactProblem.emailInvalid => l10n.supplierContactEmailInvalid,
  SupplierContactProblem.preferredNeedsEmail => l10n.supplierContactPreferredNeedsEmail,
  SupplierContactProblem.termsInvalid => l10n.supplierTermsInvalid,
  SupplierContactProblem.failed => l10n.supplierContactSaveFailed,
};

/// Opens the contacts and the terms of [supplier].
Future<void> showSupplierContactsDialog(BuildContext context, String workspaceId, Supplier supplier) => showDialog<void>(
  context: context,
  builder: (_) => _SupplierContactsDialog(workspaceId: workspaceId, supplier: supplier),
);

class _SupplierContactsDialog extends ConsumerWidget {
  const _SupplierContactsDialog({required this.workspaceId, required this.supplier});

  final String workspaceId;
  final Supplier supplier;

  SupplierKey get _key => (workspaceId: workspaceId, supplierId: supplier.id);

  Future<void> _done(BuildContext context, WidgetRef ref, SupplierContactProblem? problem) async {
    ref
      ..invalidate(supplierContactsProvider(_key))
      ..invalidate(supplierTermsProvider(_key));
    if (problem != null && context.mounted) AppSnack.error(context, supplierContactProblemText(context.l10n, problem));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, SupplierContact? contact, List<SupplierContactRole> roles) async {
    final l10n = context.l10n;
    final commands = ref.read(supplierContactCommandsProvider);
    final active = activeSupplierContactRoles(roles);
    final fields = FormControllers({
      'contactName': contact?.name ?? '',
      'contactEmail': contact?.email ?? '',
      'contactPhone': contact?.phone ?? '',
      'contactNote': contact?.note ?? '',
    });
    var roleId = contact?.roleId ?? active.firstOrNull?.id;
    var preferred = contact?.preferred ?? false;
    await showAppFormSheet(
      context,
      AppFormSheet(
        title: contact == null ? l10n.supplierContactAdd : l10n.supplierContactEditTitle,
        submitLabel: MaterialLocalizations.of(context).saveButtonLabel,
        submitKey: const ValueKey('supplier-contact-save'),
        onDispose: fields.dispose,
        validate: () => {
          if (fields.text('contactName').trim().isEmpty) 'contactName': l10n.supplierContactNameRequired,
        },
        onSubmit: () async {
          final role = roleId;
          if (role == null) return l10n.supplierContactSaveFailed;
          final problem = await commands.saveContact(
            workspaceId,
            id: contact?.id,
            supplierId: supplier.id,
            name: fields.text('contactName'),
            roleId: role,
            email: fields.text('contactEmail'),
            phone: fields.text('contactPhone'),
            note: fields.text('contactNote'),
            preferred: preferred,
          );
          ref.invalidate(supplierContactsProvider(_key));
          return problem == null ? null : supplierContactProblemText(l10n, problem);
        },
        builder: (context, refresh) => [
          AppTextField(
            key: const ValueKey('supplier-contact-name'),
            controller: fields['contactName'],
            fieldKey: 'contactName',
            label: l10n.supplierContactName,
            autofocus: true,
          ),
          const FormGap(),
          DropdownButtonFormField<String>(
            key: const ValueKey('supplier-contact-role'),
            isExpanded: true,
            initialValue: roleId,
            decoration: InputDecoration(labelText: l10n.supplierContactRole),
            items: [
              for (final r in roles)
                if (!r.retired || r.id == contact?.roleId) DropdownMenuItem(value: r.id, child: Text(supplierContactRoleName(l10n, r))),
            ],
            onChanged: (v) {
              roleId = v ?? roleId;
              refresh();
            },
          ),
          const FormGap(),
          AppTextField(
            key: const ValueKey('supplier-contact-email'),
            controller: fields['contactEmail'],
            fieldKey: 'contactEmail',
            label: l10n.supplierContactEmail,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          const FormGap(),
          AppTextField(
            key: const ValueKey('supplier-contact-phone'),
            controller: fields['contactPhone'],
            fieldKey: 'contactPhone',
            label: l10n.supplierContactPhone,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
          ),
          const FormGap(),
          AppTextField(key: const ValueKey('supplier-contact-note'), controller: fields['contactNote'], fieldKey: 'contactNote', label: l10n.supplierContactNote),
          SwitchListTile(
            key: const ValueKey('supplier-contact-preferred'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.supplierContactPreferred),
            value: preferred,
            onChanged: contact?.retired ?? false
                ? null
                : (v) {
                    preferred = v;
                    refresh();
                  },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final commands = ref.read(supplierContactCommandsProvider);
    final roles = ref.watch(supplierContactRolesProvider(workspaceId)).value ?? const <SupplierContactRole>[]; // empty-ok: the roles only name a contact; none leaves a contact unnamed
    String roleName(String id) => roles.where((r) => r.id == id).map((r) => supplierContactRoleName(l10n, r)).firstOrNull ?? '';
    return AlertDialog(
      key: const ValueKey('supplier-contacts-dialog'),
      title: Row(
        children: [
          Expanded(child: Text(l10n.supplierContactsTitle(supplier.name))),
          HelpDot(l10n.suppliersContacts, anchor: HelpAnchor.moneySupplierContacts),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AsyncReadBody<List<SupplierContact>>.part(
                value: ref.watch(supplierContactsProvider(_key)),
                onRetry: () => ref.invalidate(supplierContactsProvider(_key)),
                data: (contacts) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (contacts.isEmpty) Text(l10n.supplierContactsNone, key: const ValueKey('supplier-contacts-none')),
                    for (final c in contacts)
                      ListTile(
                        key: ValueKey('supplier-contact-${c.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(c.preferred ? Icons.star : Icons.person_outline),
                        title: Text(c.name),
                        subtitle: Text([
                          roleName(c.roleId),
                          if (c.email.isNotEmpty) c.email,
                          if (c.phone.isNotEmpty) c.phone,
                          if (c.preferred) l10n.supplierContactPreferredMark,
                          if (c.retired) l10n.supplierContactRetiredMark,
                        ].where((p) => p.isNotEmpty).join(' · ')),
                        onTap: () => _edit(context, ref, c, roles),
                        trailing: TextButton(
                          key: ValueKey('supplier-contact-retire-${c.id}'),
                          onPressed: () async {
                            final problem = await commands.setContactRetired(workspaceId, c.id, retired: !c.retired);
                            if (context.mounted) await _done(context, ref, problem);
                          },
                          child: Text(c.retired ? l10n.supplierContactRestore : l10n.supplierContactRetire),
                        ),
                      ),
                    if (contacts.isEmpty && supplier.contact.trim().isNotEmpty && roles.isNotEmpty)
                      TextButton(
                        key: const ValueKey('supplier-contact-from-text'),
                        onPressed: () async {
                          final role = roles.where((r) => r.code == BuiltInContactRole.other).firstOrNull ?? activeSupplierContactRoles(roles).first;
                          final text = supplier.contact.trim();
                          final problem = await commands.saveContact(
                            workspaceId,
                            supplierId: supplier.id,
                            name: text.length > 120 ? text.substring(0, 120) : text,
                            roleId: role.id,
                            email: '',
                            note: text,
                          );
                          if (context.mounted) await _done(context, ref, problem);
                        },
                        child: Text(l10n.supplierContactFromText),
                      ),
                    TextButton.icon(
                      key: const ValueKey('supplier-contact-add'),
                      onPressed: roles.isEmpty ? null : () => _edit(context, ref, null, roles),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.supplierContactAdd),
                    ),
                  ],
                ),
              ),
              const FormGap.large(),
              Text(l10n.supplierTermsTitle, style: Theme.of(context).textTheme.titleSmall),
              const FormGap.small(),
              AsyncReadBody<SupplierTerms>.part(
                value: ref.watch(supplierTermsProvider(_key)),
                onRetry: () => ref.invalidate(supplierTermsProvider(_key)),
                data: (terms) => _Terms(key: ValueKey('supplier-terms-${supplier.id}'), terms: terms, onSave: (t) async {
                  final problem = await commands.saveTerms(workspaceId, supplier.id, t);
                  if (context.mounted) await _done(context, ref, problem);
                }),
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(MaterialLocalizations.of(context).closeButtonLabel))],
    );
  }
}

/// The terms of a supplier: each filled in or left empty.
class _Terms extends StatefulWidget {
  const _Terms({super.key, required this.terms, required this.onSave});

  final SupplierTerms terms;
  final Future<void> Function(SupplierTerms terms) onSave;

  @override
  State<_Terms> createState() => _TermsState();
}

class _TermsState extends State<_Terms> {
  late final _currency = TextEditingController(text: widget.terms.orderCurrency ?? '');
  late final _term = TextEditingController(text: widget.terms.paymentTermDays?.toString() ?? '');
  late final _lead = TextEditingController(text: widget.terms.orderLeadDays?.toString() ?? '');

  @override
  void dispose() {
    _currency.dispose();
    _term.dispose();
    _lead.dispose();
    super.dispose();
  }

  int? _days(TextEditingController c) => int.tryParse(c.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CurrencyField(textKey: const ValueKey('supplier-terms-currency'), controller: _currency, label: l10n.supplierTermsCurrency),
        const FormGap(),
        AppTextField(
          key: const ValueKey('supplier-terms-payment-days'),
          controller: _term,
          label: l10n.supplierTermsPaymentDays,
          keyboardType: TextInputType.number,
          inputFormatters: digits,
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('supplier-terms-lead-days'),
          controller: _lead,
          label: l10n.supplierTermsLeadDays,
          keyboardType: TextInputType.number,
          inputFormatters: digits,
        ),
        const FormGap(),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(
            key: const ValueKey('supplier-terms-save'),
            onPressed: () => widget.onSave(
              SupplierTerms(
                orderCurrency: _currency.text.trim().isEmpty ? null : _currency.text.trim().toUpperCase(),
                paymentTermDays: _days(_term),
                orderLeadDays: _days(_lead),
              ),
            ),
            child: Text(MaterialLocalizations.of(context).saveButtonLabel),
          ),
        ),
      ],
    );
  }
}
