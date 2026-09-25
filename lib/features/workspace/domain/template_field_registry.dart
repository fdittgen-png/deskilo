// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1655 — every field a workspace template can carry, and what becomes of
// it: the field-level coverage contract.
//
// `deployable_entities()` says which ENTITIES travel and
// `template_publication_rules()` which may be published; the matrix
// classifies columns and entity keys. None of them says what happens to
// `booking_rules.simultaneous_reservations` when it is absent, whether
// `subscription_vat_rate` is a value or a reference, or why
// `number_sequences.next_value` never travels. This registry does, one
// record per field; `template_coverage_test` fails when a feature, a
// permission, a policy column, a JSON key or an entity has no record. It
// DESCRIBES; the rules stay in the server's transfer functions.
//
// Field ids are stable paths: `workspace.<column>[.<key>…]`,
// `tables.<table>[].<column>[…]`, `floor_plan[].offices[].desks[]…`,
// `template.<meta>`. `[]` is a row addressed by its natural key at
// inspection time; `{locale}` is any locale. Two same-named rows under
// different parents stay distinct because the path carries the parents.
// Pure Dart with no Flutter reach (`dart run` compiles it for the SQL
// generator): enum wire values and lexicon terms are literals here, held
// equal to the compiled sources by `template_coverage_test`, both ways.
import 'workspace_feature.dart';
import 'workspace_process.dart';

/// What a template may do with a PRESENT value; [TemplateAbsent] says what
/// an absent one means ("default with versioned origin" is the pair:
/// literal when written, the product's or registry's default when not).
/// `unsupported` is a real setting this version's transport does not carry;
/// `never` is never carried, with the reason.
enum TemplatePortability { literal, localBinding, reference, unsupported, never }

/// What an ABSENT field means on the target.
enum TemplateAbsent { inherit, productDefault, registryDefault, required }

enum TemplateFieldType {
  text, integer, decimal, boolean, minutes, cents, percent, date,
  enumeration, list, map, color, locale, tree,
}

class TemplateFieldSpec {
  const TemplateFieldSpec({
    required this.id,
    required this.entity,
    required this.type,
    this.portability = TemplatePortability.literal,
    this.absent = TemplateAbsent.inherit,
    this.naturalKey,
    this.values = const [],
    this.min,
    this.max,
    this.dependsOn = const [],
    this.bindings = const [],
    this.reason,
  });

  final String id;

  /// A `deployable_entities()` key, or `workspace` / `template` for what
  /// no entity carries.
  final String entity;
  final TemplateFieldType type;
  final TemplatePortability portability;
  final TemplateAbsent absent;

  /// For a row field: the natural key of its row (`entity_row_key`).
  final String? naturalKey;
  final List<String> values;
  final int? min;
  final int? max;

  /// Field ids or entity keys this one needs on the target.
  final List<String> dependsOn;

  /// Natural keys the target must be able to resolve (`vat_rates.label`).
  final List<String> bindings;
  final String? reason;

  /// The entity's group and merge policy are the server's
  /// (`deployable_entities()`), read at inspection time, never restated.
  String get process => entityProcesses[entity] ?? 'operations';
}

/// The business process each entity is configured in (`workspaceProcesses`);
/// `workspace` and `template` are the two homes of what no entity carries.
const Map<String, String> entityProcesses = {
  'identity': 'operations', 'vat': 'billingPayments', 'tariffs': 'membershipCommerce',
  'services': 'membershipCommerce', 'packages': 'membershipCommerce',
  'credit_products': 'membershipCommerce', 'accessories': 'spaceManagement',
  'floor_plan': 'spaceManagement', 'sites': 'spaceManagement',
  'booking_rules': 'reservationsUsage', 'validation_rules': 'coordination',
  'roles': 'workspaceAccess', 'workspace_roles': 'workspaceAccess', 'features': 'operations',
  'payment_instructions': 'billingPayments', 'reminders': 'billingPayments',
  'document_design': 'documentsInformation', 'document_links': 'documentsInformation',
  'number_sequences': 'billingPayments', 'closure_days': 'coordination',
  'invitations': 'workspaceAccess', 'lexicon': 'operations', 'branding': 'operations',
  'field_definitions': 'workspaceAccess', 'workspace': 'operations', 'template': 'operations',
};

const _never = TemplatePortability.never;
const _ref = TemplatePortability.reference;
const _bind = TemplatePortability.localBinding;
const _product = TemplateAbsent.productDefault;

/// Wire values pinned by the coverage lint against the compiled enums.
const templateGranularities = ['flexible', 'half_day', 'minutes_5', 'minutes_15',
  'minutes_30', 'minutes_60', 'full_day', 'hours'];
const templateOutsideHoursModes = ['off', 'free', 'charged', 'walkup_only'];
const templateLegendProfiles = ['full', 'simple'];
const templatePermissions = ['manageRoles', 'manageMembers', 'manageValidation',
  'workspaceSettings', 'issueInvoices', 'viewFinances', 'manageDocuments', 'manageServices',
  'approveExpenses', 'viewNegotiations', 'manageNegotiations', 'paymentTermsEdit',
  'manageSites', 'manageBilling', 'manageReservations', 'operateKiosk', 'exportData',
  'designDocuments', 'viewPersonalData', 'manageIntegrations', 'manageConfiguration',
  'deployToProd', 'deployToDev', 'accessProd'];

/// The overridable terms of `lexiconAllowList`, pinned by the same lint.
const templateLexiconTerms = ['legendFree', 'legendReserved', 'legendOccupied', 'legendMine',
  'legendBlocked', 'legendClosed', 'legendUnavailable', 'reserveClosedShort', 'spaceKindSeat',
  'spaceKindDesk', 'spaceKindOffice', 'spaceKindLevel', 'levelDetail', 'deskDetail', 'tabPlan',
  'tabCalendar', 'tabEvents', 'tabMoney', 'directoryTitle', 'messagesTitle',
  'shellReserveButton', 'planReserveButton', 'levelReserveButton', 'planMorningChip',
  'planAfternoonChip', 'planFromLabel', 'planDurationLabel', 'planBookForLabel',
  'planCheckInTitle', 'planCheckInButton', 'reserveMonthView', 'reserveDayView',
  'reserveWeekView', 'reserveFullDayChip'];

const _ownIdentity = "the source's own identity";
const _people = 'names people, who do not exist where a template is applied';
const _int = TemplateFieldType.integer;
const _bool = TemplateFieldType.boolean;
const _text = TemplateFieldType.text;
const _cents = TemplateFieldType.cents;

TemplateFieldSpec _f(String id, String entity, TemplateFieldType type,
        {TemplatePortability p = TemplatePortability.literal,
        TemplateAbsent absent = TemplateAbsent.inherit,
        String? key, List<String> values = const [], int? min, int? max,
        List<String> dependsOn = const [], List<String> bindings = const [],
        String? reason}) =>
    TemplateFieldSpec(id: id, entity: entity, type: type, portability: p,
        absent: absent, naturalKey: key, values: values, min: min, max: max,
        dependsOn: dependsOn, bindings: bindings, reason: reason);

/// The identity the target keeps for itself, and what never leaves a space.
List<TemplateFieldSpec> _workspaceColumns() => [
      for (final c in ['name', 'country_code', 'currency_code', 'timezone'])
        _f('workspace.$c', 'workspace', _text, p: _bind,
            absent: TemplateAbsent.required, reason: 'the new space says who and where it is'),
      _f('workspace.invite_code', 'workspace', _text, p: _never, reason: 'a secret'),
      for (final c in ['id', 'created_by', 'created_at', 'environment', 'pair_id',
        'created_datetime', 'modified_datetime', 'company_id', 'site_id',
        'created_by_user', 'modified_by_user'])
        _f('workspace.$c', 'workspace', _text, p: _never, reason: 'which row and which twin this is'),
      _f('workspace.dev_mode', 'workspace', _bool, p: _never, reason: "this space's own switch"),
      _f('workspace.accessory_supplements_since', 'workspace', TemplateFieldType.date,
          p: _never, reason: "a date in this space's history"),
      for (final c in ['address', 'street', 'postal_code', 'city', 'vat_id', 'legal_id',
        'tax_exemption_reason', 'vat_account', 'invoice_legal', 'whatsapp_group'])
        _f('workspace.$c', 'identity', _text, p: _never, reason: _ownIdentity),
      _f('workspace.default_locale', 'identity', TemplateFieldType.locale, absent: _product),
      _f('workspace.vat_regime', 'identity', TemplateFieldType.enumeration, absent: _product),
      _f('workspace.subscription_vat_rate', 'vat', _text, p: _ref, bindings: ['vat_rates.label']),
      _f('workspace.desk_opacity', 'booking_rules', TemplateFieldType.percent, absent: _product, min: 20, max: 100),
      for (final c in ['iban', 'lydia', 'paypal_me', 'reference', 'wero', 'wise'])
        _f('workspace.payment_instructions.$c', 'payment_instructions', _text, p: _never,
            reason: "bank details are the source's own"),
      _f('workspace.invoice_pdf_template', 'document_design', TemplateFieldType.map, p: _never,
          reason: "points at the source's image library; travels with the report design exchange"),
      for (final c in ['invitation_template', 'invitation_templates'])
        _f('workspace.$c', 'invitations', _text, p: _never, reason: 'names the source space and its people'),
      _f('workspace.role_permissions', 'roles', TemplateFieldType.map, absent: TemplateAbsent.registryDefault),
      for (final role in ['co_owner', 'admin', 'member'])
        _f('workspace.role_permissions.$role', 'roles', TemplateFieldType.list,
            absent: TemplateAbsent.registryDefault, values: templatePermissions),
    ];

List<TemplateFieldSpec> _bookingRules() => [
      _f('workspace.booking_rules', 'booking_rules', TemplateFieldType.map),
      _f('workspace.booking_rules.granularity', 'booking_rules', TemplateFieldType.enumeration,
          absent: _product, values: templateGranularities),
      _f('workspace.booking_rules.open_weekdays', 'booking_rules', TemplateFieldType.list, absent: _product, min: 1, max: 7),
      for (final k in ['work_start_minutes', 'half_boundary_minutes', 'work_end_minutes'])
        _f('workspace.booking_rules.$k', 'booking_rules', TemplateFieldType.minutes, absent: _product, min: 0, max: 1440),
      for (final k in ['half_day_hours', 'full_day_hours', 'max_series_days'])
        _f('workspace.booking_rules.$k', 'booking_rules', _int, absent: _product, min: 1),
      _f('workspace.booking_rules.advance_horizon_days', 'booking_rules', _int, absent: _product, min: 1, max: 730),
      for (final k in ['min_duration_minutes', 'max_duration_minutes'])
        _f('workspace.booking_rules.$k', 'booking_rules', TemplateFieldType.minutes, absent: _product, min: 5, max: 1440),
      _f('workspace.booking_rules.outside_hours_mode', 'booking_rules', TemplateFieldType.enumeration,
          absent: _product, values: templateOutsideHoursModes),
      for (final k in ['allow_past_bookings', 'admin_check_out'])
        _f('workspace.booking_rules.$k', 'booking_rules', _bool, absent: _product),
      _f('workspace.booking_rules.simultaneous_reservations', 'booking_rules', _int, absent: _product, min: 1, max: 20),
      _f('workspace.booking_rules.legend_profile', 'booking_rules', TemplateFieldType.enumeration,
          absent: _product, values: templateLegendProfiles),
      _f('workspace.booking_rules.grid_within_hours', 'booking_rules', _bool,
          p: TemplatePortability.unsupported, reason: 'retired by #634; read as outside_hours_mode, never written'),
    ];

List<TemplateFieldSpec> _moneyRules() => [
      _f('workspace.subscription_levels', 'tariffs', TemplateFieldType.map),
      for (final k in ['enabled_presets', 'extra_levels'])
        _f('workspace.subscription_levels.$k', 'tariffs', TemplateFieldType.list, absent: _product, min: 1, max: 100),
      _f('workspace.subscription_levels.allow_custom', 'tariffs', _bool, absent: _product),
      _f('workspace.billing_rules', 'tariffs', TemplateFieldType.map),
      for (final k in ['subscription_auto', 'usage_auto', 'usage_when_zero'])
        _f('workspace.billing_rules.$k', 'tariffs', _bool, absent: _product),
      _f('workspace.billing_rules.subscription_advance_days', 'tariffs', _int, absent: _product, min: 0),
      _f('workspace.billing_rules.new_member_defaults.subscription_pct', 'tariffs', TemplateFieldType.percent, absent: _product, min: 1, max: 100),
      _f('workspace.billing_rules.new_member_defaults.overage_policy', 'tariffs', TemplateFieldType.enumeration, absent: _product),
      _f('workspace.billing_rules.repartition.method', 'tariffs', TemplateFieldType.enumeration),
      for (final k in ['weights', 'excluded'])
        _f('workspace.billing_rules.repartition.$k', 'tariffs', TemplateFieldType.map, p: _never, reason: _people),
      _f('workspace.dunning_rules', 'reminders', TemplateFieldType.map),
      _f('workspace.dunning_rules.levels', 'reminders', _int, absent: _product, min: 1, max: 9),
      for (final k in ['first_after_days', 'between_days'])
        _f('workspace.dunning_rules.$k', 'reminders', _int, absent: _product, min: 0),
      _f('workspace.dunning_rules.automatic', 'reminders', _bool, absent: _product),
    ];

List<TemplateFieldSpec> _wordingAndLooks() => [
      _f('workspace.feature_flags', 'features', TemplateFieldType.map),
      for (final e in featureManifest.values)
        _f('workspace.feature_flags.${e.feature.dbKey}', 'features', _bool,
            absent: TemplateAbsent.registryDefault,
            dependsOn: [if (e.requires != null) 'workspace.feature_flags.${e.requires!.dbKey}']),
      _f('workspace.lexicon', 'lexicon', TemplateFieldType.map),
      for (final term in templateLexiconTerms)
        _f('workspace.lexicon.{locale}.$term', 'lexicon', _text),
      _f('workspace.branding', 'branding', TemplateFieldType.map),
      _f('workspace.branding.seed_color', 'branding', TemplateFieldType.color, absent: _product),
      _f('workspace.branding.office_palette', 'branding', TemplateFieldType.list, absent: _product),
      _f('workspace.branding.seat_palette', 'branding', TemplateFieldType.enumeration, absent: _product),
    ];

List<TemplateFieldSpec> _row(String table, String entity, String key,
        Map<String, TemplateFieldType> columns,
        {Map<String, TemplatePortability> portability = const {},
        Map<String, String> reasons = const {}, Map<String, String> refs = const {},
        Map<String, List<String>> values = const {}}) =>
    [
      for (final c in columns.entries)
        _f('tables.$table[].${c.key}', entity, c.value, key: key,
            p: portability[c.key] ?? (refs.containsKey(c.key) ? _ref : TemplatePortability.literal),
            bindings: [if (refs[c.key] != null) refs[c.key]!],
            values: values[c.key] ?? const [],
            reason: reasons[c.key]),
    ];

List<TemplateFieldSpec> _tables() => [
      ..._row('vat_rates', 'vat', 'label@percent', {
        'label': _text, 'percent': TemplateFieldType.decimal, 'category': TemplateFieldType.enumeration,
        'is_default': _bool, 'active': _bool, 'group_key': _text, 'outside_base': _bool,
        'exemption_reason': _text, 'supersedes': _text, 'valid_from': TemplateFieldType.date,
        'valid_to': TemplateFieldType.date,
      }, refs: {'supersedes': 'vat_rates.label'}),
      ..._row('fee_bands', 'tariffs', 'from_pct', {
        'from_pct': TemplateFieldType.percent, 'to_pct': TemplateFieldType.percent,
        'fee_cents': _cents, 'overage_fee_cents': _cents,
      }),
      ..._row('plans', 'tariffs', 'name', {
        'name': _text, 'base_fee_cents': _cents, 'included_half_days': _int,
        'overage_fee_cents': _cents, 'active': _bool,
      }),
      ..._row('services', 'services', 'name', {
        'name': _text, 'price_cents': _cents, 'active': _bool, 'stock': _int, 'vat_rate': _text,
      }, refs: {'vat_rate': 'vat_rates.label'}),
      ..._row('packages', 'packages', 'name', {
        'name': _text, 'days': _int, 'price_cents': _cents, 'active': _bool, 'vat_rate': _text,
      }, refs: {'vat_rate': 'vat_rates.label'}),
      ..._row('accessories', 'accessories', 'name', {
        'name': _text, 'supplement_cents': _cents, 'active': _bool, 'sort_order': _int, 'vat_rate': _text,
      }, refs: {'vat_rate': 'vat_rates.label'}),
      ..._row('credit_products', 'credit_products', 'name', {
        'name': _text, 'half_days': _int, 'price_cents': _cents, 'validity_months': _int,
        'active': _bool, 'sort_order': _int, 'vat_rate': _text,
      }, refs: {'vat_rate': 'vat_rates.label'}),
      ..._row('sites', 'sites', 'name', {
        for (final c in ['name', 'street', 'postal_code', 'city', 'country_code', 'legal_id',
          'vat_id', 'tax_exemption_reason']) c: _text,
        'is_default': _bool, 'sort_order': _int,
      }, portability: {for (final c in _siteColumns) c: _never},
         reasons: {for (final c in _siteColumns) c: 'sites carry addresses, legal identifiers and VAT numbers'}),
      ..._row('closure_days', 'closure_days', 'day', {'day': TemplateFieldType.date, 'reason': _text}),
      ..._row('validation_policies', 'validation_rules', 'event_type', {
        'event_type': _text, 'required_count': _int, 'admins_may_validate': _bool,
        'owner_required': _bool, 'auto_validate_admin': _bool, 'auto_validate_owner': _bool,
        'validator_scope': TemplateFieldType.enumeration, 'owner_may_self_validate': _bool,
        'sequential': _bool, 'eligible_admin_ids': TemplateFieldType.list, 'min_amount_cents': _cents,
      }, portability: {'eligible_admin_ids': _never, 'min_amount_cents': TemplatePortability.unsupported},
         reasons: {'eligible_admin_ids': _people,
                   'min_amount_cents': 'the export does not carry it yet (#1655)'}),
      ..._row('workspace_documents', 'document_links', 'title@url', {
        for (final c in ['title', 'category', 'provider', 'url', 'min_role']) c: _text,
      }, portability: {for (final c in ['title', 'category', 'provider', 'url', 'min_role']) c: _never},
         reasons: {for (final c in ['title', 'category', 'provider', 'url', 'min_role']) c: "links to the source's own documents"}),
      ..._row('number_sequences', 'number_sequences', 'journal', {
        'journal': _text, 'prefix': _text, 'suffix': _text,
        'date_part': TemplateFieldType.enumeration, 'digits': _int, 'reset': TemplateFieldType.enumeration,
        'gapless': _bool, 'next_value': _int, 'period_key': _text,
      }, portability: {'next_value': _never, 'period_key': _never},
         reasons: {'next_value': 'a counter (#1295)', 'period_key': 'a counter (#1295)'}),
      ..._row('workspace_roles', 'workspace_roles', 'key', {
        'key': _text, 'permissions': TemplateFieldType.list, 'names': TemplateFieldType.map,
        'sort_order': _int, 'active': _bool,
      }, values: {'permissions': templatePermissions}),
      _f('tables.workspace_roles[].names.{locale}', 'workspace_roles', _text, key: 'key'),
      ..._row('workspace_field_definitions', 'field_definitions', 'key', {
        'key': _text, 'type': TemplateFieldType.enumeration, 'required': _bool, 'personal_data': _bool,
        'visibility': TemplateFieldType.enumeration, 'contexts': TemplateFieldType.list,
        'group_key': _text, 'sort_order': _int, 'validation': TemplateFieldType.map, 'active': _bool,
        'labels': TemplateFieldType.map, 'options': TemplateFieldType.list,
      }),
      for (final k in ['label', 'help_text'])
        _f('tables.workspace_field_definitions[].labels.{locale}.$k', 'field_definitions', _text, key: 'key'),
      for (final c in {'key': _text, 'sort_order': _int, 'active': _bool}.entries)
        _f('tables.workspace_field_definitions[].options[].${c.key}', 'field_definitions', c.value, key: 'key'),
      _f('tables.workspace_field_definitions[].options[].labels.{locale}', 'field_definitions', _text, key: 'key'),
    ];

const _siteColumns = ['name', 'street', 'postal_code', 'city', 'country_code',
  'legal_id', 'vat_id', 'tax_exemption_reason', 'is_default', 'sort_order'];

/// The plan tree `strip_template_plan` keeps: names and geometry, never a
/// price, an image, a background or the site.
List<TemplateFieldSpec> _floorPlan() {
  const geometry = {'x': _int, 'y': _int, 'w': _int, 'h': _int};
  TemplateFieldSpec node(String path, String column, TemplateFieldType type,
          {TemplatePortability p = TemplatePortability.literal, String? reason, List<String> bindings = const []}) =>
      _f('floor_plan$path.$column', 'floor_plan', type, key: 'name', p: p, reason: reason, bindings: bindings);
  return [
    node('[]', 'name', _text), node('[]', 'sort_order', _int), node('[]', 'bookable_as_whole', _bool),
    node('[]', 'price_cents', _cents, p: _never, reason: 'stripped by strip_template_plan'),
    node('[]', 'site', _text, p: _never, reason: 'sites never travel'),
    for (final c in ['background_path', 'images'])
      node('[]', c, _text, p: _never, reason: 'a storage file of the source'),
    node('[].offices[]', 'name', _text), node('[].offices[]', 'color', _int),
    node('[].offices[]', 'bookable_as_whole', _bool),
    node('[].offices[]', 'price_cents', _cents, p: _never, reason: 'stripped by strip_template_plan'),
    for (final g in geometry.entries) node('[].offices[]', g.key, g.value),
    node('[].offices[].desks[]', 'name', _text), node('[].offices[].desks[]', 'bookable_as_whole', _bool),
    node('[].offices[].desks[]', 'price_cents', _cents, p: _never, reason: 'stripped by strip_template_plan'),
    for (final g in geometry.entries) node('[].offices[].desks[]', g.key, g.value),
    node('[].offices[].desks[].seats[]', 'name', _text),
    for (final c in ['x', 'y']) node('[].offices[].desks[].seats[]', c, _int),
    // A compass letter (`n`), not a number: the plan's own wire form.
    for (final c in ['orientation', 'chair']) node('[].offices[].desks[].seats[]', c, _text),
    node('[].offices[].desks[].seats[]', 'amenities', TemplateFieldType.list),
    node('[].offices[].desks[].seats[]', 'accessories', TemplateFieldType.list, p: _ref, bindings: ['accessories.name']),
  ];
}

List<TemplateFieldSpec> _templateMeta() => [
      for (final c in ['key', 'name', 'description', 'visibility'])
        _f('template.$c', 'template', _text, p: TemplatePortability.unsupported, reason: 'describes the template, not a space'),
      _f('template.tags', 'template', TemplateFieldType.list, p: TemplatePortability.unsupported, reason: 'describes the template, not a space'),
      for (final c in ['sort_order', 'schema_version', 'template_version'])
        _f('template.$c', 'template', _int, p: TemplatePortability.unsupported, reason: 'describes the template, not a space'),
      _f('template.entities', 'template', TemplateFieldType.list, p: TemplatePortability.unsupported, reason: 'what the template carries'),
      _f('template.owner_workspace_id', 'template', _text, p: _never, reason: 'who published it'),
      _f('template.holidays.years', 'closure_days', _int, absent: _product, min: 1, max: 3, dependsOn: ['closure_days']),
      _f('template.holidays.country', 'closure_days', _text, p: _bind, absent: _product,
          reason: "the target's country unless the template names one"),
    ];

/// Every field, in a canonical order: by id.
List<TemplateFieldSpec> templateFieldRegistry() => [
      ..._workspaceColumns(), ..._bookingRules(), ..._moneyRules(),
      ..._wordingAndLooks(), ..._tables(), ..._floorPlan(), ..._templateMeta(),
    ]..sort((a, b) => a.id.compareTo(b.id));

/// The process a feature flag is configured in; the entity's process for
/// the reserved capabilities no subprocess lists.
String templateFieldProcess(TemplateFieldSpec spec) {
  if (spec.entity == 'features' && spec.id.startsWith('workspace.feature_flags.')) {
    final feature = WorkspaceFeature.values.asNameMap()[spec.id.split('.').last];
    if (feature != null) return homeProcessOf(feature) ?? spec.process;
  }
  return spec.process;
}
