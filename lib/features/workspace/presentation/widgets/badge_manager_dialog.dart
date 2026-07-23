// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/files/file_saver.dart';
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
        );
        final safeName = widget.name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
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
    return runGuarded(
      context,
      domain: 'workspace',
      message: 'badge delete failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => widget.delete(badge.id),
    );
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
    if (badge.isActive) return row;
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

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final issued = _issued;
    final badges = _badges;
    final badgeCountOf = badges?.length ?? 0;
    return AlertDialog(
      title: Text(
        l10n?.memberBadgesTitle(widget.name) ?? 'Badges — ${widget.name}',
      ),
      content: SizedBox(
        width: 320,
        child: issued != null
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
                      if (badgeCountOf == 0)
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
        if (issued == null)
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
/// always stopped, whether the user taps a card or cancels.
class NfcTapDialog extends StatefulWidget {
  const NfcTapDialog({super.key, required this.reader, required this.l10n});

  final NfcUidReader reader;
  final AppLocalizations? l10n;

  @override
  State<NfcTapDialog> createState() => _NfcTapDialogState();
}

class _NfcTapDialogState extends State<NfcTapDialog> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.reader.startRead(
        onUid: (uid) {
          if (_done || !mounted) return;
          _done = true;
          Navigator.of(context).pop(uid);
        },
      ),
    );
  }

  @override
  void dispose() {
    unawaited(widget.reader.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n?.badgeTapCardTitle ?? 'Register a card'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Icon(Icons.contactless_outlined, size: 56),
          ),
          Text(
            l10n?.badgeTapCardHint ??
                'Hold the RFID/NFC card to the back of the device.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('nfc-tap-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
      ],
    );
  }
}
