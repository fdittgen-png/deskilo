// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../auth/domain/second_factor.dart';
import '../../application/eligibility_review.dart';
import '../../domain/mcp_context.dart';

/// Reaches aal2 with the person's authenticator app: enrolls one when
/// there is none, then verifies a code. Pops true only when the server
/// accepted the code.
class SecondFactorSheet extends StatefulWidget {
  const SecondFactorSheet({super.key, required this.review, this.scope});
  final EligibilityReview review;

  /// The installation whose session is verified; null for this screen's.
  final McpInstanceRef? scope;

  @override
  State<SecondFactorSheet> createState() => _SecondFactorSheetState();
}

class _SecondFactorSheetState extends State<SecondFactorSheet> {
  final _code = TextEditingController();
  String? _factorId;
  TotpEnrollment? _enrollment;
  bool _busy = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await runGuarded(
      context,
      domain: 'mcp',
      message: 'second factor setup failed',
      action: () async {
        final state = await widget.review.secondFactor(widget.scope);
        if (state.verifiedTotpId != null) {
          _factorId = state.verifiedTotpId;
        } else {
          final e = await widget.review.enroll(widget.scope);
          _enrollment = e;
          _factorId = e.factorId;
        }
      },
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _verify() async {
    final id = _factorId;
    if (id == null || _busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    var ok = false;
    try {
      await widget.review.verify(id, _code.text.trim(), widget.scope);
      ok = true;
    } on Object catch (error, stack) {
      // trace-exempt: a wrong code is the person's to retry, said below.
      debugPrintStack(stackTrace: stack, label: '$error');
    }
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = _enrollment;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.mfaTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (e != null) ...[
            Text(l10n.mfaEnroll),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: QrImageView(
                data: e.uri,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
            SelectableText(
              e.secret,
              key: const ValueKey('mfa-secret'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          TextField(
            key: const ValueKey('mfa-code'),
            controller: _code,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: l10n.mfaCode,
              errorText: _failed ? (l10n.mfaWrong) : null,
            ),
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const ValueKey('mfa-verify'),
            onPressed: _busy || _factorId == null ? null : _verify,
            child: Text(l10n.mfaVerify),
          ),
        ],
      ),
    );
  }
}
