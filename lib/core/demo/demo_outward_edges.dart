// SPDX-License-Identifier: 0BSD
//
// #1377 — the app's outward edges, in a Demo session.
//
// A payment, an invitation, an e-invoice, a webhook: each of those
// travels through a repository, and inside a Demo scope every repository
// is in memory (ADR 0028) — so they cannot leave, and no check is needed
// to stop them. What is left is the handful of edges the app itself owns:
// saving a file to the device, sharing one, sharing text, opening a link.
//
// Those are not "effects that must be refused" either. Saving a PDF a
// visitor asked for is the demo working. What matters is that they are
// SEEN: a session records what it was asked to send outwards, so a test
// can assert that a journey stayed inside the app, and a future journey
// that wants to show a share can show a simulated one.
import 'dart:typed_data';

/// Everything a session was asked to send outwards, in order.
class DemoOutwardEdges {
  final List<String> savedFiles = [];
  final List<String> sharedFiles = [];
  final List<String> sharedTexts = [];
  final List<Uri> openedLinks = [];

  /// Nothing reached the device or the network.
  bool get nothingLeft =>
      savedFiles.isEmpty &&
      sharedFiles.isEmpty &&
      sharedTexts.isEmpty &&
      openedLinks.isEmpty;

  Future<String?> saveFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    savedFiles.add(fileName);
    return 'demo://$fileName';
  }

  Future<void> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? text,
  }) async {
    sharedFiles.add(fileName);
  }

  Future<void> shareText(String text) async => sharedTexts.add(text);

  Future<bool> openLink(Uri uri) async {
    openedLinks.add(uri);
    return true;
  }
}
