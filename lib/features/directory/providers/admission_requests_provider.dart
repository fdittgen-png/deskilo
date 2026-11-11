// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3683 -- "Ask to join" was sent: a counter the personal home's readers
// watch, so My spaces and "Needs you" show the request at once instead of
// after a reload. The directory owns the fact; Me reads it.
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdmissionRequestsSent extends Notifier<int> {
  @override
  int build() => 0;

  /// A request to join was taken by a server.
  void sent() => state++;
}

final admissionRequestsSentProvider =
    NotifierProvider<AdmissionRequestsSent, int>(AdmissionRequestsSent.new);
