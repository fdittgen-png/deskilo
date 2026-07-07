// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace.freezed.dart';

/// One coworking community (spec §3). Currency defaults from the country;
/// the owner may override it (decided 2026-07-07).
@freezed
sealed class Workspace with _$Workspace {
  const factory Workspace({
    required String id,
    required String name,
    required String countryCode,
    required String currencyCode,
    required String timezone,
    required String inviteCode,
  }) = _Workspace;
}
