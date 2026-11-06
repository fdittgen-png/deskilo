// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3335 — settling an e-invoice submission whose outcome is `uncertain` by
// hand. The upload may have landed and the answer was lost; only a person
// with the send authority, with a reason and the evidence they checked
// (the platform's own record), may say what became of it. The server
// records the actor, refuses a second resolution and re-checks the
// authority; these are the rules the form applies before it asks.

/// What the person established about the submission.
enum EInvoiceResolution {
  /// The platform took the upload (optionally: and then refused the
  /// document — a verdict beside the upload, not a failed transport).
  accepted,

  /// The platform affirmatively refused the upload.
  rejected,

  /// Nothing reached the platform: the same record may be sent again.
  failed,
}

/// What is missing from a resolution.
enum EInvoiceResolutionProblem { reason, evidence }

/// The widest a reason or evidence may be, as the server cuts it.
const int einvoiceReasonWidth = 300;
const int einvoiceEvidenceWidth = 1000;

/// The first thing missing, or null when the resolution may be sent.
EInvoiceResolutionProblem? einvoiceResolutionProblem({
  required String reason,
  required String evidence,
}) {
  if (reason.trim().isEmpty) return EInvoiceResolutionProblem.reason;
  if (evidence.trim().isEmpty) return EInvoiceResolutionProblem.evidence;
  return null;
}

/// How the server answered a resolution.
class EInvoiceResolveResult {
  const EInvoiceResolveResult({required this.resolved, this.error = ''});

  /// The submission is now settled as asked.
  final bool resolved;

  /// '' when resolved; else why not (`not_deployed`, `already_settled`, the
  /// server's refusal key).
  final String error;
}
