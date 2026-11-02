// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — "Submit through MTD": the nine boxes of a prepared UK VAT return,
// the HMRC sign-in, and the one submit. The boxes are the ones the bridging
// CSV writes; the server recomputes them and refuses any difference. Only a
// receipt from HMRC files the return; an unconfirmed answer files nothing.
// Web builds only (HMRC's connection method WEB_APP_VIA_SERVER); other builds
// say to use the web app.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/hmrc_submission.dart';
import '../../domain/mtd_boxes.dart';
import '../../domain/vat_declaration.dart';
import '../../providers/hmrc_providers.dart';
import '../../providers/vat_declaration_providers.dart';

/// The sheet's button on a prepared UK return.
Widget hmrcSubmitButton(
  BuildContext context,
  VatDeclaration declaration, {
  required String? issuerSiteId,
}) => OutlinedButton.icon(
  key: ValueKey('vat-decl-mtd-${declaration.id}'),
  icon: const Icon(Icons.send_outlined, size: 18),
  label: Text(context.l10n.hmrcSubmitButton),
  onPressed: () => showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _HmrcSubmitSheet(
      declaration: declaration,
      issuerSiteId: issuerSiteId,
    ),
  ),
);

class _HmrcSubmitSheet extends ConsumerStatefulWidget {
  const _HmrcSubmitSheet({
    required this.declaration,
    required this.issuerSiteId,
  });

  final VatDeclaration declaration;
  final String? issuerSiteId;

  @override
  ConsumerState<_HmrcSubmitSheet> createState() => _HmrcSubmitSheetState();
}

class _HmrcSubmitSheetState extends ConsumerState<_HmrcSubmitSheet> {
  bool _busy = false;
  HmrcOutcome? _outcome;

  Future<void> _connect(HmrcState state) async {
    final site = widget.issuerSiteId;
    if (site == null || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(connectHmrcProvider).call(
        workspaceId: widget.declaration.workspaceId,
        issuerSiteId: site,
        state: state,
      );
      ref.invalidate(hmrcStateProvider(widget.declaration.workspaceId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit(HmrcConnection connection, HmrcClientValues client) async {
    // One command: the button is disabled from the first activation.
    if (_busy) return;
    setState(() {
      _busy = true;
      _outcome = null;
    });
    try {
      final outcome = await ref
          .read(submitToHmrcProvider)
          .call(
            declaration: widget.declaration,
            connection: connection,
            client: client,
          );
      if (!mounted) return;
      setState(() => _outcome = outcome);
      if (outcome is HmrcFiled || outcome is HmrcAcceptedNotRecorded) {
        ref.invalidate(vatDeclarationsProvider);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspaceId = widget.declaration.workspaceId;
    final client = ref.watch(hmrcClientValuesProvider);
    final state = ref.watch(hmrcStateProvider(workspaceId));
    final cents = mtdBoxCents(widget.declaration);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.hmrcSheetTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.hmrcSheetIntro),
            const SizedBox(height: AppSpacing.md),
            for (final (i, field) in mtdBoxFields.indexed)
              ListTile(
                key: ValueKey('hmrc-box-$field'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(_boxLabel(l10n, i + 1)),
                trailing: Text(mtdBoxText(field, cents[field]!)),
              ),
            const SizedBox(height: AppSpacing.md),
            switch ((client, state)) {
              (AsyncData(value: null), _) => Text(
                l10n.hmrcWebOnly,
                key: const ValueKey('hmrc-web-only'),
              ),
              (AsyncData(value: final values?), AsyncData(value: final s)) =>
                _body(l10n, s, values),
              (AsyncError(), _) || (_, AsyncError()) => InlineBanner(
                icon: Icons.error_outline,
                text: l10n.hmrcRefusalOther,
              ),
              _ => const LoadingView(),
            },
            if (_outcome != null) ...[
              const SizedBox(height: AppSpacing.md),
              _outcomeBanner(l10n, _outcome!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n, HmrcState s, HmrcClientValues values) {
    final connection = s.connection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.demo)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(l10n.hmrcDemoNote, key: const ValueKey('hmrc-demo-note')),
          ),
        if (s.vrn == null)
          Text(l10n.hmrcNoVrn, key: const ValueKey('hmrc-no-vrn'))
        else ...[
          Text(l10n.hmrcVrnLine(s.vrn!)),
          const SizedBox(height: AppSpacing.sm),
          if (connection == null || !connection.isConnected) ...[
            Text(switch (connection?.link) {
              HmrcLink.expired => l10n.hmrcExpired,
              HmrcLink.pending => l10n.hmrcPending,
              _ => l10n.hmrcConnectHint,
            }),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const ValueKey('hmrc-connect'),
              onPressed: _busy || widget.issuerSiteId == null ? null : () => _connect(s),
              child: Text(l10n.hmrcConnect),
            ),
            if (connection?.link == HmrcLink.pending)
              TextButton(
                key: const ValueKey('hmrc-signed-in'),
                onPressed: () => ref.invalidate(
                  hmrcStateProvider(widget.declaration.workspaceId),
                ),
                child: Text(l10n.hmrcSignedIn),
              ),
          ] else ...[
            Text(l10n.hmrcConnected),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const ValueKey('hmrc-submit'),
              onPressed: _busy || _outcome is HmrcFiled
                  ? null
                  : () => _submit(connection, values),
              child: Text(l10n.hmrcSubmitNow),
            ),
          ],
        ],
      ],
    );
  }

  Widget _outcomeBanner(AppLocalizations l10n, HmrcOutcome outcome) {
    final (icon, text) = switch (outcome) {
      HmrcFiled(:final receipt, :final demo) => (
        Icons.check_circle_outline,
        demo
            ? l10n.hmrcFiledDemo(receipt.formBundleNumber)
            : l10n.hmrcFiled(receipt.formBundleNumber),
      ),
      HmrcAcceptedNotRecorded(:final receipt) => (
        Icons.warning_amber_outlined,
        l10n.hmrcAcceptedNotRecorded(receipt.formBundleNumber),
      ),
      HmrcUnconfirmed() => (Icons.help_outline, l10n.hmrcUnconfirmed),
      HmrcRefused(:final refusal) => (Icons.block, _refusalText(l10n, refusal)),
    };
    return InlineBanner(
      key: const ValueKey('hmrc-outcome'),
      icon: icon,
      text: text,
    );
  }
}

String _boxLabel(AppLocalizations l10n, int n) => switch (n) {
  1 => l10n.hmrcBox1,
  2 => l10n.hmrcBox2,
  3 => l10n.hmrcBox3,
  4 => l10n.hmrcBox4,
  5 => l10n.hmrcBox5,
  6 => l10n.hmrcBox6,
  7 => l10n.hmrcBox7,
  8 => l10n.hmrcBox8,
  _ => l10n.hmrcBox9,
};

String _refusalText(AppLocalizations l10n, HmrcRefusal r) => switch (r) {
  HmrcRefusal.notAllowed => l10n.hmrcRefusalNotAllowed,
  HmrcRefusal.notConfigured => l10n.hmrcRefusalNotConfigured,
  HmrcRefusal.notConnected => l10n.hmrcRefusalNotConnected,
  HmrcRefusal.wrongRegistration => l10n.hmrcRefusalWrongRegistration,
  HmrcRefusal.signInAgain => l10n.hmrcRefusalSignInAgain,
  HmrcRefusal.figuresDiffer => l10n.hmrcRefusalFiguresDiffer,
  HmrcRefusal.acquisitionNotSupported => l10n.hmrcRefusalAcquisitionNotSupported,
  HmrcRefusal.noOpenObligation => l10n.hmrcRefusalNoOpenObligation,
  HmrcRefusal.alreadySubmitted => l10n.hmrcRefusalAlreadySubmitted,
  HmrcRefusal.notAuthorised => l10n.hmrcRefusalNotAuthorised,
  HmrcRefusal.refused => l10n.hmrcRefusalRefused,
  HmrcRefusal.busy => l10n.hmrcRefusalBusy,
  HmrcRefusal.inFlight => l10n.hmrcRefusalInFlight,
  HmrcRefusal.acceptedForOtherFigures => l10n.hmrcRefusalAcceptedForOtherFigures,
  HmrcRefusal.fraudHeadersMissing => l10n.hmrcRefusalFraudHeadersMissing,
  HmrcRefusal.unreachable => l10n.hmrcRefusalUnreachable,
  HmrcRefusal.other => l10n.hmrcRefusalOther,
};
