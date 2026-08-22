// SPDX-License-Identifier: 0BSD
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';

// #587 — the erase confirmations announce the audit substitution while
// planObjectDelete is on (referenced bookings survive as a text
// snapshot, open ones are cancelled) and keep the historic wording off.

bool _auditOn(WidgetRef ref) => ref
    .read(enabledFeaturesSyncProvider)
    .contains(WorkspaceFeature.planObjectDelete);

String deleteElementConfirmText(WidgetRef ref, AppLocalizations? l10n) =>
    _auditOn(ref)
        ? (l10n?.editorDeleteElementConfirmAudit ??
            'Delete this element? Anything placed on it is removed too. '
                'Bookings that reference it keep a text snapshot for '
                'audits; open bookings are cancelled.')
        : (l10n?.editorDeleteElementConfirm ??
            'Delete this element? Anything placed on it is removed too.');

String deleteLevelConfirmText(WidgetRef ref, AppLocalizations? l10n) =>
    _auditOn(ref)
        ? (l10n?.editorDeleteLevelConfirmAudit ??
            'Delete this level? All offices, desks and seats on it are '
                'removed. Bookings that reference them keep a text '
                'snapshot for audits; open bookings are cancelled.')
        : (l10n?.editorDeleteLevelConfirm ??
            'Delete this level? All offices, desks and seats on it are '
                'removed.');
