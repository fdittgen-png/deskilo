// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Find company details: the person names the country and the identifier,
// the registry answers, and the answer goes to the supplier form for
// review — never straight to a save. Every way the registry can fail
// keeps what was typed on screen and offers the next step: retry when
// asking again can help, change the input, or go on by hand.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/country/country_catalog.dart';
import '../../../../core/i18n/country_names.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/lookup_company.dart';
import '../../domain/company_lookup.dart';
import '../../domain/supplier.dart';
import '../../domain/supplier_prefill.dart';
import '../../providers/company_lookup_providers.dart';

/// What the person decided in the lookup dialog.
sealed class SupplierLookupOutcome {
  const SupplierLookupOutcome();
}

/// Fill the form from the registry's answer and review it.
class SupplierLookupReviewed extends SupplierLookupOutcome {
  const SupplierLookupReviewed(this.prefill);

  final SupplierPrefill prefill;
}

/// Go on by hand, keeping what was typed.
class SupplierLookupManual extends SupplierLookupOutcome {
  const SupplierLookupManual({
    required this.countryCode,
    required this.identifier,
  });

  final String countryCode;
  final String identifier;
}

/// Open the supplier that already carries the identifier.
class SupplierLookupExisting extends SupplierLookupOutcome {
  const SupplierLookupExisting(this.supplier);

  final Supplier supplier;
}

/// The words for a registry's answer, shared with the review step.
String supplierLookupStatusText(
  AppLocalizations l10n,
  CompanyLookupResult result,
) => switch (result.validation) {
  IdentifierValidation.validated => l10n.supplierLookupStatusValidated,
  IdentifierValidation.notValidated =>
    result.retrieval == LookupRetrieval.retrieved
        ? l10n.supplierLookupStatusRetrievedNotValidated
        : l10n.supplierLookupStatusCouldNotVerify,
  IdentifierValidation.invalid => l10n.supplierLookupStatusCouldNotVerify,
  IdentifierValidation.unavailable => l10n.supplierLookupStatusUnavailable,
};

/// The name a provider is shown under.
String supplierLookupProviderName(AppLocalizations l10n, String providerId) =>
    providerId == viesProviderId ? l10n.supplierLookupProviderVies : providerId;

/// Opens the lookup for [workspaceId]; null when cancelled. [existing] is
/// what the duplicate check reads; [countryCode] and [identifier] start
/// the fields; [base] is what the form already holds, kept where the
/// registry returns nothing.
Future<SupplierLookupOutcome?> showSupplierLookupDialog(
  BuildContext context, {
  required String workspaceId,
  required List<Supplier> existing,
  String countryCode = '',
  String identifier = '',
  SupplierDraft base = const SupplierDraft(name: ''),
}) => showDialog<SupplierLookupOutcome>(
  context: context,
  builder: (_) => _SupplierLookupDialog(
    workspaceId: workspaceId,
    existing: existing,
    countryCode: countryCode,
    identifier: identifier,
    base: base,
  ),
);

class _SupplierLookupDialog extends ConsumerStatefulWidget {
  const _SupplierLookupDialog({
    required this.workspaceId,
    required this.existing,
    required this.countryCode,
    required this.identifier,
    required this.base,
  });

  final String workspaceId;
  final List<Supplier> existing;
  final String countryCode;
  final String identifier;
  final SupplierDraft base;

  @override
  ConsumerState<_SupplierLookupDialog> createState() =>
      _SupplierLookupDialogState();
}

/// What the dialog says below the fields after an attempt.
class _Problem {
  const _Problem(this.text, {this.retryable = false, this.existing});

  final String text;

  /// Asking again can change the answer.
  final bool retryable;

  /// A supplier already carries the identifier.
  final Supplier? existing;
}

class _SupplierLookupDialogState extends ConsumerState<_SupplierLookupDialog> {
  late final FormControllers _fields = FormControllers({
    'identifier': widget.identifier,
  });
  String? _country;
  bool _busy = false;
  String? _identifierError;
  String? _countryError;
  _Problem? _problem;

  @override
  void initState() {
    super.initState();
    final code = widget.countryCode.trim().toUpperCase();
    _country = code.isEmpty ? null : code;
  }

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  /// One place that changes what the dialog shows.
  void _show({
    _Problem? problem,
    String? identifierError,
    String? countryError,
    bool busy = false,
  }) {
    if (!mounted) return;
    setState(() {
      _problem = problem;
      _identifierError = identifierError;
      _countryError = countryError;
      _busy = busy;
    });
    final announced = identifierError ?? countryError ?? problem?.text;
    if (announced != null) {
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          announced,
          Directionality.of(context),
        ),
      );
    }
  }

  /// The countries offered: every one a provider answers for, plus the
  /// ones the app bills in, so an unsupported choice is possible and gets
  /// its honest answer.
  List<String> _countries(AppLocalizations l10n, LookupCompany lookup) {
    return <String>{
      for (final p in lookup.providers) ...p.countries,
      for (final c in CountryCatalog.countries) c.code,
    }.toList()..sort(
      (a, b) => localizedCountryName(
        l10n,
        a,
      ).compareTo(localizedCountryName(l10n, b)),
    );
  }

  SupplierLookupManual _manual() => SupplierLookupManual(
    countryCode: _country ?? '',
    identifier: _fields.text('identifier'),
  );

  Future<void> _find() async {
    if (_busy) return;
    final l10n = context.l10n;
    final typed = _fields.text('identifier');
    if (typed.isEmpty) {
      _show(identifierError: l10n.supplierLookupIdentifierMissing);
      return;
    }
    final identifier = normalizeCompanyIdentifier(
      typed,
      country: _country ?? '',
    );
    if (identifier == null) {
      if (_country == null) {
        _show(countryError: l10n.supplierLookupCountryMissing);
      } else {
        _show(identifierError: l10n.supplierLookupIdentifierMalformed);
      }
      return;
    }
    final existing = supplierWithIdentifier(widget.existing, identifier);
    if (existing != null) {
      _show(
        problem: _Problem(
          l10n.supplierLookupDuplicate('${existing.number} · ${existing.name}'),
          existing: existing,
        ),
      );
      return;
    }
    await _ask(l10n, CompanyLookupRequest(identifier: identifier));
  }

  Future<void> _ask(AppLocalizations l10n, CompanyLookupRequest request) async {
    final lookup = ref.read(lookupCompanyProvider);
    final capability = lookup.providerFor(request);
    if (capability == null) {
      _show(
        problem: _Problem(
          l10n.supplierLookupUnsupported(
            localizedCountryName(l10n, request.countryCode),
          ),
        ),
      );
      return;
    }
    _show(busy: true);
    final CompanyLookupResult result;
    try {
      result = await lookup(widget.workspaceId, request);
    } on CompanyLookupRefused catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'supplier lookup refused',
        error: e,
        stackTrace: st,
      );
      _show(problem: _Problem(l10n.supplierLookupRefused));
      return;
    }
    if (!mounted) return;
    if (result.canReview) {
      Navigator.of(context).pop(
        SupplierLookupReviewed(
          prefillFromLookup(
            request: request,
            result: result,
            capability: capability,
            base: widget.base,
          ),
        ),
      );
      return;
    }
    _show(
      problem: _Problem(
        _failureText(l10n, request, result),
        retryable: result.isRetryable,
      ),
    );
  }

  static String _failureText(
    AppLocalizations l10n,
    CompanyLookupRequest request,
    CompanyLookupResult result,
  ) => switch (result.retrieval) {
    LookupRetrieval.notFound => l10n.supplierLookupNotFound,
    LookupRetrieval.invalidInput => l10n.supplierLookupInvalidInput,
    LookupRetrieval.unsupported => l10n.supplierLookupUnsupported(
      localizedCountryName(l10n, request.countryCode),
    ),
    LookupRetrieval.timeout => l10n.supplierLookupTimeout,
    LookupRetrieval.throttled => l10n.supplierLookupThrottled,
    LookupRetrieval.unavailable => l10n.supplierLookupUnavailable,
    LookupRetrieval.malformed => l10n.supplierLookupMalformed,
    LookupRetrieval.retrieved ||
    LookupRetrieval.notReturned => supplierLookupStatusText(l10n, result),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final lookup = ref.watch(lookupCompanyProvider);
    final countries = _countries(l10n, lookup);
    final problem = _problem;
    return AlertDialog(
      title: Text(l10n.supplierLookupFind),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.supplierLookupIntro,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const FormGap(),
            DropdownButtonFormField<String>(
              key: const ValueKey('supplier-lookup-country'),
              isExpanded: true,
              initialValue: countries.contains(_country) ? _country : null,
              decoration: InputDecoration(
                labelText: l10n.supplierLookupCountry,
                errorText: _countryError,
              ),
              items: [
                for (final code in countries)
                  DropdownMenuItem(
                    value: code,
                    child: Text(
                      localizedCountryName(l10n, code),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _busy ? null : (v) => setState(() => _country = v),
            ),
            const FormGap(),
            AppTextField(
              key: const ValueKey('supplier-lookup-identifier'),
              controller: _fields['identifier'],
              label: l10n.supplierLookupIdentifier,
              helper: l10n.supplierLookupIdentifierHelp,
              error: _identifierError,
              autofocus: true,
              enabled: !_busy,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _find(),
              maxLength: 40,
            ),
            if (_busy) ...[
              const FormGap.small(),
              LinearProgressIndicator(
                key: const ValueKey('supplier-lookup-progress'),
                semanticsLabel: l10n.supplierLookupSearching,
              ),
            ],
            if (problem != null) ...[
              const FormGap(),
              Semantics(
                liveRegion: true,
                child: InlineBanner(
                  key: const ValueKey('supplier-lookup-problem'),
                  icon: problem.existing != null
                      ? Icons.people_outline
                      : Icons.error_outline,
                  severity: problem.existing != null
                      ? InlineBannerSeverity.info
                      : InlineBannerSeverity.error,
                  text: problem.text,
                ),
              ),
            ],
          ],
        ),
      ),
      // The next step lives here, where a dialog keeps it on screen while
      // the fields scroll: go on by hand (with what was typed), open the
      // supplier that already exists, or ask again.
      actions: [
        TextButton(
          key: const ValueKey('supplier-lookup-cancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        if (problem?.existing case final existing?)
          TextButton(
            key: const ValueKey('supplier-lookup-open-existing'),
            onPressed: () =>
                Navigator.of(context).pop(SupplierLookupExisting(existing)),
            child: Text(l10n.supplierLookupOpenExisting),
          )
        else
          TextButton(
            key: const ValueKey('supplier-lookup-manual'),
            onPressed: _busy
                ? null
                : () => Navigator.of(context).pop(_manual()),
            child: Text(
              problem == null
                  ? l10n.supplierLookupEnterManually
                  : l10n.supplierLookupContinueManually,
            ),
          ),
        FilledButton(
          key: const ValueKey('supplier-lookup-find'),
          onPressed: _busy ? null : _find,
          child: Text(
            (problem?.retryable ?? false)
                ? l10n.supplierLookupRetry
                : l10n.supplierLookupFind,
          ),
        ),
      ],
    );
  }
}
