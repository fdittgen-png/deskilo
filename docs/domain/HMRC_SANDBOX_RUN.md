<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# HMRC MTD VAT — the sandbox run an operator performs (#2470)

Everything the issue asked for is merged behind the `mtdSubmission` flag
(default off): the connection, the obligations, the submission with the
fraud-prevention headers, the recovery of an uncertain submission, the
screen and the London Demo. What is not recorded is a real exchange with the
HMRC Developer Hub sandbox. This sheet is that run, and the record that
closes the issue. Nothing here needs a code change unless the run finds a
defect (one fix per defect, `Refs #2470`).

## Before the run (the operator provides)

1. An application on the HMRC Developer Hub with the **VAT (MTD)** API
   subscribed, a sandbox client id and secret, and this **redirect URI**:
   `<SUPABASE_URL>/functions/v1/accounting-connect` (the function's own
   address, not an app route).
2. Function secrets on the target Supabase project:
   - `ACCOUNTING_HMRC_MTD_CLIENT_ID`, `ACCOUNTING_HMRC_MTD_CLIENT_SECRET`;
   - `HMRC_ENVIRONMENT=sandbox`;
   - **`HMRC_VENDOR_PUBLIC_IP` — required**: without it every HMRC action
     answers `fraud_headers_missing` (`Gov-Vendor-Public-IP` has no other
     source);
   - `DESKILO_VERSION` (optional; `unknown` when absent).
3. An HMRC sandbox test user with VAT (create it with the Test Support API)
   and its VRN on a **GB workspace** with a prepared return whose period has
   ended, `vatDeclarations` and `mtdSubmission` switched on.
4. A signed-in **web** session as the owner: a submission is web-only (the
   fraud-prevention client values come from the browser).

## The run

1. Connect to HMRC from the VAT returns screen (the authorisation code
   exchange returns to the function's address above; the tokens are Vault
   secrets, never client-readable).
2. Read the open obligation: post `hmrc_obligations` to `accounting-connect`
   as the signed-in owner with the `client` object the web app sends
   (`supabase/functions/accounting-connect/hmrc.ts`). Note the `periodKey`
   matching the prepared return.
3. Check the headers: post `hmrc_validate_headers` the same way. The verdict
   must report no error for the connection method `WEB_APP_VIA_SERVER`.
4. Submit through MTD from the sheet. The answer carries the status, the
   channel `hmrc_mtd` and the receipt (`formBundleNumber`).
5. Read back the return: `filed`, channel `hmrc_mtd`, that receipt, and its
   period locked (ADR 0039).

If the first call refuses with a missing `Gov-Client-Public-Port`, the host
did not forward the caller's port (`x-forwarded-port`): that is a code fix,
not an operator error.

## The record that closes the issue

One dated file under `docs/product/evidence/` (the first lines are what the
capability evidence tool reads):

```
scope: provider_sandbox
id: tax.hmrc_mtd
provider: hmrc

HMRC VAT (MTD) sandbox run, <date>
- sandbox VRN (masked): ***<last three digits>
- obligation periodKey: <periodKey>
- formBundleNumber: <formBundleNumber>
- fraud-prevention headers validator, WEB_APP_VIA_SERVER: <verdict>
- return state: filed / hmrc_mtd / that receipt; period locked: yes
```

It holds no token, no client secret and no unmasked VRN. Then:

- add the entry's evidence row in `docs/product/capabilities.json` under
  `tax.hmrc_mtd` (`sha`, `date`, `outcome`, and the fingerprint
  `dart run tool/capability_evidence.dart --fingerprints` prints), and update
  its `limitations`;
- `dart run tool/capability_evidence.dart` rewrites the page, the release
  file and the web module;
- the flag stays off: enabling it for GB production is a separate operator
  decision, after HMRC approves the production application.
