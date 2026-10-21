// SPDX-License-Identifier: AGPL-3.0-or-later
import '../application/recorder_controller.dart';
import '../guide/guide_session.dart';

/// A guarded command a guide saw: the guide to tell its result, and the
/// recording's own token when one was live.
class GuidedCommand {
  const GuidedCommand(this.guide, this.token, this.guideToken);
  final GuideEventSink guide;
  final OperationToken? token;
  final Object? guideToken;
}
