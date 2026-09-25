// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1650 — what the person came to do, typed, so the app can finish it
// after sign-in, verification and consent instead of landing everybody
// on the Reserve hub.
//
// An intent is a requested ACTION and an immutable TARGET: open this
// screen, join a space, create one, connect this installation, reach
// this account page. It is never a URL somebody handed the app and never
// a claim about a role — the route classes say what a location is, the
// server says what the person may do there. What it carries is safe to
// write to the device: a hint typed by the person (a name, never used to
// select anything) and a target id. An invitation code, an OAuth code,
// a PKCE verifier, a one-time password are not targets and are refused
// at the door: [EntryIntent.open] rejects a location that carries one,
// and no constructor takes one.
import 'route_classes.dart';

/// What was asked for.
enum EntryPurpose {
  /// The app's home: [kDefaultHome].
  defaultEntry,

  /// A registered route the person asked for before they could open it.
  open,

  /// Join a space by invitation. The code itself is NOT retained (it is
  /// the secret that redeems a membership); the person pastes it again.
  join,

  /// Create a space.
  create,

  /// Connect this device to an organisation's server — a non-secret
  /// endpoint, chosen on the Server screen.
  connectInstallation,

  /// One of the account's own pages.
  account,

  /// A consent or an action confirmation referenced by an outside
  /// caller (MCP, #1607). No route serves these yet, so they resolve to
  /// nothing: the caller registers its real route when it exists.
  consentReference,
  actionConfirmation,
}

/// The account pages an intent may name — by section, not by path.
enum AccountSection { profiles, linkedAccounts, privacy, consentReview }

/// Query parameters a resumed location may keep: each is a display
/// choice, none is a credential. Anything else is dropped with the
/// location.
const Set<String> kResumableQueryKeys = {'topic', 'anchor', 'review'};

/// Words that mark a credential wherever they appear in a location. A
/// location carrying one is refused whole rather than cleaned: a URL
/// with a token in it was not a place the person meant to come back to.
const List<String> kCredentialCanaries = [
  'code',
  'token',
  'otp',
  'verifier',
  'pkce',
  'secret',
  'password',
  'state',
];

/// One continuation. [id] tells two apart: a late answer for the first
/// never overwrites the second.
final class EntryIntent {
  const EntryIntent._(
    this.id,
    this.purpose, {
    this.target,
    this.hint,
  });

  const EntryIntent.defaultEntry(String id)
      : this._(id, EntryPurpose.defaultEntry);

  /// [location] is the validated path (see [validatedLocation]); the
  /// caller passes what that returned, never the raw request.
  const EntryIntent.openValidated(String id, String location)
      : this._(id, EntryPurpose.open, target: location);

  /// [workspaceHint] is what the person said the space was called —
  /// shown back to them, never matched against anything.
  const EntryIntent.join(String id, {String? workspaceHint})
      : this._(id, EntryPurpose.join, hint: workspaceHint);

  const EntryIntent.create(String id) : this._(id, EntryPurpose.create);

  /// [host] is the endpoint's host, as the Server screen verified it.
  const EntryIntent.connectInstallation(String id, {required String host})
      : this._(id, EntryPurpose.connectInstallation, target: host);

  /// Not const: the target is the section's name, which a const redirect
  /// cannot compute.
  EntryIntent.account(String id, AccountSection section)
      : this._(id, EntryPurpose.account, target: section.name);

  const EntryIntent.consentReference(String id, {required String reference})
      : this._(id, EntryPurpose.consentReference, target: reference);

  const EntryIntent.actionConfirmation(String id, {required String reference})
      : this._(id, EntryPurpose.actionConfirmation, target: reference);

  final String id;
  final EntryPurpose purpose;

  /// The immutable target: a validated route for [EntryPurpose.open], a
  /// host, an account section, an outside reference. Never a name.
  final String? target;

  /// Unverified, for display only.
  final String? hint;

  /// The route this intent opens once the facts allow — or null when no
  /// current route serves it, which the router treats as "nothing asked".
  String? get destination => switch (purpose) {
        EntryPurpose.defaultEntry => kDefaultHome,
        EntryPurpose.open => target,
        EntryPurpose.join || EntryPurpose.create => '/onboarding',
        EntryPurpose.connectInstallation => '/server',
        EntryPurpose.account => switch (AccountSection.values
            .where((s) => s.name == target)
            .firstOrNull) {
            AccountSection.profiles => '/profiles',
            AccountSection.linkedAccounts => '/linked-accounts',
            AccountSection.privacy => '/privacy',
            AccountSection.consentReview => '/consent?review=1',
            null => null,
          },
        EntryPurpose.consentReference ||
        EntryPurpose.actionConfirmation =>
          null,
      };

  /// The path of [raw] when it is a place the app can bring somebody
  /// back to; null otherwise. Accepts a registered route that is not the
  /// sign-in screen itself, with at most the display queries of
  /// [kResumableQueryKeys]; refuses a scheme, a host, a fragment, a
  /// credential canary anywhere, and every unregistered path.
  static String? validatedLocation(String raw) {
    if (raw.isEmpty || !raw.startsWith('/') || raw.startsWith('//')) {
      return null;
    }
    if (raw.contains('\\') || raw.contains('#')) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
    final rule = matchRoute(uri.path);
    if (rule == null || rule.kind == RouteClass.unknown || uri.path == '/auth') {
      return null;
    }
    if (uri.queryParameters.keys.any((k) => !kResumableQueryKeys.contains(k))) {
      return null;
    }
    // The static segments are the registry's own words (`/workspace-code`
    // is a route); what the person supplied is the parameters and the
    // query values, and those are where a credential would sit.
    final want = rule.pattern.split('/');
    final have = uri.path.split('/');
    final supplied = [
      for (var i = 0; i < want.length; i++)
        if (want[i].startsWith(':')) have[i],
      ...uri.queryParameters.values,
    ];
    for (final piece in supplied) {
      final lower = Uri.decodeComponent(piece).toLowerCase();
      for (final canary in kCredentialCanaries) {
        if (RegExp('(^|[^a-z])$canary([^a-z]|\$)').hasMatch(lower)) {
          return null;
        }
      }
    }
    return uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
  }

  @override
  String toString() => 'EntryIntent($id, $purpose'
      '${target == null ? '' : ', $target'}'
      '${hint == null ? '' : ', "$hint"'})';
}
