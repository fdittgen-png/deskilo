// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3961 — where the app leaves for the provider's approval page: the link
// launcher opens it outside the app; the demonstration overrides this seam
// with a page of its own that stands in for the provider's.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/links/link_launcher.dart';

/// Takes the member to the provider's page for the order at [approveUrl].
typedef PaymentApproval = Future<void> Function(
  BuildContext context,
  Uri approveUrl,
);

final paymentApprovalProvider = Provider<PaymentApproval>(
  (ref) =>
      (context, approveUrl) async => ref.read(linkLauncherProvider)(approveUrl),
);
