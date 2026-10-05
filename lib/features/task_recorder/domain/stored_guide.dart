// SPDX-License-Identifier: AGPL-3.0-or-later
import '../guide/task_guide.dart';

/// One guide of the library.
class StoredGuide {
  const StoredGuide({required this.id, required this.guide, this.createdAt});

  final String id;
  final TaskGuide guide;
  final DateTime? createdAt;
}
