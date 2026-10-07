---
name: deskilo-forms
description: Building or changing a form in DesKilo — which scaffold (sheet, dialog, wizard, screen), the form kit (AppTextField, FormControllers, AppFormSheet, FormGap/FormSection in lib/core/ui/form_kit.dart), domain-first validation (FieldErrors), the checklist a form must pass (ARB ×5, help dot and anchor, setup.html for a parameter, feature flag, 48dp targets, labels, error announced, keyboard type, autofill hints), the identity-form rule, splitting large sheets, and the form ratchets in test/lint/form_patterns_test.dart. Trigger before writing any TextField, showModalBottomSheet with fields, dialog with inputs, wizard step or settings screen with inputs, and when a form ratchet fails.
---
# Forms in DesKilo

The visual rules (tokens, radii, colours, contrast) are enforced by lint; this
skill covers how a form is BUILT. New forms use the kit; an existing form moves
to the kit when you touch it. `test/lint/form_patterns_test.dart` counts what is
left and only lets the counts fall.

## 1. Pick the scaffold

| The person is… | Use | Why |
|---|---|---|
| filing one record from where they are (an expense, a payment, a request) | `AppFormSheet` via `showAppFormSheet` | stays in context; pinned footer; refused submits keep it open |
| confirming one choice, or typing one value | `AlertDialog` (no kit needed beyond `AppTextField`) | a dialog is a question, not a form |
| configuring something with several steps that depend on each other | the wizard (`wizard_scaffold.dart`, `wizard_form_layout.dart`) | progress, back/next, one decision per step |
| maintaining a long-lived settings object (identity, legal, invoicing) | a screen with `FormSection`s | room for sections, help dots per field |

The identity and address form is ONE form: `PersonalInfoForm`
(AGENT_RULES "The identity form is ONE form"). Never write a second.

## 2. Build with the kit (`lib/core/ui/form_kit.dart`)

```dart
final fields = FormControllers({'name': item.name});   // no N declarations
await showAppFormSheet(context, AppFormSheet(
  title: l10n.newThingTitle,
  submitLabel: l10n.save,
  submitKey: const ValueKey('thing-save'),
  onDispose: fields.dispose,                           // disposed with the sheet
  onSubmit: () async {                                 // check + save; null = done
    final errors = validateThing(draft(fields));        // pure, in domain/
    if (errors.isNotEmpty) return describe(l10n, errors);
    await ref.read(thingsProvider).save(draft(fields));
    return null;
  },
  builder: (context, refresh) => [
    AppTextField(controller: fields['name'], label: l10n.thingName,
        error: shownErrors['name'], autofillHints: const [AutofillHints.name],
        help: const HelpDot('things', anchor: 'name')),
    const FormGap(),
    …
  ],
));
```

* `FormGap()` / `.small()` / `.large()` — never `SizedBox(height: 12)`.
* `AppTextField` — label, helper, `error` under the field (announced by the
  platform), keyboard, `autofillHints`, optional `help` dot. Never a raw
  `TextField(InputDecoration(...))` outside `lib/core/ui`.
* `onSubmit` returns `null` when done or the sentence to show; the sheet shows it
  above the buttons and stays open. It cannot be pressed twice while saving.

## 3. Validation is domain-first

The rules are a pure function in `domain/` (or `application/`): draft in, an
outcome enum (or a set of problems) out — `submit_expense.dart` /
`ExpenseOutcome` is the model. Test the rules without widgets; test the form
only for wiring. A numeric field always has a parse-and-validate path
(`parseCentsInput`, …).

The form maps the outcome to `FieldErrors` (field key → localized sentence) in
`AppFormSheet.validate`; each `AppTextField` with that `fieldKey` shows its own
problem under itself, the first one is announced, nothing is submitted while
any remains, and editing a field clears its problem:

```dart
validate: () {
  final outcome = expenseOutcome(draft());
  final field = fieldOf(outcome);          // outcome → 'amount', 'supplyName'…
  return field == null ? const {} : {field: reason(outcome)!};
},
onSubmit: () async { … return null or the server's reason … },
…
AppTextField(controller: fields['amount'], fieldKey: 'amount', label: …),
```

`onSubmit`'s returned sentence is for what no single field explains — the
server refused, the connection dropped — and shows above the buttons. A field
problem never goes to that banner.

## 4. The checklist a form passes before push

- [ ] Every label, helper, error and button in ARB ×5 (`lib/l10n/_fragments`,
      then `dart run tool/build_arb.dart` + `flutter gen-l10n` +
      `dart run tool/recorder_vocabulary.dart`).
- [ ] A help dot (and its anchor in the guides) on anything a person could misread
      (`deskilo-documentation`).
- [ ] A workspace parameter? `web/setup.html` in the same PR (hard rule).
- [ ] New functionality behind a `WorkspaceFeature` (lifetime rule).
- [ ] Keys on every control the recorder or a test drives (`recorder_keys_test`).
- [ ] 48dp targets, a label on every field, the error under its field.
- [ ] The right `keyboardType`; `autofillHints` on name, e-mail, phone, address,
      password fields (the e-mail rule is at zero and stays there).
- [ ] No sheet over ~400 lines: split per section, with a `FormControllers` bundle
      as the shared state (the three largest today: invoice template, expense
      schedule, export accounts).

## 5. When a form ratchet fails

`form_patterns_test` prints which count moved:
* **grew** — the change added a raw field / literal gap / inline fallback /
  e-mail field without autofill: use the kit instead.
* **fell** — you migrated something: lower the ceiling in the same commit to the
  number printed, so the ground stays taken.
