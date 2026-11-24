// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4409 — the public page as the editors hold it: a typed draft read from
// the stored document, edited with copyWith, and turned back into the
// patch at the boundary. The document's keys are named here and in
// public_workspace.dart's field lists, nowhere in a widget.
import 'directory_location.dart';
import 'public_facets.dart';
import 'public_workspace.dart';

const _openingHours = 'opening_hours';
const _name = 'name';

/// The writable values of a stored public page. A text field the document
/// does not hold is null; an editor writes what was typed, the empty text
/// included. Fields the app does not know are never read, so they never
/// join a patch: the server keeps them as they are.
class PublicationDraft {
  const PublicationDraft({
    this.hostType,
    this.texts = const {},
    this.place,
    this.amenities,
    this.accessibility,
    this.hoursNote,
  });

  /// The draft of a `publication.page.read` document, or of the projection
  /// a save answers. Coordinates are numeric even when a legacy projection
  /// stores text.
  factory PublicationDraft.fromDocument(Map<String, Object?> document) =>
      PublicationDraft(
        hostType: _text(document[publicHostField]),
        texts: Map.unmodifiable({
          for (final field in publicPageFields)
            if (document.containsKey(field)) field: _text(document[field]),
        }),
        place: publicPlaceOf(document),
        amenities: _list(document, PublicFacets.amenities),
        accessibility: _list(document, PublicFacets.accessibility),
        hoursNote: PublicOpeningHours.read(document[_openingHours])?.note,
      );

  /// The draft of a page answer `{published, document, following}`.
  factory PublicationDraft.fromPage(Map<String, Object?> page) =>
      PublicationDraft.fromDocument(
        Map<String, Object?>.from(page['document'] as Map),
      );

  /// `host_type`: association, company or person.
  final String? hostType;

  /// The text fields of [publicPageFields] the document holds.
  final Map<String, String?> texts;

  /// Where the business is on the map.
  final DirectoryLocation? place;

  /// The facet ids, as stored.
  final List<String>? amenities, accessibility;

  /// The opening-hours note of a business without bookable places.
  final String? hoursNote;

  /// [field] of [publicPageFields], or null when the document has none.
  String? text(String field) => texts[field];

  /// The facet ids of [field], `amenities` or `accessibility`.
  List<String>? facet(String field) =>
      field == PublicFacets.amenities ? amenities : accessibility;

  PublicationDraft copyWith({
    String? hostType,
    Map<String, String>? texts,
    List<String>? amenities,
    List<String>? accessibility,
    String? hoursNote,
  }) => PublicationDraft(
    hostType: hostType ?? this.hostType,
    texts: texts == null
        ? this.texts
        : Map.unmodifiable({...this.texts, ...texts}),
    place: place,
    amenities: amenities ?? this.amenities,
    accessibility: accessibility ?? this.accessibility,
    hoursNote: hoursNote ?? this.hoursNote,
  );

  /// The facet [field] set to [ids].
  PublicationDraft withFacet(String field, List<String> ids) =>
      field == PublicFacets.amenities
      ? copyWith(amenities: ids)
      : copyWith(accessibility: ids);

  /// The draft with [place], null clearing the stored one.
  PublicationDraft withPlace(DirectoryLocation? place) => PublicationDraft(
    hostType: hostType,
    texts: texts,
    place: place,
    amenities: amenities,
    accessibility: accessibility,
    hoursNote: hoursNote,
  );

  /// Whether [field]'s facet differs from [other]'s.
  bool facetDiffers(PublicationDraft other, String field) =>
      !_sameList(facet(field), other.facet(field));

  /// The patch from this stored draft to [edited]: only what differs is
  /// sent, so another editor's fields and the ones the app does not know
  /// stay on the server. A moved place sends both coordinates.
  PublicationPatch diff(PublicationDraft edited) => PublicationPatch.patch({
    if (edited.hostType != hostType) publicHostField: edited.hostType,
    for (final field in publicPageFields)
      if (edited.texts.containsKey(field) &&
          edited.texts[field] != texts[field])
        field: edited.texts[field],
    if (!_sameList(edited.amenities, amenities))
      PublicFacets.amenities: edited.amenities,
    if (!_sameList(edited.accessibility, accessibility))
      PublicFacets.accessibility: edited.accessibility,
    if (edited.hoursNote != hoursNote) _openingHours: edited.hoursNote,
    if (edited.place?.latitude != place?.latitude ||
        edited.place?.longitude != place?.longitude)
      ...publicPlaceFields(edited.place),
  });
}

/// #2086 — the owner's own page: whether it is published, its draft, the
/// inherited fields that still follow the workspace information, and the
/// page as it reads back.
class OwnPublicPage {
  OwnPublicPage.fromAnswer(Map<String, Object?> answer)
    : published = answer['published'] == true,
      following = publicFollowing(answer),
      offer = PublicWorkspace(
        '',
        '',
        '',
        Map<String, dynamic>.from(answer['document'] as Map),
      ),
      draft = PublicationDraft.fromPage(answer);

  final bool published;
  final Set<String> following;
  final PublicationDraft draft;

  /// The stored document as the public projection reads it.
  final PublicWorkspace offer;

  /// The name the page stores, or null when it names none.
  String? get name => storedPageName(offer);
}

/// The name a stored page or a save's projection holds, or null.
String? storedPageName(PublicWorkspace page) =>
    page.document[_name] is String ? page.document[_name] as String : null;

String? _text(Object? raw) => raw is String ? raw : null;

List<String>? _list(Map<String, Object?> document, String key) {
  final raw = document[key];
  return raw is List
      ? List<String>.unmodifiable(raw.whereType<String>())
      : null;
}

bool _sameList(List<String>? a, List<String>? b) {
  if (a == null || b == null) return a == b;
  return a.length == b.length && a.indexed.every((e) => e.$2 == b[e.$1]);
}
