// SPDX-License-Identifier: AGPL-3.0-or-later

import 'feature_assessment.dart';

// Reviews describe the cited evidence and preserve its limitations.
// They do not enable features, grant permissions or claim stable maturity.

const _reviewedBetaRationale =
    'Reviewed against the cited shipped capabilities and their gated '
    'evidence. Beta is retained; the catalogue states the scope and '
    'limitations of each check. No stable qualification is claimed.';

const _reviewedOwnerBetaRationale =
    'The owner decision of 2026-10-13 set this feature to beta. The cited '
    'shipped capabilities now have an evidence-based review. Their scope '
    'and limitations are retained here; this review does not promote '
    'maturity.';

const bookingAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedBetaRationale,
  evidence: ['booking'],
  limitations:
      'Single-workspace timezone per booking; recovery of a booking made '
      'against a stale plan is manual.',
);

const approvalsAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedBetaRationale,
  evidence: ['approvals'],
  limitations:
      'Quorums count distinct people by membership, not by device or session.',
);

const privacyMemberRightsAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedOwnerBetaRationale,
  evidence: ['privacy.member_rights'],
  limitations:
      'Erasure is scoped to the installation and membership; accounting '
      'evidence and other retained records remain as disclosed, and external '
      'installations require separate action. A workspace can disable direct '
      'member export/erasure while the rights-request path stays available. '
      'Automated permission, field visibility, request, export and erasure '
      'checks do not establish legal compliance or independently qualify the '
      'operator\'s process.',
);

const membershipAllowancesAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedBetaRationale,
  evidence: ['membership.allowances'],
  limitations:
      'Allowances are counted per calendar month in the workspace clock; no '
      'pro-rata on a mid-month join.',
);

const demoAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedBetaRationale,
  evidence: ['demo'],
  limitations:
      'Named journey, workflow, persona and financial checks run against '
      'in-memory repositories. The Demo does not prove backend RLS or '
      'triggers, provider integrations, multi-device realtime or every screen '
      'journey. Leipzig intentionally uses new-workspace defaults; '
      'quota-extension and negotiated-price decisions do not have their '
      'corresponding stores, and some preview counts remain sample content.',
);

const mcpAccessAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedOwnerBetaRationale,
  evidence: [
    'mcp.read',
    'mcp.write',
    'mcp.consent',
  ],
  limitations:
      'mcp.read: Repository checks, authenticated database tests and a real '
      'local PostgREST containment drill cover the named paths. There is no '
      'external OAuth-client, hosted-runtime or operator-pilot qualification '
      'recorded here. A delegated token in the local drill is minted with the '
      'local stack signing key; this does not rehearse the external '
      'consent/login flow. Installation activation remains an '
      'operator-controlled state. mcp.write: Database and contract tests '
      'cover the named write, race and setup paths. No real external '
      'MCP-client write journey or named-runtime/operator-pilot execution is '
      'recorded here; installation activation, workspace exposure and current '
      'rights still govern availability. mcp.consent: Proved against the '
      'repository and a replayed database only; no provider, named-runtime or '
      'operator-pilot record is kept here.',
);

const calendarInterchangeAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedOwnerBetaRationale,
  evidence: ['calendar.interchange'],
  limitations:
      'This is one local .ics snapshot with UTC instants and a stable '
      'installation-scoped UID. It provides no import, subscription feed or '
      'ongoing calendar synchronization. Automated checks cover encoding, '
      'cancellation, ownership and changed previews; acceptance by external '
      'calendar applications and native platform save flows has not been '
      'recorded.',
);

const webmcpBrowserAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedOwnerBetaRationale,
  evidence: ['webmcp.browser'],
  limitations:
      'Unsupported browsers register nothing; native clients have no WebMCP '
      'tools. Reads, output filtering, context withdrawal and confirmed '
      'writes are tested through fake modelContext. The 3 November Edge 156 '
      'browser run exercised public-page tools and signed-in reads/refusals, '
      'with no writes; the published app build SHA was not recorded. '
      'get_availability is intentionally not offered. No hosted external-MCP '
      'activation is implied.',
);

const setupGuideAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedOwnerBetaRationale,
  evidence: ['setup.guide'],
  limitations:
      'The screen journey runs over fake repositories and uses a plan '
      'fixture; separate authenticated database tests prove the real command '
      'and readiness sequence. These are not one complete real-browser '
      'onboarding rehearsal. The owner waived the five newcomer study on '
      '#2874; setup remains beta and displayed time estimates remain a script '
      'baseline, not measured newcomer performance.',
);

const personalWorkspaceSeparationAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedOwnerBetaRationale,
  evidence: ['personal.workspace_separation'],
  limitations:
      'CI exercises seeded identities on three separate local stacks, '
      'including signed HTTP, database readback, cross-target refusal, '
      'outages and account epochs. This does not prove the complete '
      'one-registration onboarding and external identity-provider flow, or '
      'the Android/iPhone/desktop acceptance of the wider personal rework; '
      '#2560 remains open. Workspace operational data remains on its own '
      'installation.',
);
