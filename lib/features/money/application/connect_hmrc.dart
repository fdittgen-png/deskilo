// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — connecting the space to HMRC: the sign-in page is opened outside the
// app (HMRC asks the person for the password, never us). The Demo's sign-in is
// synthetic: nothing opens.
import '../../../core/links/link_launcher.dart';
import '../domain/hmrc_submission.dart';

class ConnectHmrc {
  const ConnectHmrc(this._repository, this._launch);

  final HmrcRepository _repository;
  final LinkLauncher _launch;

  Future<void> call({
    required String workspaceId,
    required String issuerSiteId,
    required HmrcState state,
  }) async {
    final url = await _repository.startConnect(workspaceId, issuerSiteId);
    if (!state.demo) await _launch(url);
  }
}
