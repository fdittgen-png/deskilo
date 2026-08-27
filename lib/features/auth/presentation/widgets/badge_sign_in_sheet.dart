// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/nfc/nfc_uid_reader.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/badge_sign_in.dart';
import '../../providers/auth_providers.dart';

/// Signing in by badge (#662): scan, then PIN, on one sheet.
///
/// One sheet, two steps — which is what the user asked for, and it is
/// not cosmetic. The scan is what makes it possible to say "Hello Alex,
/// your PIN?" instead of asking a shared tablet's user to type an
/// address in front of whoever is in the room.
///
/// WHAT THIS SHEET REFUSES TO EXPLAIN. Every failure except a lockout
/// says the same sentence. An unknown card, a card whose owner never set
/// a PIN, a card nobody armed and a wrong PIN are indistinguishable from
/// here, because a sheet that told them apart would sort a stolen stack
/// of cards into real and fake for whoever is holding it. The server
/// keeps the same silence; this is the client half of one decision.
Future<void> showBadgeSignInSheet(
  BuildContext context, {
  String? scannedUid,
}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: BadgeSignInSheet(scannedUid: scannedUid),
      ),
    );

class BadgeSignInSheet extends ConsumerStatefulWidget {
  const BadgeSignInSheet({super.key, this.scannedUid});

  /// A tag this sheet does not have to read itself, because the caller
  /// already did — a kiosk whose reader is always live, or a test, which
  /// has no reader at all. Given one, the sheet opens straight on the
  /// PIN step for whoever it identifies.
  final String? scannedUid;

  @override
  ConsumerState<BadgeSignInSheet> createState() => _BadgeSignInSheetState();
}

class _BadgeSignInSheetState extends ConsumerState<BadgeSignInSheet> {
  final _reader = NfcUidReader();
  final _pin = TextEditingController();
  final _pinFocus = FocusNode();

  /// The scanned tag, kept because step 2 must send it again — the
  /// server holds no session between the two calls, deliberately.
  String? _uid;
  BadgeIdentity? _who;
  BadgeSignInFailure? _failure;
  bool _busy = false;
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    final preset = widget.scannedUid;
    if (preset != null) {
      _onUid(preset);
    } else {
      _scan();
    }
  }

  @override
  void dispose() {
    // Unawaited on purpose: dispose cannot await, and the reader is
    // built to survive a stop that is still in flight when the next
    // sheet starts one.
    _reader.stop();
    _pin.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _failure = null;
      _reading = true;
    });
    final up = await _reader.startRead(onUid: _onUid);
    if (!mounted) return;
    // startRead reports whether a session is REALLY up. Showing the tap
    // icon over a dead reader is the failure this return value exists
    // to prevent.
    if (!up) {
      setState(() {
        _reading = false;
        _failure = BadgeSignInFailure.unavailable;
      });
    }
  }

  Future<void> _onUid(String uid) async {
    if (!mounted || _busy) return;
    // Fire-and-forget: closing the reader is cleanup, and the tag is
    // already in hand. Awaiting it stalls the whole sheet whenever the
    // platform is slow to answer — or never answers, which is exactly
    // what a device with no reader does, leaving the member looking at
    // "hold your badge" forever after a successful tap.
    unawaited(_reader.stop());
    setState(() {
      _busy = true;
      _uid = uid;
    });
    final result = await ref.read(authRepositoryProvider).identifyBadge(uid);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _reading = false;
      _who = result.value;
      _failure = result.failure;
    });
    if (result.ok) _pinFocus.requestFocus();
  }

  Future<void> _submit() async {
    final uid = _uid;
    if (uid == null || _pin.text.isEmpty) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final result = await ref
        .read(authRepositoryProvider)
        .signInWithBadge(uid: uid, pin: _pin.text);
    if (!mounted) return;
    if (result.ok) {
      // The session is already live; the router moves on its own.
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _failure = result.failure;
      // Clear the field either way. Leaving a rejected PIN on screen on
      // a shared tablet shows the next person a real member's guess.
      _pin.clear();
    });
  }

  /// Deliberately flat: every refusal reads the same. Only a lockout and
  /// an unreachable server differ, and neither tells a stranger anything
  /// about a card they are holding.
  String _failureText(AppLocalizations? l10n) => switch (_failure!) {
        BadgeSignInFailure.locked => l10n?.badgeSignInLocked ??
            'Too many attempts. Wait a few minutes, or sign in with your '
                'e-mail.',
        BadgeSignInFailure.unavailable => l10n?.badgeSignInUnavailable ??
            'Badge sign-in is not reachable right now. Sign in with your '
                'e-mail instead.',
        BadgeSignInFailure.refused => l10n?.badgeSignInRefused ??
            'That did not work. Check the badge and the PIN, or sign in '
                'with your e-mail.',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final who = _who;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n?.badgeSignInTitle ?? 'Sign in with your badge',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (who == null) ..._scanStep(l10n) else ..._pinStep(l10n, who),
          if (_failure != null) ...[
            const SizedBox(height: 16),
            Text(
              _failureText(l10n),
              key: const ValueKey('badge-signin-error'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n?.badgeSignInUseEmail ?? 'Use my e-mail instead'),
          ),
        ],
      ),
    );
  }

  List<Widget> _scanStep(AppLocalizations? l10n) => [
        Icon(
          Icons.contactless_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          _reading
              ? (l10n?.badgeSignInTapPrompt ?? 'Hold your badge against the '
                  'phone.')
              : (l10n?.badgeSignInNoReader ?? 'No badge reader is available '
                  'on this device.'),
          key: const ValueKey('badge-signin-prompt'),
          textAlign: TextAlign.center,
        ),
        if (!_reading && _failure == BadgeSignInFailure.unavailable) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey('badge-signin-retry'),
            onPressed: _busy ? null : _scan,
            child: Text(l10n?.badgeSignInRetry ?? 'Try again'),
          ),
        ],
      ];

  List<Widget> _pinStep(AppLocalizations? l10n, BadgeIdentity who) => [
        // Greeting them by name is the whole reason the steps are split.
        Text(
          l10n?.badgeSignInHello(who.displayName) ?? 'Hello ${who.displayName}',
          key: const ValueKey('badge-signin-hello'),
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('badge-signin-pin'),
          controller: _pin,
          focusNode: _pinFocus,
          obscureText: true,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: l10n?.badgeSignInPinLabel ?? 'Your PIN',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('badge-signin-submit'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n?.badgeSignInButton ?? 'Sign in'),
        ),
      ];
}
