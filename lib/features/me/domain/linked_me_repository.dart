// SPDX-License-Identifier: AGPL-3.0-or-later
import 'my_spaces.dart';
import 'visibility.dart';

/// The account layer's calls on a linked server: each is made with that
/// server's own session, for the account I have there. [MeRepository] is
/// about this server only.
abstract interface class LinkedMeRepository {
  /// My spaces on the linked server [source].
  Future<List<LinkedSpace>> spaces(String source);

  /// `my_visibility()` on [source]: what people on that server see of me.
  Future<MyVisibility> visibility(String source);

  /// `set_visibility` on [source].
  Future<void> setVisibility(
    String source,
    VisibilityField field,
    FieldAudience audience,
  );
}
