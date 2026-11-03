// SPDX-License-Identifier: AGPL-3.0-or-later
// #2494 — what the member profile's tiles read, gathered once by the page.
// Split out of member_page (was a part file).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/booking_policies.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/domain/workspace_permission.dart';

/// What the page's tiles read, gathered once by the page's build.
class MemberPageContext {
  const MemberPageContext({
    required this.context,
    required this.ref,
    required this.member,
    required this.name,
    required this.l10n,
    required this.me,
    required this.features,
    required this.perms,
    required this.email,
    required this.policies,
    required this.isSelf,
    required this.active,
    required this.pending,
    required this.canAdmin,
    required this.isOwner,
    required this.whatsappUri,
    required this.canMessage,
    required this.servicesOn,
    required this.reportsOn,
    required this.kioskOn,
    required this.coOwnerOn,
    required this.levelOn,
    required this.rolesOn,
    required this.negotiationVisible,
  });

  final BuildContext context;
  final WidgetRef ref;
  final Member member;
  final String name;
  final AppLocalizations l10n;
  final Member? me;
  final Set<WorkspaceFeature> features;
  final Set<WorkspacePermission> perms;
  final String email;
  final BookingPolicies policies;
  final bool isSelf;
  final bool active;
  final bool pending;
  final bool canAdmin;
  final bool isOwner;
  final Uri? whatsappUri;
  final bool canMessage;
  final bool servicesOn;
  final bool reportsOn;
  final bool kioskOn;
  final bool coOwnerOn;
  final bool levelOn;
  final bool rolesOn;
  final bool negotiationVisible;

  /// Opens [uri] with the platform; a refusal is traced and told.
  Future<void> launch(Uri uri) async {
    try {
      final handled = await ref.read(linkLauncherProvider)(uri);
      if (!handled) throw StateError('no handler for $uri');
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'members',
        'link launch failed',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      AppSnack.error(context, l10n.workspaceGenericError);
    }
  }
}
