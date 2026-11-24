// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4414 -- a stock read that failed is shown by the shared read-failure view
// (lib/core/ui/async_read_body.dart): whether the connection, the access or
// the read failed, and Try again. The keys stay each section's own
// (`<name>-failed`, `<name>-retry`), as the screens and their tests name them.
import 'package:flutter/material.dart';

import '../../../core/ui/async_read_body.dart';

/// The failed read of [error] in the section [keyName], with [onRetry].
class StockReadFailed extends StatelessWidget {
  const StockReadFailed({
    super.key,
    required this.keyName,
    required this.error,
    required this.onRetry,
  });

  final String keyName;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: ValueKey('$keyName-failed'),
    child: ReadFailureBanner(
      error: error,
      onRetry: onRetry,
      retryKey: ValueKey('$keyName-retry'),
    ),
  );
}
