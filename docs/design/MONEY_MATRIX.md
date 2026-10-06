# Money: my finances vs the workspace's invoicing

Two different jobs, two different places. **My finances** (Me › Finances) is
everything about MY money, from every workspace I belong to. **Invoicing**
(workspace) is the process that creates, sends and chases documents for the
whole workspace. An admin who invoices and pays their own invoices does both —
in two places that never mix.

## 1. Where each function lives

| Function | Me › Finances | Workspace · Money (my account here) | Workspace · Invoicing (process) |
|---|---|---|---|
| See what I owe, across workspaces | **yes** (Outstanding) | this workspace only | — |
| See what I paid (settled invoices) | **yes** (Paid) | this workspace only | — |
| My payments and payment preference | **yes** (Payments) | this workspace | — |
| Reminders I received | **yes** (Reminders) | on the invoice | — |
| Pay an invoice online / how to pay | opens the workspace | **yes** | — |
| My usage and statement of the month | link (history) | **yes** | — |
| Issue invoices (month, one member, all) | — | — | **yes** |
| Preview / download / share / e-invoice | my own, in the workspace | my own | any invoice |
| Send a reminder, suspend reminders | — | — | **yes** |
| Mark paid / register a payment | — | — | **yes** |
| Mark erroneous, replace, credit note | — | — | **yes** |
| Closing assistant, bulk invoicing, register, VAT | — | — | **yes** |

## 2. Who may do what (roles and permissions)

| Role / permission | My finances | Workspace · Money | Invoicing: see | Invoicing: issue | Chase / register payment | Void / credit |
|---|---|---|---|---|---|---|
| Member | own | own | — | — | — | — |
| Member + `viewFinances` | own | own | read | — | — | — |
| Admin (default) | own | own | read | per `issueInvoices` | per `manageMembers` / finance validation | per validation rule |
| Owner / co-owner | own | own | all | all | all | all (validated) |
| Custom role | own | own | per its permissions | per `issueInvoices` | per its permissions | per its permissions |

My finances never shows another member's document, whatever the role.

## 3. Documents emitted

| Document | Created by | Seen by the member in | Process |
|---|---|---|---|
| Invoice | Invoicing → issue | Me › Finances (Outstanding / Paid), Workspace · Money | issue → pay → confirm → close |
| Reminder | Invoicing → remind (or automatic) | Me › Finances (Reminders) | levels 1…n, suspendable |
| Payment confirmation | Invoicing → register / online provider | Me › Finances (Payments) | match → validate → close |
| Credit note / replacement | Invoicing → void / replace | Me › Finances (Paid: refunded) | validated |

## 4. Rules of the design

- One question per place: "what do I owe?" → Me › Finances; "what must I do to
  invoice?" → Invoicing. Titles and entry points never share a word.
- The admin's own invoices are never inside the invoicing worklist.
- Every row opens its home: an invoice of mine opens the workspace Money face
  for that workspace; an invoice to issue opens its invoicing form.
