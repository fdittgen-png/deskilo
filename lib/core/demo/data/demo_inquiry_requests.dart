// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3745 -- the first outcome of an inquiry send's request id in the demo, as
// `inquiry_request_outcome` (0721) keeps it: the same content answers it,
// other content is refused, a new id is null.
class DemoInquiryRequests {
  final _first = <String, ({String content, String outcome})>{};

  /// The first outcome of [requestId] for [content], or null when new.
  String? repeat(String? requestId, String content) {
    final first = requestId == null ? null : _first[requestId];
    if (first == null) return null;
    if (first.content != content) {
      throw StateError('this request id was used for another message');
    }
    return first.outcome;
  }

  void remember(String? requestId, String content, String outcome) {
    if (requestId != null) {
      _first[requestId] = (content: content, outcome: outcome);
    }
  }

}
