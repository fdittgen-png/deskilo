// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'directory_location.dart';
import 'public_facets.dart';

/// One row of `my_reachable_people`: a person I may write to, in
/// one workspace I share with them.
class ReachablePerson {
  const ReachablePerson({
    required this.workspaceId,
    required this.workspaceName,
    required this.id,
    required this.name,
  });

  factory ReachablePerson.fromRow(Object? raw) {
    final r = JsonReader.of(raw, context: 'my_reachable_people');
    return ReachablePerson(
      workspaceId: r.string('workspace_id'),
      workspaceName: r.stringOr('workspace_name'),
      id: r.string('id'),
      name: r.stringOr('name'),
    );
  }

  final String workspaceId, workspaceName, id, name;
}

/// The deliberately public projection, separate from the private workspace.
///
/// [document] is the allow-listed projection the public network adapter
/// produced (#1847): only fields the contract lists, never a raw row.
class PublicWorkspace {
  const PublicWorkspace(this.id, this.source, this.key, this.document);
  final String id, source, key;
  final Map<String, dynamic> document;
  String text(String field) =>
      document[field] is String ? document[field] as String : '';
  String get name => text('name');
  List<String>? get amenities => PublicFacets.read('amenities', document['amenities']);
  List<String>? get accessibility => PublicFacets.read('accessibility', document['accessibility']);
  PublicOpeningHours? get openingHours => PublicOpeningHours.read(document['opening_hours']);
  DirectoryLocation? get location =>
      DirectoryLocation.parse(document['latitude'], document['longitude']);
  double? get latitude => location?.latitude;
  double? get longitude => location?.longitude;
  List<PublicContact> get contacts =>
      (document['contacts'] as List<dynamic>? ?? [])
          .map((e) => PublicContact(Map<String, dynamic>.from(e as Map)))
          .toList();

  /// #3553 — the business's kind codes, the primary one first; none from an
  /// installation that does not publish them.
  List<String> get kinds => [
    for (final k in document['kinds'] as List<Object?>? ?? const [])
      if (k is String) k,
  ];

  /// #3553 — the services the business marked public, in its own order;
  /// none from an installation that does not publish them.
  List<PublicService> get services => [
    for (final s in document['services'] as List<Object?>? ?? const [])
      ?PublicService.read(s),
  ];

  /// #3553 — whether the business takes inquiries; null where the
  /// installation does not say.
  bool? get takesInquiries =>
      document['takes_inquiries'] is bool
      ? document['takes_inquiries'] as bool
      : null;
}

/// #4409 — one contact a public page lists.
extension type const PublicContact(Map<String, dynamic> _row) {
  String get name => _row['name'] as String? ?? '';

  /// The account to write to, when the contact has one.
  String? get userId =>
      _row['user_id'] is String ? _row['user_id'] as String : null;
  bool get owner => _row['owner'] == true;
  bool get available => _row['available'] == true;
}

/// #3553 — what a listed price means for tax: the price contains the tax,
/// a tax is added at the sale, or no tax applies.
enum PublicTaxTreatment { included, excluded, none }

/// #3553 — one service a business publishes: each price in its own
/// currency, never converted.
class PublicService {
  const PublicService({
    required this.name,
    required this.priceMinor,
    required this.currency,
    required this.taxTreatment,
    this.category,
    this.durationMinutes,
  });

  /// The service in a published document, or null when it is not one this
  /// version can show (the contract's codec already refused a malformed
  /// card; a missing field here is a newer shape).
  static PublicService? read(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final price = raw['price_minor'];
    final currency = raw['currency'];
    final tax = PublicTaxTreatment.values
        .where((t) => t.name == raw['tax_treatment'])
        .firstOrNull;
    if (name is! String || price is! int || currency is! String || tax == null) {
      return null;
    }
    final category = raw['category'];
    final duration = raw['duration_minutes'];
    return PublicService(
      name: name,
      priceMinor: price,
      currency: currency,
      taxTreatment: tax,
      category: category is String ? category : null,
      durationMinutes: duration is int ? duration : null,
    );
  }

  final String name;
  final String? category;
  final int? durationMinutes;
  final int priceMinor;
  final String currency;
  final PublicTaxTreatment taxTreatment;
}

/// #2086 — the public fields that have a counterpart in the workspace's
/// own information: until the owner overrides one, it follows that
/// information. Every other public field is only what the owner typed.
const publicInheritedFields = [publicHostField, 'address'];

/// The field naming who runs the space: association, company or person.
const publicHostField = 'host_type';

/// The text fields of a public page the owner writes, beside its host type,
/// in the order the page editor shows them.
const publicPageFields = [
  'description',
  'address',
  'email',
  'phone',
  'website',
  'image_url',
  'plan_url',
  'plans',
];

/// Numeric map coordinates, or nulls that explicitly clear the stored place.
Map<String, Object?> publicPlaceFields(DirectoryLocation? place) => {
  'latitude': place?.latitude,
  'longitude': place?.longitude,
};

/// The stored place of a `publication.page.read` document, if it has one.
DirectoryLocation? publicPlaceOf(Map<String, Object?> document) =>
    DirectoryLocation.parse(document['latitude'], document['longitude']);

/// The inherited fields that follow the workspace information in [page],
/// a `publication.page.read` answer. A page without the marker (an older
/// server) follows nothing: what it stored is what it shows.
Set<String> publicFollowing(Map<String, dynamic> page) {
  final following = page['following'];
  if (following is! Map) return {};
  return {
    for (final field in publicInheritedFields)
      if (following[field] == true) field,
  };
}

/// Explicit write semantics shared by the editor, repository and Demo.
/// An omitted patch field is untouched; null removes it (restoring inheritance
/// for inherited fields); an empty string is a deliberate blank override.
class PublicationPatch {
  PublicationPatch.patch(Map<String, Object?> fields)
    : fields = Map.unmodifiable(fields), mode = PublicationWriteMode.patch;
  PublicationPatch.replace(Map<String, Object?> fields)
    : fields = Map.unmodifiable(fields), mode = PublicationWriteMode.replace;

  final Map<String, Object?> fields;
  final PublicationWriteMode mode;
}

enum PublicationWriteMode { replace, patch }

/// #1847 — the MANAGEMENT interface: the owner authors the public page.
abstract interface class PublicationRepository {
  /// `{published, document, following}` — the owner's own page, draft
  /// included, inherited fields resolved (#2086).
  Future<Map<String, dynamic>> ownPage(String workspace);

  /// #2086 — returns [fields] (every inherited field when null) to the
  /// workspace information; answers the page as [ownPage] does. Never
  /// publishes or withdraws the page.
  Future<Map<String, dynamic>> resetPage(
    String workspace, {
    Set<String>? fields,
  });

  /// Saves and publishes or withdraws; answers the public projection.
  Future<Map<String, dynamic>> savePage(
    String workspace,
    PublicationPatch document, {
    required bool published,
  });
}

/// #1847 — the PARTICIPANT interface: a signed-in account acting for
/// itself — registering an installation in the directory, asking to join.
abstract interface class DirectoryParticipantRepository {
  Future<void> register(String origin, String key);
  Future<void> apply(PublicWorkspace workspace);

  /// #2343 — where [origin] stands with the global directory.
  Future<DirectoryLinkState> linkState(String origin, String key);
}

/// #2343 — a server and the global directory.
enum DirectoryLinkState {
  /// It carries the directory: its published spaces are always listed.
  directory,

  /// Linked: its published spaces are listed.
  linked,

  /// It answers with published spaces this app reads: it can be linked.
  linkable,

  /// It does not answer, or not with spaces this app can read.
  unreachable,
}

abstract interface class AccountContactRepository {
  Future<bool> availability();
  Future<void> setAvailability({required bool value});
  Future<bool> adminVisibility(String workspace, {bool? visible});
  Future<bool> employment(String member, {bool? employed});
  Future<List<Map<String, dynamic>>> search(String query, {String? before});

  /// The people I may write to, one row per shared workspace.
  Future<List<ReachablePerson>> reachablePeople();
  Future<List<Map<String, dynamic>>> conversations({
    DateTime? beforeAt,
    String? beforeId,
  });
  Future<List<Map<String, dynamic>>> messages(
    String conversation, {
    DateTime? beforeAt,
    String? beforeId,
  });
  Future<String?> conversationWith(String recipient);
  Future<String> send(String recipient, String body);
}
