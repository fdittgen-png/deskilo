// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2870 — the setup step "name, country and time zone" confirms the
// workspace's locale and its language through the two writes the settings
// screen's own import path makes. Not the settings form's whole Save: that
// payload also carries the invitation templates, the address and the new
// member defaults, which this step neither shows nor may send back.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/data/json_reader.dart';
import '../domain/workspace.dart';
import '../domain/workspace_identity_repository.dart';
import '../providers/workspace_providers.dart';

part 'save_workspace_basics.g.dart';

/// What the basics step lets the owner confirm.
class WorkspaceBasics {
  const WorkspaceBasics({
    required this.countryCode,
    required this.currencyCode,
    required this.timezone,
    required this.language,
  });

  final String countryCode;
  final String currencyCode;
  final String timezone;

  /// The workspace's language; '' leaves it unset.
  final String language;

  /// The answers as the step's draft keeps them (#2869).
  Map<String, Object?> toDraft() => {
    'country_code': countryCode,
    'currency_code': currencyCode,
    'timezone': timezone,
    'language': language,
  };

  /// A draft's answers over [stored]: an answer the draft does not hold
  /// keeps the stored one.
  static WorkspaceBasics fromDraft(
    Map<String, Object?> draft,
    WorkspaceBasics stored,
  ) {
    final r = JsonReader(draft, context: 'setup draft basics');
    return WorkspaceBasics(
      countryCode: r.stringOr('country_code', stored.countryCode),
      currencyCode: r.stringOr('currency_code', stored.currencyCode),
      timezone: r.stringOr('timezone', stored.timezone),
      language: r.stringOr('language', stored.language),
    );
  }
}

class SaveWorkspaceBasics {
  const SaveWorkspaceBasics(this._repository);
  final WorkspaceIdentityRepository _repository;

  /// Stores [basics] on [stored]'s row; the language is written only when
  /// it changed. Throws whatever the repository throws.
  Future<void> save(Workspace stored, WorkspaceBasics basics) async {
    await _repository.updateWorkspaceLocale(
      stored.id,
      countryCode: basics.countryCode,
      currencyCode: basics.currencyCode.trim(),
      timezone: basics.timezone.trim(),
    );
    if (basics.language != stored.defaultLocale) {
      await _repository.setWorkspaceLanguage(stored.id, basics.language);
    }
  }
}

/// #2870 — the basics step's save.
@riverpod
SaveWorkspaceBasics saveWorkspaceBasics(Ref ref) =>
    SaveWorkspaceBasics(ref.watch(workspaceRepositoryProvider));
