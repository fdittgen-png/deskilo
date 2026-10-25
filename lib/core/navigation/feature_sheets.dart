// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — a sheet one feature owns, opened from a feature that does not
// import it: the money feature's negotiation card shows who can see the
// deal (the calendar's access sheet), the profile's platform tools open
// the tax reference (money's) and the messenger opens a member's profile
// (the members feature's). The owner's opener is put in the scope's
// overrides by the composition root (lib/app/feature_sheets_wiring.dart);
// unwired, there is none and the entry does nothing.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sheets opened across a feature boundary.
enum FeatureSheet {
  /// Who may see my data and who did (#719), owned by the calendar.
  dataAccess,

  /// The platform's tax reference, editable (#2484), owned by money.
  taxReferenceEditor,
}

/// The openers by sheet, each completing when its sheet is closed; empty
/// until the composition root wires them.
final featureSheetsProvider =
    Provider<Map<FeatureSheet, Future<void> Function(BuildContext, WidgetRef)>>(
      (ref) => const {},
    );

/// Opens [sheet] when its owner is wired; otherwise nothing happens.
Future<void> openFeatureSheet(
  BuildContext context,
  WidgetRef ref,
  FeatureSheet sheet,
) async {
  final open = ref.read(featureSheetsProvider)[sheet];
  if (open != null) await open(context, ref);
}

/// The members feature's opener of a member's profile from anywhere
/// (#695: the member page or the profile sheet, as that feature decides);
/// none until the composition root wires it.
final memberProfileOpenerProvider =
    Provider<
      Future<void> Function(
        BuildContext context,
        WidgetRef ref, {
        required String memberId,
      })?
    >((ref) => null);

/// Opens [memberId]'s profile when its owner is wired; otherwise nothing.
Future<void> openMemberProfile(
  BuildContext context,
  WidgetRef ref, {
  required String memberId,
}) async {
  final open = ref.read(memberProfileOpenerProvider);
  if (open != null) await open(context, ref, memberId: memberId);
}
