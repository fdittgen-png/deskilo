// SPDX-License-Identifier: 0BSD
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace.freezed.dart';

/// Rules for the owner-set WhatsApp group link (#231). The prefix is
/// enforced twice with this single constant: the settings-form validator
/// and the 0029 column check (`whatsapp_group ~
/// '^https://chat\.whatsapp\.com/'`) — cross-pinned by test.
abstract final class WhatsappGroupRules {
  /// Every WhatsApp group invite link starts with this — anything else
  /// is not a group invite and is rejected client- AND server-side.
  static const String linkPrefix = 'https://chat.whatsapp.com/';

  /// '' (no group) or a real chat.whatsapp.com invite link.
  static bool isValid(String link) =>
      link.isEmpty || link.startsWith(linkPrefix);
}

/// One coworking community (spec §3). Currency defaults from the country;
/// the owner may override it (decided 2026-07-07).
@freezed
sealed class Workspace with _$Workspace {
  const Workspace._();

  const factory Workspace({
    required String id,
    required String name,
    required String countryCode,
    required String currencyCode,
    required String timezone,
    required String inviteCode,

    /// Per-workspace feature overrides (#146): WorkspaceFeature.name →
    /// bool. Absent key = the feature's registry default (ON); resolve
    /// with [resolveEnabledFeatures].
    @Default(<String, dynamic>{}) Map<String, dynamic> featureFlags,

    /// #513 — the role→permission matrix as stored: role wire name →
    /// list of permission wire names. Absent role key = the defaults
    /// (see workspace_permission.dart). Owners are never stored.
    @Default(<String, dynamic>{}) Map<String, dynamic> rolePermissions,

    /// Workspace-wide developer mode (#419, 0081): admin/owner-set,
    /// applies to every member on every device (realtime-pushed).
    /// Distinct from [environment] — this one only opens the e-invoice
    /// TEST endpoints; a production space may legitimately use them
    /// while rehearsing, and a development space is not sending real
    /// documents anywhere at all.
    @Default(false) bool devMode,

    /// #917 — whether this workspace is REAL. `'dev'` (the default, and
    /// what every workspace that predates 0160 became) says it is a
    /// place to try things out: the app says so on every screen and
    /// every document it prints carries the development watermark.
    /// `'prod'` is a deliberate statement by the owner that the
    /// invoices leaving here are owed.
    @Default('dev') String environment,

    /// Owner-configured payment instructions (#155) as stored — decode
    /// with [PaymentInstructions.fromDb]. Empty = none configured.
    @Default(<String, dynamic>{}) Map<String, dynamic> paymentInstructions,

    /// Owner-set WhatsApp group invite link (#231), shown to members in
    /// the directory (#232); '' = no group configured. Shape-checked
    /// against [WhatsappGroupRules.linkPrefix] (0029 column check).
    @Default('') String whatsappGroup,

    /// Postal address (0060): printed on invoices; owner-edited.
    @Default('') String address,

    /// LEGAL IDENTITY (0069) — what an EN 16931 e-invoice cannot omit.
    /// [vatRegime] is the wire value of `VatRegime` (money domain) and
    /// decides which of the two identifiers is required: category `E`
    /// needs [vatId] (BR-E-02), category `O` needs [legalId] and must NOT
    /// carry a VAT id at all (BR-O-02 / BR-CO-26).
    @Default('not_subject') String vatRegime,

    /// BT-31, the VAT identification number ('FR12345678901').
    @Default('') String vatId,

    /// BT-30, the company register identifier (SIREN/SIRET, HRB, CIF…).
    @Default('') String legalId,

    /// BT-120, why no VAT is charged, in the owner's own words. Category
    /// `E` requires a reason; a VATEX code is added automatically where
    /// the code lists have one.
    @Default('') String taxExemptionReason,

    /// Structured address parts (BT-35/37/38) beside [address], which
    /// stays the free-text block the PDF letterhead prints.
    @Default('') String street,
    @Default('') String city,
    @Default('') String postalCode,

    /// The account VAT is booked to in the FEC export (0072); '' = the
    /// French default 445710. Only the accounting export reads it — the
    /// app books nothing itself.
    @Default('') String vatAccount,

    /// The subscription tariff's VAT rate (#542, 0109) — fee bands and
    /// overage tax at this rate; '' = the workspace default rate.
    @Default('') String subscriptionVatRateId,

    /// Desk fill opacity percentage (0040): 100 = solid (default), lower
    /// makes desks translucent so a level's background photo shows through.
    /// Clamped 20..100 by the column check.
    @Default(100) int deskOpacity,

    /// Owner-configured invitation message template (0049) with {tag}
    /// placeholders (see [InvitationTags]); '' = use the app's localized
    /// default message. Max length enforced by the column check.
    @Default('') String invitationTemplate,

    /// Legal invoice mentions (0094) — legal form, trade register,
    /// payment terms, penalty/indemnity/escompte clauses, insurance and
    /// special mentions. Raw jsonb; typed access via InvoiceLegal.
    @Default(<String, dynamic>{}) Map<String, dynamic> invoiceLegal,

    /// The workspace's own language (0096, e.g. 'fr'); '' = unset →
    /// the sender's app language. Invitations default to it.
    @Default('') String defaultLocale,

    /// Per-locale CUSTOM invitation templates (0096): language code →
    /// template. Absent key → legacy [invitationTemplate] → built-in.
    @Default(<String, dynamic>{}) Map<String, dynamic> invitationTemplates,
  }) = _Workspace;

  /// Desk fill opacity as a 0..1 fraction for the painter.
  double get deskOpacityFraction => deskOpacity / 100;

  /// The group link as a launchable https URI for the directory (#232),
  /// or null when no group is configured.
  Uri? get whatsappGroupUri =>
      whatsappGroup.isEmpty ? null : Uri.tryParse(whatsappGroup);
}

/// #917 — is this workspace real?
///
/// The question has exactly two answers and no default that flatters:
/// a space is a development space until its owner says otherwise. Every
/// surface that can be mistaken for a real one — the app itself, and
/// above all the documents it prints — says which it is.
enum WorkspaceEnvironment {
  development('dev'),
  production('prod');

  const WorkspaceEnvironment(this.wire);

  final String wire;

  static WorkspaceEnvironment fromWire(String? wire) =>
      values.where((e) => e.wire == wire).firstOrNull ?? development;

  bool get isDevelopment => this == WorkspaceEnvironment.development;
}

extension WorkspaceEnvironmentX on Workspace {
  /// The declared environment; anything unknown reads as development.
  WorkspaceEnvironment get env => WorkspaceEnvironment.fromWire(environment);

  /// Shorthand for the many places that only care whether to warn.
  bool get isDevelopment => env.isDevelopment;
}
