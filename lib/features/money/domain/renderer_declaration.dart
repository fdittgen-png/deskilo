// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3336 (0694) — what this app says about itself when it hands a document to
// the server: which renderer produced it and which version of the app. It is
// DECLARED, not proven: the server keeps it apart from what it established
// itself (the actor, the digest of the bytes) and never promotes it to proof.
// Empty parts are left out, so an app that cannot tell its version claims none.
class RendererDeclaration {
  const RendererDeclaration({this.renderer = '', this.appVersion = ''});

  /// The builder that produced the document (a format name such as `facturX`).
  final String renderer;

  /// The installed app version, from the one source the About screen reads.
  final String appVersion;

  Map<String, String> toJson() => {
    if (renderer.isNotEmpty) 'renderer': renderer,
    if (appVersion.isNotEmpty) 'app_version': appVersion,
  };
}
