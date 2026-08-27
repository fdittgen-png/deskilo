// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/material.dart';

import 'nfc_tap_dialog.dart';
import 'package:intl/intl.dart';

import '../../../../core/time/clock.dart';
import '../../../money/presentation/batch_cover.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/files/file_names.dart';
import '../../../../core/files/file_saver.dart';
import '../../../../core/help/help_hint.dart';
import '../../../../core/nfc/nfc_uid_reader.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/badge_pdf.dart';
import '../../domain/member_badge.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';

/// One member's badge manager (0043/0046, extracted for the 0053
/// self-service pass): the badge list with revoke, the one-time QR with
/// its printable PDF, and the RFID/NFC card registration. The three
/// server operations are INJECTED so the admin surface (Members &
/// plans) and the member's own Settings entry share this widget with
/// their respective RPCs.
class BadgeManagerDialog extends ConsumerStatefulWidget {
  const BadgeManagerDialog({
    super.key,
    required this.workspaceId,
    required this.memberId,
    required this.name,
    required this.l10n,
    required this.issue,
    required this.registerNfc,
    required this.revoke,
    required this.delete,
    this.setAuthEnabled,
  });

  final String workspaceId;
  final String memberId;
  final String name;
  final AppLocalizations? l10n;

  /// Mints a badge for the subject; returns the one-time token.
  final Future<IssuedBadge> Function() issue;

  /// Registers a tapped card's normalized [uid] for the subject.
  final Future<void> Function(String uid) registerNfc;

  /// Revokes one of the subject's badges.
  final Future<void> Function(String badgeId) revoke;

  /// Deletes a REVOKED badge for good (0055) — the swipe-right cleanup
  /// of the pile a badge history leaves behind.
  final Future<void> Function(String badgeId) delete;

  /// #662 — arms or disarms ONE badge for sign-in.
  ///
  /// Null hides the control entirely, which is how an ADMIN opening
  /// someone else's badges sees no toggle. That is not a UI nicety: the
  /// server refuses it too ('not your badge'), because an admin who
  /// could arm a member's badge could sign in as them, and every
  /// check-in after would carry that member's name.
  final Future<void> Function(String badgeId, bool enabled)? setAuthEnabled;

  @override
  ConsumerState<BadgeManagerDialog> createState() =>
      _BadgeManagerDialogState();
}

class _BadgeManagerDialogState
    extends ConsumerState<BadgeManagerDialog> {
  List<MemberBadge>? _badges;

  /// Set right after issuing: the one-time raw token to render as a QR.
  IssuedBadge? _issued;

  /// Whether this device can read an RFID/NFC tap (Android + NFC on).
  bool _nfcAvailable = false;

  /// #662 — a badge arm/disarm is in flight. Without it a double tap
  /// sends two opposite writes and the switch settles on whichever
  /// landed second.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _checkNfc();
  }

  Future<void> _checkNfc() async {
    // Both the workspace toggle AND this device's hardware must allow it.
    final enabled = ref
        .read(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.nfcBadges);
    final available =
        enabled && await ref.read(nfcUidReaderProvider).isAvailable();
    if (mounted) setState(() => _nfcAvailable = available);
  }

  Future<void> _load() async {
    final l10n = widget.l10n;
    List<MemberBadge> all = const [];
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'badge list failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        all = await ref
            .read(workspaceRepositoryProvider)
            .fetchMemberBadges(widget.workspaceId);
      },
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _badges =
        [for (final b in all) if (b.memberId == widget.memberId) b]);
  }

  Future<void> _issue() async {
    final l10n = widget.l10n;
    IssuedBadge? issued;
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'badge issue failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        issued = await widget.issue();
      },
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _issued = issued);
    unawaited(_load());
  }

  /// Downloads the freshly issued badge as a printable PDF card (the QR
  /// exists only in this dialog — this is the moment to keep it).
  Future<void> _savePdf(IssuedBadge issued) async {
    final l10n = widget.l10n;
    final workspaceName =
        ref.read(currentWorkspaceProvider).value?.name ?? '';
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'badge PDF export failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        // #671 — the sheet's wording is the workspace's own now, edited
        // in report management like every other printable.
        final cover = batchCover(context, ref, docId: 'badges', data: {
          'workspace': workspaceName,
          'member': widget.name,
          'issued': DateFormat.yMMMMd(
            Localizations.localeOf(context).toLanguageTag(),
          ).format(ref.read(clockProvider).now()),
        });
        // Built BEFORE the awaits: it reads the context, and the font
        // loads below are async gaps.
        // Embedded Roboto like the bill PDF: accented names must encode.
        final regular =
            await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
        final bytes = await buildBadgePdf(
          workspaceName: workspaceName,
          memberName: widget.name,
          token: issued.token,
          hint: l10n?.kioskPresentBadge ?? 'Present your badge',
          baseFont: pw.Font.ttf(regular),
          boldFont: pw.Font.ttf(bold),
          coverHeader: cover.header,
          coverBody: cover.body,
          coverFooter: cover.footer,
        );
        final safeName = safeFileSlug(widget.name);
        final path = await ref.read(fileSaverProvider)(
          bytes: bytes,
          fileName: 'deskilo-badge-$safeName.pdf',
        );
        if (!mounted) return;
        if (path == null) {
          AppSnack.error(
            context,
            l10n?.commonSaveFailed ?? 'Could not save.',
          );
        } else {
          AppSnack.success(
            context,
            l10n?.commonSavedTo(path) ?? 'Saved to $path',
          );
        }
      },
    )) {
      return;
    }
  }

  /// Registers a physical RFID/NFC card as this member's badge (0046):
  /// prompt "tap the card", read its UID, hand it to the server. The
  /// reader session is always stopped, and a re-registered tag maps to
  /// its own message.
  Future<void> _registerNfc() async {
    final l10n = widget.l10n;
    final reader = ref.read(nfcUidReaderProvider);
    final uid = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => NfcTapDialog(reader: reader, l10n: l10n),
    );
    if (uid == null || uid.isEmpty || !mounted) return;

    var duplicate = false;
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'nfc badge registration failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        try {
          await widget.registerNfc(uid);
        } on PostgrestException catch (e, st) {
          if (e.message.contains('tag already registered')) {
            duplicate = true;
            return; // handled below, not a generic failure
          }
          // trace-exempt: rethrown to runGuarded, which logs it.
          Error.throwWithStackTrace(e, st);
        }
      },
    )) {
      return;
    }
    if (!mounted) return;
    if (duplicate) {
      AppSnack.error(
        context,
        l10n?.badgeCardAlreadyRegistered ??
            'That card is already registered.',
      );
      return;
    }
    AppSnack.success(
      context,
      l10n?.badgeCardRegistered ?? 'Card registered.',
    );
    unawaited(_load());
  }

  Future<void> _revoke(MemberBadge badge) async {
    final l10n = widget.l10n;
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'badge revoke failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => widget.revoke(badge.id),
    )) {
      return;
    }
    await _load();
  }

  /// Deletes a revoked badge; returns whether the swipe may complete —
  /// a failed delete snaps the row back instead of lying about it.
  Future<bool> _delete(MemberBadge badge) async {
    final l10n = widget.l10n;
    // #523 — every swipe-delete in the app confirms before destroying.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.memberNoteDelete ?? 'Delete'),
        content: Text(l10n?.badgeDeleteConfirm ??
            'Delete this revoked badge for good?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            key: const ValueKey('badge-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n?.memberNoteDelete ?? 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    return runGuarded(
      context,
      domain: 'workspace',
      message: 'badge delete failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => widget.delete(badge.id),
    );
  }

  /// #662 — arm or disarm this badge for sign-in.
  ///
  /// The server refuses to arm a badge before its owner has a PIN, and
  /// that refusal is SURFACED rather than swallowed: without it the
  /// switch would flick back with no explanation, and the member has no
  /// way to guess that a PIN is the missing piece.
  Future<void> _setAuth(
    MemberBadge badge,
    bool enabled,
    Future<void> Function(String badgeId, bool enabled) arm,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = widget.l10n;
    await runGuarded(
      context,
      domain: 'workspace',
      message: 'badge auth toggle failed',
      errorText: l10n?.badgeAuthNeedsPin ??
          'Set a sign-in PIN first — a badge alone must never be enough.',
      action: () => arm(badge.id, enabled),
    );
    if (mounted) setState(() => _busy = false);
  }

  /// One badge row: live badges keep the Revoke button; revoked ones
  /// are swiped RIGHT to delete for good (field request — a badge
  /// history piles up otherwise).
  Widget _badgeRow(BuildContext context, MemberBadge badge) {
    final l10n = widget.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final row = ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        !badge.isActive
            ? Icons.block_outlined
            : badge.kind == BadgeKind.nfc
                ? Icons.contactless_outlined
                : Icons.qr_code_2_outlined,
      ),
      title: Text(
        badge.label.isEmpty
            ? (l10n?.badgeDefaultLabel ?? 'Badge')
            : badge.label,
      ),
      subtitle: badge.isActive
          ? null
          : Text(l10n?.badgeRevoked ?? 'Revoked'),
      trailing: badge.isActive
          ? TextButton(
              onPressed: () => _revoke(badge),
              child: Text(l10n?.badgeRevoke ?? 'Revoke'),
            )
          : null,
    );
    if (badge.isActive) {
      final arm = widget.setAuthEnabled;
      if (arm == null) return row;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        row,
        SwitchListTile(
          key: ValueKey('badge-auth-${badge.id}'),
          contentPadding: EdgeInsets.zero,
          value: badge.authEnabled,
          title: Text(l10n?.badgeAuthEnabledLabel ?? 'Signs me in'),
          subtitle: Text(
            l10n?.badgeAuthEnabledHint ??
                'Off by default: a badge that checks you in does not log '
                    'you in until you say so.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          onChanged: _busy ? null : (value) => _setAuth(badge, value, arm),
        ),
      ]);
    }
    return Dismissible(
      key: ValueKey('badge-dismiss-${badge.id}'),
      direction: DismissDirection.startToEnd,
      background: ColoredBox(
        color: colorScheme.errorContainer,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Icon(
              Icons.delete_outline,
              color: colorScheme.onErrorContainer,
            ),
          ),
        ),
      ),
      confirmDismiss: (_) => _delete(badge),
      onDismissed: (_) => setState(
        () => _badges?.removeWhere((b) => b.id == badge.id),
      ),
      child: row,
    );
  }

  /// The dialog body below the workspace line: the one-time QR, the
  /// loading spinner, or the badge list.
  Widget _content(
    BuildContext context,
    IssuedBadge? issued,
    List<MemberBadge>? badges,
  ) {
    final l10n = widget.l10n;
    return issued != null
        ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The raw token, once: print it or let the member scan
                  // it into their badge wallet.
                  Center(
                    child: QrImageView(
                      key: const ValueKey('badge-qr'),
                      data: issued.token,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n?.badgeTokenOnce ??
                        'Save this QR now — it is shown only once.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : badges == null
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (badges.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            l10n?.badgeNone ?? 'No badges yet.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      for (final badge in badges)
                        _badgeRow(context, badge),
                    ],
                  );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final issued = _issued;
    final badges = _badges;
    return AlertDialog(
      title: Text(
        l10n?.memberBadgesTitle(widget.name) ?? 'Badges — ${widget.name}',
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // #606 — contextual how-to; gated inside the widget.
            const HelpHint(HelpHintId.badges),
            // Badges are PER WORKSPACE (0056) — say which one this
            // manager registers into, so a card is never silently
            // attached to the wrong profile's workspace (field trap:
            // read at the kiosk, "not recognized").
            Text(
              ref.watch(currentWorkspaceProvider).value?.name ?? '',
              key: const ValueKey('badge-workspace-name'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            _content(context, issued, badges),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonClose ?? 'Close'),
        ),
        // Download & print the one-time QR as a badge card (UX pass).
        if (issued != null)
          FilledButton.icon(
            key: const ValueKey('badge-save-pdf'),
            onPressed: () => _savePdf(issued),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(l10n?.badgeSavePdf ?? 'Save as PDF'),
          ),
        if (issued == null && _nfcAvailable)
          OutlinedButton.icon(
            key: const ValueKey('badge-register-nfc-button'),
            onPressed: _registerNfc,
            icon: const Icon(Icons.contactless_outlined),
            label: Text(l10n?.badgeRegisterCard ?? 'Register card'),
          ),
        // #604 — QR badge issuance rides its own flag beside nfcBadges.
        if (issued == null &&
            ref
                .watch(enabledFeaturesSyncProvider)
                .contains(WorkspaceFeature.qrBadges))
          FilledButton.icon(
            key: const ValueKey('badge-issue-button'),
            onPressed: _issue,
            icon: const Icon(Icons.qr_code_2_outlined),
            label: Text(l10n?.badgeIssue ?? 'New badge'),
          ),
      ],
    );
  }
}

/// "Tap the card" prompt (0046): starts an NFC read session and pops with
/// the first tag's normalized UID. Owns the session lifecycle so it is
