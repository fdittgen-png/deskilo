// SPDX-License-Identifier: 0BSD
//
// #1289 — the one place a brand seed arriving from outside is decided.
//
// A questionnaire's document, an imported workspace XML and (later) a
// picker all hand over a colour somebody chose elsewhere. Before it is
// stored it is measured, so a document cannot hand a space a palette its
// members cannot read.
//
// The measurement itself is `DeskiloTheme.refusals` — the same checker
// the accessibility lint runs over the shipped schemes — and it needs
// Flutter, which this layer may not import. So the caller passes it in:
// the decision (measure, then write or refuse) stays pure Dart and
// testable without a widget, and there is still one implementation of
// the check.
import '../domain/workspace_branding.dart';
import '../domain/workspace_repository.dart';

/// What a candidate seed would make unreadable: the pairs, empty when it
/// may be used. `DeskiloTheme.refusals` is the implementation.
typedef BrandSeedCheck = List<String> Function(int argb);

/// Writes [brandColor] (`#RRGGBB`) as the workspace's seed, or returns
/// the first pair that would be unreadable and writes nothing.
///
/// Returns an empty string when the colour was applied, and when the
/// document carried none or carried something that is not a colour —
/// there is nothing to refuse and nothing to say.
Future<String> applyImportedBrandSeed(
  WorkspaceRepository repository,
  String workspaceId,
  String? brandColor, {
  required BrandSeedCheck check,
}) async {
  final argb = parseHexColor(brandColor);
  if (argb == null) return '';
  final refusals = check(argb);
  if (refusals.isNotEmpty) return refusals.first;
  await repository.setWorkspaceBranding(
    workspaceId,
    {BrandingKeys.seedColor: hexOfColor(argb)},
  );
  return '';
}
