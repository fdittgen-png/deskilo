// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3774 — why an e-mail of the business (a purchase order, a payment
// reminder) was refused, as the send functions record it: the codes this
// server writes itself, a provider's HTTP answer, or anything else, which is
// shown as it came.

/// A recorded refusal reason, read.
sealed class MailRefusal {
  const MailRefusal();

  /// Reads the reason `finish_*` recorded (supabase/functions/_shared/
  /// resend.ts and the send functions write it).
  factory MailRefusal.of(String reason) {
    if (reason == 'mail_not_configured') return const MailRefusalNoSender();
    if (reason == 'invalid_order_mail') return const MailRefusalInvalid();
    final status = RegExp(r'^provider_(\d{3})$').firstMatch(reason)?.group(1);
    if (status != null) return MailRefusalProvider(status);
    return MailRefusalOther(reason);
  }
}

/// The business's sender (its key) was not configured when it was sent.
class MailRefusalNoSender extends MailRefusal {
  const MailRefusalNoSender();
}

/// An address, the subject or the attached letter was not one the
/// transport accepts.
class MailRefusalInvalid extends MailRefusal {
  const MailRefusalInvalid();
}

/// The e-mail provider answered with HTTP [status].
class MailRefusalProvider extends MailRefusal {
  const MailRefusalProvider(this.status);
  final String status;
}

/// Any other reason, shown as it came.
class MailRefusalOther extends MailRefusal {
  const MailRefusalOther(this.text);
  final String text;
}
