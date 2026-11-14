// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3913 — a place on another server whose membership status this version
// cannot read says so; it is never shown as "no membership".
import 'package:deskilo/features/me/domain/personal_workspace_refs.dart';
import 'package:deskilo/features/me/presentation/personal_refs_section.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('an unknown status is said as unreadable, not as no membership', () {
    const unknown = PersonalWorkspaceRef(
      networkId: 'n1',
      hostedHere: false,
      freshness: RefFreshness.local,
      statusUnknown: true,
    );
    const none = PersonalWorkspaceRef(
      networkId: 'n2',
      hostedHere: false,
      freshness: RefFreshness.local,
    );
    expect(PersonalRefsSection.detail(l10n, unknown), l10n.meRefStatusUnknown);
    expect(PersonalRefsSection.detail(l10n, none), l10n.meRefNoRelationship);
  });
}
