-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0266 (#1655) — a template can be inspected field by field.
--
-- `deployable_entities()` says which entities travel and
-- `template_publication_rules()` which may be published; `template_outline`
-- names the groups. None of them says what happens to ONE field: whether
-- `booking_rules.simultaneous_reservations` travels as written, what its
-- absence means on the target, that `subscription_vat_rate` is a
-- reference resolved by label, why `number_sequences.next_value` never
-- travels. The client's `templateFieldRegistry()` answers that, one record
-- per stable path; `public.template_field_registry()` is GENERATED from
-- it (`dart run tool/build_template_field_registry_sql.dart`, pinned by
-- `template_field_registry_sql_test`) so the server and the client cannot
-- disagree. 0265 carried its first revision; this file restates it with
-- the two corrections the inspector's first run against real payloads
-- found (a seat's orientation is a compass letter, not a number; the desk
-- opacity is a percent between 20 and 100) — an applied file never
-- changes, so the corrections are a restatement here.
--
-- `inspect_workspace_template(template)` — readable by whoever may read
-- the template (`workspace_template_readable`), refused to anon, declared
-- STABLE so it cannot write — walks the stored payload against that
-- registry and answers:
--
--   { template: {safe metadata}, supported_schema_versions, registry_revision,
--     schema_revision, compatibility, compatibility_reason, outline,
--     status: ok | unsupported_version | rejected,
--     profile: full | partial | legacy | rejected,
--     digest, fields: [{path, id, disposition, value | shape, absent, reason}],
--     problems, required_inputs, exclusions, coverage }
--
-- Every applicable registered field is reported: present with its value
-- (scalars and lists of scalars only; a map is named by shape, never
-- copied), absent with what its absence means (inherit, product default,
-- registry default, required), a reference with whether the template can
-- resolve it, unsupported when this version does not carry it. An unknown
-- key, a duplicate natural key or a value the publication rules deny
-- REJECTS the template, and a denied value is never echoed; a plan that
-- still carries what `strip_template_plan` removes is reported (legacy)
-- and not rejected, because `template_snapshot` strips it again on every
-- read. A schema this build does not know is `unsupported_version` with
-- no usable field, never coerced. Rows are addressed by their natural key
-- (`entity_row_key`), so two same-named rows under different parents stay
-- distinct; `{locale}` matches a key shaped like a locale. The digest is
-- the md5 of the canonical present fields, so two installations holding
-- the same payload compute the same digest whatever their row ids.
--
-- No feature flag: the inspection is a second reading of a row the caller
-- may already read whole, inside the `workspaceLibrary` family.

-- ── the registry, generated ────────────────────────────────────────────
create or replace function public.template_field_registry()
returns jsonb
language sql
immutable
set search_path = public
as $registry$
  select $json$[
    {"id":"floor_plan[].background_path","entity":"floor_plan","type":"text","portability":"never","absent":"inherit","key":"name","reason":"a storage file of the source","process":"spaceManagement"},
    {"id":"floor_plan[].bookable_as_whole","entity":"floor_plan","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].images","entity":"floor_plan","type":"text","portability":"never","absent":"inherit","key":"name","reason":"a storage file of the source","process":"spaceManagement"},
    {"id":"floor_plan[].name","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].bookable_as_whole","entity":"floor_plan","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].color","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].bookable_as_whole","entity":"floor_plan","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].h","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].name","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].price_cents","entity":"floor_plan","type":"cents","portability":"never","absent":"inherit","key":"name","reason":"stripped by strip_template_plan","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].accessories","entity":"floor_plan","type":"list","portability":"reference","absent":"inherit","key":"name","bindings":["accessories.name"],"process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].amenities","entity":"floor_plan","type":"list","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].chair","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].name","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].orientation","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].x","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].y","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].w","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].x","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].y","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].h","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].name","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].price_cents","entity":"floor_plan","type":"cents","portability":"never","absent":"inherit","key":"name","reason":"stripped by strip_template_plan","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].w","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].x","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].y","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].price_cents","entity":"floor_plan","type":"cents","portability":"never","absent":"inherit","key":"name","reason":"stripped by strip_template_plan","process":"spaceManagement"},
    {"id":"floor_plan[].site","entity":"floor_plan","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites never travel","process":"spaceManagement"},
    {"id":"floor_plan[].sort_order","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].active","entity":"accessories","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].name","entity":"accessories","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].sort_order","entity":"accessories","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].supplement_cents","entity":"accessories","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].vat_rate","entity":"accessories","type":"text","portability":"reference","absent":"inherit","key":"name","bindings":["vat_rates.label"],"process":"spaceManagement"},
    {"id":"tables.closure_days[].day","entity":"closure_days","type":"date","portability":"literal","absent":"inherit","key":"day","process":"coordination"},
    {"id":"tables.closure_days[].reason","entity":"closure_days","type":"text","portability":"literal","absent":"inherit","key":"day","process":"coordination"},
    {"id":"tables.credit_products[].active","entity":"credit_products","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].half_days","entity":"credit_products","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].name","entity":"credit_products","type":"text","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].price_cents","entity":"credit_products","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].sort_order","entity":"credit_products","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].validity_months","entity":"credit_products","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].vat_rate","entity":"credit_products","type":"text","portability":"reference","absent":"inherit","key":"name","bindings":["vat_rates.label"],"process":"membershipCommerce"},
    {"id":"tables.fee_bands[].fee_cents","entity":"tariffs","type":"cents","portability":"literal","absent":"inherit","key":"from_pct","process":"membershipCommerce"},
    {"id":"tables.fee_bands[].from_pct","entity":"tariffs","type":"percent","portability":"literal","absent":"inherit","key":"from_pct","process":"membershipCommerce"},
    {"id":"tables.fee_bands[].overage_fee_cents","entity":"tariffs","type":"cents","portability":"literal","absent":"inherit","key":"from_pct","process":"membershipCommerce"},
    {"id":"tables.fee_bands[].to_pct","entity":"tariffs","type":"percent","portability":"literal","absent":"inherit","key":"from_pct","process":"membershipCommerce"},
    {"id":"tables.number_sequences[].date_part","entity":"number_sequences","type":"enumeration","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].digits","entity":"number_sequences","type":"integer","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].gapless","entity":"number_sequences","type":"boolean","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].journal","entity":"number_sequences","type":"text","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].next_value","entity":"number_sequences","type":"integer","portability":"never","absent":"inherit","key":"journal","reason":"a counter (#1295)","process":"billingPayments"},
    {"id":"tables.number_sequences[].period_key","entity":"number_sequences","type":"text","portability":"never","absent":"inherit","key":"journal","reason":"a counter (#1295)","process":"billingPayments"},
    {"id":"tables.number_sequences[].prefix","entity":"number_sequences","type":"text","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].reset","entity":"number_sequences","type":"enumeration","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].suffix","entity":"number_sequences","type":"text","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.packages[].active","entity":"packages","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.packages[].days","entity":"packages","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.packages[].name","entity":"packages","type":"text","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.packages[].price_cents","entity":"packages","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.packages[].vat_rate","entity":"packages","type":"text","portability":"reference","absent":"inherit","key":"name","bindings":["vat_rates.label"],"process":"membershipCommerce"},
    {"id":"tables.plans[].active","entity":"tariffs","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.plans[].base_fee_cents","entity":"tariffs","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.plans[].included_half_days","entity":"tariffs","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.plans[].name","entity":"tariffs","type":"text","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.plans[].overage_fee_cents","entity":"tariffs","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].active","entity":"services","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].name","entity":"services","type":"text","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].price_cents","entity":"services","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].stock","entity":"services","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].vat_rate","entity":"services","type":"text","portability":"reference","absent":"inherit","key":"name","bindings":["vat_rates.label"],"process":"membershipCommerce"},
    {"id":"tables.sites[].city","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].country_code","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].is_default","entity":"sites","type":"boolean","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].legal_id","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].name","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].postal_code","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].sort_order","entity":"sites","type":"integer","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].street","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].tax_exemption_reason","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].vat_id","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.validation_policies[].admins_may_validate","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].auto_validate_admin","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].auto_validate_owner","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].eligible_admin_ids","entity":"validation_rules","type":"list","portability":"never","absent":"inherit","key":"event_type","reason":"names people, who do not exist where a template is applied","process":"coordination"},
    {"id":"tables.validation_policies[].event_type","entity":"validation_rules","type":"text","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].min_amount_cents","entity":"validation_rules","type":"cents","portability":"unsupported","absent":"inherit","key":"event_type","reason":"the export does not carry it yet (#1655)","process":"coordination"},
    {"id":"tables.validation_policies[].owner_may_self_validate","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].owner_required","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].required_count","entity":"validation_rules","type":"integer","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].sequential","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].validator_scope","entity":"validation_rules","type":"enumeration","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.vat_rates[].active","entity":"vat","type":"boolean","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].category","entity":"vat","type":"enumeration","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].exemption_reason","entity":"vat","type":"text","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].group_key","entity":"vat","type":"text","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].is_default","entity":"vat","type":"boolean","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].label","entity":"vat","type":"text","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].outside_base","entity":"vat","type":"boolean","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].percent","entity":"vat","type":"decimal","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].supersedes","entity":"vat","type":"text","portability":"reference","absent":"inherit","key":"label@percent","bindings":["vat_rates.label"],"process":"billingPayments"},
    {"id":"tables.vat_rates[].valid_from","entity":"vat","type":"date","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].valid_to","entity":"vat","type":"date","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.workspace_documents[].category","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_documents[].min_role","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_documents[].provider","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_documents[].title","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_documents[].url","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_field_definitions[].active","entity":"field_definitions","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].contexts","entity":"field_definitions","type":"list","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].group_key","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].key","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].labels","entity":"field_definitions","type":"map","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].labels.{locale}.help_text","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].labels.{locale}.label","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options","entity":"field_definitions","type":"list","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options[].active","entity":"field_definitions","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options[].key","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options[].labels.{locale}","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options[].sort_order","entity":"field_definitions","type":"integer","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].personal_data","entity":"field_definitions","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].required","entity":"field_definitions","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].sort_order","entity":"field_definitions","type":"integer","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].type","entity":"field_definitions","type":"enumeration","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].validation","entity":"field_definitions","type":"map","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].visibility","entity":"field_definitions","type":"enumeration","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].active","entity":"workspace_roles","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].key","entity":"workspace_roles","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].names","entity":"workspace_roles","type":"map","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].names.{locale}","entity":"workspace_roles","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].permissions","entity":"workspace_roles","type":"list","portability":"literal","absent":"inherit","key":"key","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd"],"process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].sort_order","entity":"workspace_roles","type":"integer","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"template.description","entity":"template","type":"text","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.entities","entity":"template","type":"list","portability":"unsupported","absent":"inherit","reason":"what the template carries","process":"operations"},
    {"id":"template.holidays.country","entity":"closure_days","type":"text","portability":"local_binding","absent":"product_default","reason":"the target's country unless the template names one","process":"coordination"},
    {"id":"template.holidays.years","entity":"closure_days","type":"integer","portability":"literal","absent":"product_default","min":1,"max":3,"depends_on":["closure_days"],"process":"coordination"},
    {"id":"template.key","entity":"template","type":"text","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.name","entity":"template","type":"text","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.owner_workspace_id","entity":"template","type":"text","portability":"never","absent":"inherit","reason":"who published it","process":"operations"},
    {"id":"template.schema_version","entity":"template","type":"integer","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.sort_order","entity":"template","type":"integer","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.tags","entity":"template","type":"list","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.template_version","entity":"template","type":"integer","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.visibility","entity":"template","type":"text","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"workspace.accessory_supplements_since","entity":"workspace","type":"date","portability":"never","absent":"inherit","reason":"a date in this space's history","process":"operations"},
    {"id":"workspace.address","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.billing_rules","entity":"tariffs","type":"map","portability":"literal","absent":"inherit","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.new_member_defaults.overage_policy","entity":"tariffs","type":"enumeration","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.new_member_defaults.subscription_pct","entity":"tariffs","type":"percent","portability":"literal","absent":"product_default","min":1,"max":100,"process":"membershipCommerce"},
    {"id":"workspace.billing_rules.repartition.excluded","entity":"tariffs","type":"map","portability":"never","absent":"inherit","reason":"names people, who do not exist where a template is applied","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.repartition.method","entity":"tariffs","type":"enumeration","portability":"literal","absent":"inherit","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.repartition.weights","entity":"tariffs","type":"map","portability":"never","absent":"inherit","reason":"names people, who do not exist where a template is applied","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.subscription_advance_days","entity":"tariffs","type":"integer","portability":"literal","absent":"product_default","min":0,"process":"membershipCommerce"},
    {"id":"workspace.billing_rules.subscription_auto","entity":"tariffs","type":"boolean","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.usage_auto","entity":"tariffs","type":"boolean","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.usage_when_zero","entity":"tariffs","type":"boolean","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.booking_rules","entity":"booking_rules","type":"map","portability":"literal","absent":"inherit","process":"reservationsUsage"},
    {"id":"workspace.booking_rules.admin_check_out","entity":"booking_rules","type":"boolean","portability":"literal","absent":"product_default","process":"reservationsUsage"},
    {"id":"workspace.booking_rules.advance_horizon_days","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"max":730,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.allow_past_bookings","entity":"booking_rules","type":"boolean","portability":"literal","absent":"product_default","process":"reservationsUsage"},
    {"id":"workspace.booking_rules.full_day_hours","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.granularity","entity":"booking_rules","type":"enumeration","portability":"literal","absent":"product_default","values":["flexible","half_day","minutes_5","minutes_15","minutes_30","minutes_60","full_day","hours"],"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.grid_within_hours","entity":"booking_rules","type":"boolean","portability":"unsupported","absent":"inherit","reason":"retired by #634; read as outside_hours_mode, never written","process":"reservationsUsage"},
    {"id":"workspace.booking_rules.half_boundary_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":0,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.half_day_hours","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.legend_profile","entity":"booking_rules","type":"enumeration","portability":"literal","absent":"product_default","values":["full","simple"],"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.max_duration_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":5,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.max_series_days","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.min_duration_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":5,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.open_weekdays","entity":"booking_rules","type":"list","portability":"literal","absent":"product_default","min":1,"max":7,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.outside_hours_mode","entity":"booking_rules","type":"enumeration","portability":"literal","absent":"product_default","values":["off","free","charged","walkup_only"],"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.simultaneous_reservations","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"max":20,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.work_end_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":0,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.work_start_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":0,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.branding","entity":"branding","type":"map","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.branding.office_palette","entity":"branding","type":"list","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.branding.seat_palette","entity":"branding","type":"enumeration","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.branding.seed_color","entity":"branding","type":"color","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.city","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.company_id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.country_code","entity":"workspace","type":"text","portability":"local_binding","absent":"required","reason":"the new space says who and where it is","process":"operations"},
    {"id":"workspace.created_at","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.created_by","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.created_by_user","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.created_datetime","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.currency_code","entity":"workspace","type":"text","portability":"local_binding","absent":"required","reason":"the new space says who and where it is","process":"operations"},
    {"id":"workspace.default_locale","entity":"identity","type":"locale","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.desk_opacity","entity":"booking_rules","type":"percent","portability":"literal","absent":"product_default","min":20,"max":100,"process":"reservationsUsage"},
    {"id":"workspace.dev_mode","entity":"workspace","type":"boolean","portability":"never","absent":"inherit","reason":"this space's own switch","process":"operations"},
    {"id":"workspace.dunning_rules","entity":"reminders","type":"map","portability":"literal","absent":"inherit","process":"billingPayments"},
    {"id":"workspace.dunning_rules.automatic","entity":"reminders","type":"boolean","portability":"literal","absent":"product_default","process":"billingPayments"},
    {"id":"workspace.dunning_rules.between_days","entity":"reminders","type":"integer","portability":"literal","absent":"product_default","min":0,"process":"billingPayments"},
    {"id":"workspace.dunning_rules.first_after_days","entity":"reminders","type":"integer","portability":"literal","absent":"product_default","min":0,"process":"billingPayments"},
    {"id":"workspace.dunning_rules.levels","entity":"reminders","type":"integer","portability":"literal","absent":"product_default","min":1,"max":9,"process":"billingPayments"},
    {"id":"workspace.environment","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.feature_flags","entity":"features","type":"map","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.feature_flags.accessorySupplements","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.adminInvoicing","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.adminLevelAssign","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.levelBooking"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.adminSeatBlocking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.autoCheckInOut","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.badgeSignIn","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.nfcBadges"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.bookForOthers","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.bookingGate","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.bookingPolicies"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.bookingPolicies","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.calendarFileExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.calendarHub","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.calendarTab","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.calendarValidations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.calendarHub"],"process":"coordination"},
    {"id":"workspace.feature_flags.calendarViews","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.calendarHub"],"process":"coordination"},
    {"id":"workspace.feature_flags.carnets","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.coOwner","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.configurationTransfer","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.dataExport"],"process":"operations"},
    {"id":"workspace.feature_flags.customFields","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.customRoles","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.dataAccessLog","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.dataExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.decisionSurface","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.deletionRequests","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.demoMode","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.deployments","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.environmentPairs"],"process":"operations"},
    {"id":"workspace.feature_flags.documents","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.dunning","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.einvoiceCustomerDelivery","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"integrations"},
    {"id":"workspace.feature_flags.environmentPairs","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.eventsTab","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.expenseRepartition","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.expenseRepartitionWizard","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.expenseRepartition"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.financeFaces","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.formHelpHints","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.instanceWizard","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.invoiceAddressWindow","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.invoiceJourney","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.invoicePdfTemplate","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.invoiceSettlement","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.invoicing","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.invoicingWizard","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.kioskMemberPhotos","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.kioskMode"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.kioskMode","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.letterStandard","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportLayouts"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.levelBooking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.managedProfileAccess","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.managedProfiles"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.managedProfiles","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.membersDirectory"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.mcpAccess","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"integrations"},
    {"id":"workspace.feature_flags.memberAccountMenu","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.memberDataExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.memberEnvironments","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.environmentPairs"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.memberNotifications","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.memberOrigin","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.membersDirectory"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.memberPage","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.membersDirectory"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.memberPaymentTerms","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.memberReports","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.membersDirectory","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.messageGestures","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.messagesHub","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.moneyTab","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"billingPayments"},
    {"id":"workspace.feature_flags.multiSite","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.navigationStyle","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.nfcBadges","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.kioskMode"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.nfcSeatTags","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.notificationGrouping","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.eventsTab"],"process":"coordination"},
    {"id":"workspace.feature_flags.numberSequences","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.onlinePayments","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.paymentReminders","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.dunning"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.pdfExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.personalInfo","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.planMemberPhotos","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.planObjectDelete","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.priceNegotiations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.publicHolidays","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.pushNotifications","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"integrations"},
    {"id":"workspace.feature_flags.qrBadges","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.kioskMode"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.recordingPrivacy","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.regionalFormats","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.reportDesignExchange","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportDesigner"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.reportDesigner","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicePdfTemplate"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.reportLayouts","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportDesigner"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.reportTexts","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportDesigner"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.richMessageRefs","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.memberNotifications"],"process":"coordination"},
    {"id":"workspace.feature_flags.roleManagement","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.scheduledExpenses","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.seatDayTimeline","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.seriesBooking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.services","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.settlementFold","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoiceSettlement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.singleRoomLevelNames","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.siteDocuments","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.multiSite"],"process":"operations"},
    {"id":"workspace.feature_flags.spaceQrCodes","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.subscriptionInvoices","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.supplyExpenses","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.services"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.uiAnimations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.uniqueMonograms","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.usageInvoices","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.usageRecords","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.usageReport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.usageRecords"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.validationChain","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.validationScopes","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.vatCounterparty","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatDeclarations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatGroups","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatManagement","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatRateHistory","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatReport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatDeclarations"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.whatsappIntegration","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.membersDirectory"],"process":"integrations"},
    {"id":"workspace.feature_flags.workingHours","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.workspaceBranding","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.workspaceLibrary","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.workspaceStatus","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"operations"},
    {"id":"workspace.feature_flags.workspaceVocabulary","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.invitation_template","entity":"invitations","type":"text","portability":"never","absent":"inherit","reason":"names the source space and its people","process":"workspaceAccess"},
    {"id":"workspace.invitation_templates","entity":"invitations","type":"text","portability":"never","absent":"inherit","reason":"names the source space and its people","process":"workspaceAccess"},
    {"id":"workspace.invite_code","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"a secret","process":"operations"},
    {"id":"workspace.invoice_legal","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.invoice_pdf_template","entity":"document_design","type":"map","portability":"never","absent":"inherit","reason":"points at the source's image library; travels with the report design exchange","process":"documentsInformation"},
    {"id":"workspace.legal_id","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.lexicon","entity":"lexicon","type":"map","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.deskDetail","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.directoryTitle","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendBlocked","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendClosed","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendFree","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendMine","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendOccupied","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendReserved","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendUnavailable","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.levelDetail","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.levelReserveButton","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.messagesTitle","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planAfternoonChip","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planBookForLabel","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planCheckInButton","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planCheckInTitle","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planDurationLabel","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planFromLabel","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planMorningChip","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planReserveButton","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveClosedShort","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveDayView","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveFullDayChip","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveMonthView","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveWeekView","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.shellReserveButton","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.spaceKindDesk","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.spaceKindLevel","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.spaceKindOffice","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.spaceKindSeat","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.tabCalendar","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.tabEvents","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.tabMoney","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.tabPlan","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.modified_by_user","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.modified_datetime","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.name","entity":"workspace","type":"text","portability":"local_binding","absent":"required","reason":"the new space says who and where it is","process":"operations"},
    {"id":"workspace.pair_id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.payment_instructions.iban","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.lydia","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.paypal_me","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.reference","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.wero","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.wise","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.postal_code","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.role_permissions","entity":"roles","type":"map","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.role_permissions.admin","entity":"roles","type":"list","portability":"literal","absent":"registry_default","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd"],"process":"workspaceAccess"},
    {"id":"workspace.role_permissions.co_owner","entity":"roles","type":"list","portability":"literal","absent":"registry_default","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd"],"process":"workspaceAccess"},
    {"id":"workspace.role_permissions.member","entity":"roles","type":"list","portability":"literal","absent":"registry_default","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd"],"process":"workspaceAccess"},
    {"id":"workspace.site_id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.street","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.subscription_levels","entity":"tariffs","type":"map","portability":"literal","absent":"inherit","process":"membershipCommerce"},
    {"id":"workspace.subscription_levels.allow_custom","entity":"tariffs","type":"boolean","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.subscription_levels.enabled_presets","entity":"tariffs","type":"list","portability":"literal","absent":"product_default","min":1,"max":100,"process":"membershipCommerce"},
    {"id":"workspace.subscription_levels.extra_levels","entity":"tariffs","type":"list","portability":"literal","absent":"product_default","min":1,"max":100,"process":"membershipCommerce"},
    {"id":"workspace.subscription_vat_rate","entity":"vat","type":"text","portability":"reference","absent":"inherit","bindings":["vat_rates.label"],"process":"billingPayments"},
    {"id":"workspace.tax_exemption_reason","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.timezone","entity":"workspace","type":"text","portability":"local_binding","absent":"required","reason":"the new space says who and where it is","process":"operations"},
    {"id":"workspace.vat_account","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.vat_id","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.vat_regime","entity":"identity","type":"enumeration","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.whatsapp_group","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"}
  ]$json$::jsonb
$registry$;


revoke execute on function public.template_field_registry() from public, anon;
grant execute on function public.template_field_registry() to authenticated;

-- ── the walk ───────────────────────────────────────────────────────────
-- One pass over a payload, breadth-first with a jsonb work queue rather
-- than recursion: every node is either a container the registry knows
-- children of (descend), or a leaf (record). A key the registry has no
-- record for is reported as unknown, never skipped. `{locale}` matches a
-- key shaped like a locale; `[]` matches a row, addressed by its natural
-- key so two same-named rows under different parents stay distinct.
create or replace function public.template_walk_payload(p_configuration jsonb, p_floor_plan jsonb)
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
  v_ids text[] := array(select r->>'id' from jsonb_array_elements(public.template_field_registry()) r);
  v_queue jsonb := '[]'::jsonb;
  v_out jsonb := '[]'::jsonb;
  v_item jsonb;
  v_node jsonb;
  v_id text;
  v_path text;
  v_key text;
  v_child_id text;
  v_row_key text;
  v_table text;
  v_seen text[];
  v_i int;
  v_elem jsonb;
  v_depth int;
begin
  for v_key in select jsonb_object_keys(coalesce(p_configuration, '{}'::jsonb)) loop
    v_queue := v_queue || jsonb_build_object(
      'id', case v_key when 'workspace' then 'workspace' when 'tables' then 'tables'
                       when 'holidays' then 'template.holidays' else null end,
      'path', v_key, 'node', p_configuration->v_key, 'depth', 1);
  end loop;
  if p_floor_plan is not null and jsonb_typeof(p_floor_plan) = 'array' then
    v_queue := v_queue || jsonb_build_object('id', 'floor_plan', 'path', 'floor_plan',
      'node', p_floor_plan, 'depth', 1);
  end if;

  while jsonb_array_length(v_queue) > 0 loop
    v_item := v_queue->0;
    v_queue := v_queue - 0;
    v_id := v_item->>'id';
    v_path := v_item->>'path';
    v_node := v_item->'node';
    v_depth := (v_item->>'depth')::int;

    -- A seat's fields sit at depth 9 (plan, level, offices, office, desks,
    -- desk, seats, seat, field); nothing registered goes past 12.
    if v_depth > 12 then
      v_out := v_out || jsonb_build_object('path', v_path, 'id', null, 'problem', 'too_deep');
      continue;
    end if;
    if v_id is null then
      v_out := v_out || jsonb_build_object('path', v_path, 'id', null, 'problem', 'unknown_field');
      continue;
    end if;

    if jsonb_typeof(v_node) = 'object'
       and (v_id in ('workspace', 'tables') or exists (select 1 from unnest(v_ids) i where i like v_id || '.%')) then
      if v_id not in ('workspace', 'tables') and v_id = any (v_ids) then
        v_out := v_out || jsonb_build_object('path', v_path, 'id', v_id, 'container', true);
      end if;
      for v_key in select jsonb_object_keys(v_node) order by 1 loop
        if v_id || '.' || v_key = any (v_ids)
           or exists (select 1 from unnest(v_ids) i where i like v_id || '.' || v_key || '.%' or i like v_id || '.' || v_key || '[]%') then
          v_child_id := v_id || '.' || v_key;
        elsif v_key ~ '^[a-z]{2}(-[A-Z]{2})?$'
              and exists (select 1 from unnest(v_ids) i where i like v_id || '.{locale}%') then
          v_child_id := v_id || '.{locale}';
        else
          v_child_id := null;
        end if;
        v_queue := v_queue || jsonb_build_object('id', v_child_id, 'path', v_path || '.' || v_key,
          'node', v_node->v_key, 'depth', v_depth + 1);
      end loop;
      continue;
    end if;

    if jsonb_typeof(v_node) = 'array'
       and exists (select 1 from unnest(v_ids) i where i like v_id || '[]%') then
      v_table := case when v_id like 'tables.%' and position('[' in v_id) = 0 then substr(v_id, 8) else null end;
      v_seen := '{}';
      v_i := 0;
      for v_elem in select value from jsonb_array_elements(v_node) loop
        if jsonb_typeof(v_elem) <> 'object' then
          v_out := v_out || jsonb_build_object('path', v_path || '[' || v_i || ']', 'id', null, 'problem', 'unknown_field');
        else
          v_row_key := case when v_table is not null then public.entity_row_key(v_table, v_elem)
                            when v_elem ? 'name' then v_elem->>'name'
                            when v_elem ? 'key' then v_elem->>'key'
                            else v_i::text end;
          v_row_key := coalesce(v_row_key, v_i::text);
          if v_row_key = any (v_seen) then
            v_out := v_out || jsonb_build_object('path', v_path || '[' || v_row_key || ']', 'id', v_id || '[]', 'problem', 'duplicate_key');
          end if;
          v_seen := v_seen || v_row_key;
          v_queue := v_queue || jsonb_build_object('id', v_id || '[]', 'path', v_path || '[' || v_row_key || ']',
            'node', v_elem, 'depth', v_depth + 1);
        end if;
        v_i := v_i + 1;
      end loop;
      continue;
    end if;

    -- A leaf: the registry knows it as a value (scalar, a list of scalars,
    -- or a map it classifies whole). A map or a list of maps the registry
    -- has no children for is reported by shape, never copied.
    if v_id = any (v_ids) then
      if jsonb_typeof(v_node) in ('object')
         or (jsonb_typeof(v_node) = 'array'
             and exists (select 1 from jsonb_array_elements(v_node) e where jsonb_typeof(e.value) in ('object', 'array'))) then
        v_out := v_out || jsonb_build_object('path', v_path, 'id', v_id, 'shape', jsonb_typeof(v_node));
      else
        v_out := v_out || jsonb_build_object('path', v_path, 'id', v_id, 'value', v_node);
      end if;
    else
      v_out := v_out || jsonb_build_object('path', v_path, 'id', null, 'problem', 'unknown_field');
    end if;
  end loop;
  return v_out;
end $$;

-- An internal helper of the inspection, which runs as definer: nobody
-- calls it directly, so the default grant to PUBLIC (which authenticated
-- inherits at create time) is taken back too.
revoke execute on function public.template_walk_payload(jsonb, jsonb) from public, anon, authenticated;

-- ── the inspection ─────────────────────────────────────────────────────
create or replace function public.inspect_workspace_template(p_template_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tpl public.workspace_templates;
  v_registry jsonb := public.template_field_registry();
  v_rules jsonb := public.template_publication_rules();
  v_compat jsonb;
  v_walk jsonb;
  v_fields jsonb := '[]'::jsonb;
  v_problems jsonb := '[]'::jsonb;
  v_required jsonb := '[]'::jsonb;
  v_exclusions jsonb := '[]'::jsonb;
  v_applicable text[];
  v_declared text[];
  v_publishable text[];
  v_present_ids text[] := '{}';
  v_present_rows text[] := '{}';
  v_item jsonb;
  v_spec jsonb;
  v_disp text;
  v_value jsonb;
  v_ok boolean;
  v_row_prefix text;
  v_column text;
  v_pattern text;
  v_labels text[];
  v_names text[];
  v_head jsonb;
  v_status text := 'ok';
  v_profile text;
  v_digest text;
  v_absent int := 0;
  v_present int := 0;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.workspace_template_readable(p_template_id) then
    raise exception 'unknown template';
  end if;
  select * into v_tpl from public.workspace_templates where id = p_template_id;
  v_declared := v_tpl.entities;
  select array_agg(k) into v_publishable from jsonb_each(v_rules) r(k, v) where (v->>'allowed')::boolean;
  v_compat := public.template_compatibility(v_tpl, null);

  v_head := jsonb_build_object(
    'template', jsonb_build_object(
      'id', v_tpl.id, 'key', v_tpl.key, 'name', v_tpl.name, 'description', v_tpl.description,
      'visibility', v_tpl.visibility, 'tags', to_jsonb(v_tpl.tags), 'entities', to_jsonb(v_tpl.entities),
      'schema_version', v_tpl.schema_version, 'template_version', v_tpl.template_version,
      'owner_workspace_id', v_tpl.owner_workspace_id),
    'supported_schema_versions', to_jsonb(public.template_supported_schema_versions()),
    'registry_revision', left(md5(v_registry::text), 12),
    'schema_revision', public.deskilo_schema_version(),
    'compatibility', v_compat->>'status',
    'compatibility_reason', v_compat->'reason',
    'outline', coalesce((
      select jsonb_agg(jsonb_build_object('group', s.grp, 'entities', s.keys) order by s.first_ord)
        from (select e.value->>'group' as grp, jsonb_agg(e.value->>'key' order by e.ord) as keys, min(e.ord) as first_ord
                from jsonb_array_elements(public.deployable_entities()) with ordinality e(value, ord)
               where (e.value->>'key') in (select jsonb_array_elements_text(v_compat->'selected'))
               group by e.value->>'group') s), '[]'::jsonb));

  if not v_tpl.schema_version = any (public.template_supported_schema_versions()) then
    return v_head || jsonb_build_object('status', 'unsupported_version', 'profile', 'unknown',
      'digest', null, 'fields', '[]'::jsonb, 'problems', jsonb_build_array(jsonb_build_object(
        'path', 'template.schema_version', 'problem', 'unsupported_version', 'value', v_tpl.schema_version)),
      'required_inputs', '[]'::jsonb, 'exclusions', '[]'::jsonb,
      'coverage', jsonb_build_object('registered', 0, 'present', 0, 'absent', 0, 'unknown', 0));
  end if;

  v_walk := public.template_walk_payload(v_tpl.configuration, v_tpl.floor_plan);
  select array_agg(l->>'label') into v_labels from jsonb_array_elements(coalesce(v_tpl.configuration->'tables'->'vat_rates', '[]'::jsonb)) l;
  select array_agg(a->>'name') into v_names from jsonb_array_elements(coalesce(v_tpl.configuration->'tables'->'accessories', '[]'::jsonb)) a;

  for v_item in select value from jsonb_array_elements(v_walk) loop
    if v_item ? 'problem' then
      v_problems := v_problems || (v_item - 'id');
      continue;
    end if;
    if v_item ? 'container' then
      v_present_ids := v_present_ids || (v_item->>'id');
      continue;
    end if;
    select value into v_spec from jsonb_array_elements(v_registry) r where r.value->>'id' = v_item->>'id';
    v_value := v_item->'value';
    v_disp := case v_spec->>'portability'
      when 'never' then 'excluded' when 'unsupported' then 'unsupported'
      when 'reference' then 'reference' else 'present' end;
    if v_disp = 'excluded' then
      -- What the stripper leaves behind is empty; a value that is not is a
      -- problem — and rejects, unless it sits in the plan, which
      -- `template_snapshot` strips again on every read (legacy templates).
      if v_value is null or v_value in ('null'::jsonb, '""'::jsonb, '[]'::jsonb, '{}'::jsonb, '0'::jsonb, 'false'::jsonb) then
        v_disp := 'stripped';
      else
        v_problems := v_problems || jsonb_build_object('path', v_item->>'path',
          'problem', case when (v_item->>'path') like 'floor_plan%' then 'legacy_excluded' else 'carries_excluded' end,
          'reason', v_spec->>'reason');
      end if;
      v_fields := v_fields || jsonb_build_object('path', v_item->>'path', 'id', v_item->>'id', 'disposition', v_disp, 'reason', v_spec->>'reason');
      continue;
    end if;
    if v_value is not null and jsonb_typeof(v_value) <> 'null' then
      v_ok := true;
      if jsonb_typeof(v_value) = 'array' then
        if (v_spec->>'type') <> 'list' then v_ok := false; end if;
        if v_spec ? 'values' and not (v_spec->'values' @> v_value) then v_ok := false; end if;
        if exists (select 1 from jsonb_array_elements(v_value) e where jsonb_typeof(e.value) = 'number'
                    and ((v_spec ? 'min' and (e.value::text)::numeric < (v_spec->>'min')::numeric)
                      or (v_spec ? 'max' and (e.value::text)::numeric > (v_spec->>'max')::numeric))) then v_ok := false; end if;
      else
        if v_spec ? 'values' and not (v_spec->'values' @> jsonb_build_array(v_value)) then v_ok := false; end if;
        if jsonb_typeof(v_value) = 'number' and v_spec ? 'min' and (v_value::text)::numeric < (v_spec->>'min')::numeric then v_ok := false; end if;
        if jsonb_typeof(v_value) = 'number' and v_spec ? 'max' and (v_value::text)::numeric > (v_spec->>'max')::numeric then v_ok := false; end if;
        if (v_spec->>'type') = 'boolean' and jsonb_typeof(v_value) <> 'boolean' then v_ok := false; end if;
        if (v_spec->>'type') in ('integer', 'minutes', 'cents', 'percent', 'decimal') and jsonb_typeof(v_value) <> 'number' then v_ok := false; end if;
        if (v_spec->>'type') = 'list' then v_ok := false; end if;
      end if;
      if not v_ok then
        v_problems := v_problems || jsonb_build_object('path', v_item->>'path', 'problem', 'out_of_range', 'value', v_value);
      end if;
    end if;
    if v_disp = 'reference' then
      v_ok := case
        when (v_spec->'bindings'->>0) = 'vat_rates.label' then v_value is null or v_value = 'null'::jsonb or (v_value #>> '{}') = any (coalesce(v_labels, '{}'))
        when (v_spec->'bindings'->>0) = 'accessories.name' then jsonb_typeof(v_value) <> 'array' or not exists (
          select 1 from jsonb_array_elements_text(v_value) n where not n = any (coalesce(v_names, '{}')))
        else true end;
      if not v_ok then
        v_required := v_required || jsonb_build_object('path', v_item->>'path', 'id', v_item->>'id',
          'binding', v_spec->'bindings'->>0, 'value', v_value, 'reason', 'not defined in this template');
      end if;
    end if;
    v_present_ids := v_present_ids || (v_item->>'id');
    if position('[' in v_item->>'path') > 0 then
      v_present_rows := v_present_rows || regexp_replace(v_item->>'path', '\.[^.\[\]]+$', '');
    end if;
    v_present := v_present + 1;
    v_fields := v_fields || (jsonb_build_object('path', v_item->>'path', 'id', v_item->>'id', 'disposition', v_disp)
      || case when v_item ? 'value' then jsonb_build_object('value', v_value) else jsonb_build_object('shape', v_item->>'shape') end);
  end loop;

  -- Every applicable record the payload does not carry, with what its
  -- absence means; row fields per row the payload does carry.
  v_applicable := array(select r->>'id' from jsonb_array_elements(v_registry) r
    where (r->>'entity') = any (v_declared || array['workspace', 'template'])
      and (r->>'portability') in ('literal', 'reference', 'local_binding')
      and position('{locale}' in r->>'id') = 0);
  for v_spec in select value from jsonb_array_elements(v_registry) r where (r.value->>'id') = any (v_applicable) loop
    if (v_spec->>'portability') = 'local_binding' then
      v_required := v_required || jsonb_build_object('path', v_spec->>'id', 'id', v_spec->>'id',
        'binding', 'target', 'reason', v_spec->>'reason');
      continue;
    end if;
    if position('[]' in v_spec->>'id') > 0 then
      v_column := regexp_replace(v_spec->>'id', '^.*\.', '');
      v_pattern := '^' || regexp_replace(regexp_replace(regexp_replace(v_spec->>'id', '\.[^.\[\]]+$', ''), '\.', '\\.', 'g'), '\[\]', '\\[[^\\]]*\\]', 'g') || '$';
      for v_row_prefix in select distinct p from unnest(v_present_rows) p where p ~ v_pattern loop
        if not exists (select 1 from jsonb_array_elements(v_fields) f where f.value->>'path' = v_row_prefix || '.' || v_column) then
          v_absent := v_absent + 1;
          v_fields := v_fields || jsonb_build_object('path', v_row_prefix || '.' || v_column,
            'id', v_spec->>'id', 'disposition', 'absent', 'absent', v_spec->>'absent');
        end if;
      end loop;
    elsif not (v_spec->>'id') = any (v_present_ids) then
      v_absent := v_absent + 1;
      v_fields := v_fields || jsonb_build_object('path', v_spec->>'id', 'id', v_spec->>'id',
        'disposition', 'absent', 'absent', v_spec->>'absent');
    end if;
  end loop;

  v_exclusions := coalesce((select jsonb_agg(jsonb_build_object('id', r->>'id', 'portability', r->>'portability', 'reason', r->>'reason') order by r->>'id')
    from jsonb_array_elements(v_registry) r
    where (r->>'portability') in ('never', 'unsupported')
      and (r->>'entity') = any (v_declared || array['workspace', 'template'])), '[]'::jsonb);

  if exists (select 1 from jsonb_array_elements(v_problems) p
              where p.value->>'problem' in ('unknown_field', 'duplicate_key', 'carries_excluded', 'too_deep')) then
    v_status := 'rejected';
  end if;
  v_profile := case
    when v_status = 'rejected' then 'rejected'
    when coalesce(v_tpl.configuration, '{}'::jsonb) = '{}'::jsonb and v_declared <@ array['floor_plan'] then 'legacy'
    when v_declared @> v_publishable then 'full'
    else 'partial' end;
  v_fields := coalesce((select jsonb_agg(f order by f->>'path') from jsonb_array_elements(v_fields) f), '[]'::jsonb);
  v_digest := md5(v_tpl.schema_version::text || '|' || array_to_string(v_declared, ',') || E'\n' ||
    coalesce((select string_agg((f->>'path') || '=' || coalesce((f->'value')::text, f->>'shape', ''), E'\n' order by f->>'path')
      from jsonb_array_elements(v_fields) f where f->>'disposition' in ('present', 'reference', 'unsupported')), ''));

  return v_head || jsonb_build_object(
    'status', v_status, 'profile', v_profile, 'digest', v_digest,
    'fields', v_fields,
    'problems', coalesce((select jsonb_agg(p order by p->>'path') from jsonb_array_elements(v_problems) p), '[]'::jsonb),
    'required_inputs', coalesce((select jsonb_agg(r order by r->>'path') from jsonb_array_elements(v_required) r), '[]'::jsonb),
    'exclusions', v_exclusions,
    'coverage', jsonb_build_object('registered', cardinality(v_applicable), 'present', v_present,
      'absent', v_absent, 'unknown', (select count(*) from jsonb_array_elements(v_problems) p where p.value->>'problem' = 'unknown_field'),
      'required_inputs', jsonb_array_length(v_required)));
end $$;

revoke execute on function public.inspect_workspace_template(uuid) from public, anon;
grant execute on function public.inspect_workspace_template(uuid) to authenticated;

select public.set_deskilo_schema_version(266);
