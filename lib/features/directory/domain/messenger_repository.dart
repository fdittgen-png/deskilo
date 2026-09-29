// SPDX-License-Identifier: AGPL-3.0-or-later
import 'messenger.dart';

/// #1824 — the context-bound messenger on ONE server.
///
/// One instance per server: the unified inbox asks every connected
/// server's instance and merges the answers (`mergeInboxes`). A forward
/// never crosses servers — the source and the target are written in one
/// transaction on the server both live on.
abstract interface class MessengerRepository {
  /// `my_inbox`: every conversation I take part in on this server.
  Future<List<Map<String, dynamic>>> inbox();

  // ── inquiries ─────────────────────────────────────────────────────
  Future<List<HostRosterEntry>> hostRoster(String workspace);
  Future<String> startInquiry(String workspace, String body);
  Future<String> sendInquiryMessage(String inquiry, String body);
  Future<List<InquirySummary>> myInquiries();
  Future<List<InquirySummary>> workspaceInquiries(String workspace);
  Future<List<ContextMessage>> inquiryMessages(
    String inquiry, {
    DateTime? beforeAt,
    String? beforeId,
  });
  Future<void> markInquiryRead(String inquiry);
  Future<void> closeInquiry(String inquiry);

  // ── forwarding and history ────────────────────────────────────────
  Future<String> forward({
    required MessageKind kind,
    required String messageId,
    required MessageContextKind targetKind,
    required String targetId,
  });
  Future<void> setForwardLock(MessageKind kind, String messageId, bool locked);
  Future<List<MessageEvent>> history(MessageKind kind, String messageId);

  /// [kind] names the CONTEXT (`conversation | account_conversation |
  /// inquiry`), the words a forward target uses.
  Future<void> recordScreenCapture(MessageContextKind kind, String contextId);

  // ── account messages ──────────────────────────────────────────────
  Future<List<ContextMessage>> accountMessages(
    String conversation, {
    DateTime? beforeAt,
    String? beforeId,
  });
  Future<String> sendAccountMessage(String recipient, String body);
  Future<void> markAccountConversationRead(String conversation);
  Future<void> deleteAccountMessage(String message);

  // ── a space conversation read from the unified inbox ──────────────
  Future<List<ContextMessage>> spaceMessages(String conversation);
  Future<void> sendSpaceMessage(String conversation, String body);
  Future<void> markSpaceConversationRead(String conversation);
}
