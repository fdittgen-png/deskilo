# Push setup — the owner's one-time Firebase checklist (#426, ADR 0011)

The FCM stack ships DISABLED: `packages/deskilo_push/lib/src/firebase_options.dart` is a
stub returning null, so the app stays local-notifications-only and
everything builds and runs. These steps light FCM up on Android, iOS, web and
macOS. Nothing here can be automated — every step needs the owner's
Google/Apple accounts.

## 1. Firebase project

1. https://console.firebase.google.com → *Add project* (suggested name
   `deskilo`). Analytics OFF.
2. `dart pub global activate flutterfire_cli`
3. In the repo root: `flutterfire configure` — select the project and
   the android/ios/web/macos platforms. This writes
   `lib/firebase_options.dart` and the native config files.
4. Edit `packages/deskilo_push/lib/src/firebase_options.dart`: import the generated
   file and change the getter to
   `DefaultFirebaseOptions.currentPlatform`.

## 2. APNs (iOS/macOS delivery)

1. Apple Developer → Keys → new key with *Apple Push Notifications
   service* → download the `.p8`.
2. Firebase console → Project settings → Cloud Messaging → *Apple app
   configuration* → upload the key (Key ID + Team ID).

## 3. The send-push function secret

1. Firebase console → Project settings → Service accounts → *Generate
   new private key* (JSON).
2. `supabase secrets set FCM_SERVICE_ACCOUNT="$(cat the-key.json)"`
3. `supabase functions deploy send-push`

### Pair the database trigger and function

Do this independently on development, production and every self-hosted installation.
Keep the value in the operator's secret manager; never put it in source, client
configuration, setup XML, issue comments or logs.

1. Generate a private random shared secret with the operator's secret manager.
2. In the installation's Supabase Vault, create the named secret
   `deskilo_push_shared_secret` with that value. Apply the database update that
   routes event, message and reminder headers through `push_delivery_headers`.
3. Set the push function's `PUSH_SHARED_SECRET` to the same value through the
   installation's secret management interface. Deploy the updated `send-push`.
   Vault and trigger support come first, so configuring the function never
   cuts off the database's existing callers.
4. Verify that a caller without the secret is refused with 401 and sends nothing,
   while a message, pending event and payment reminder still reach their devices.
   Authorized calls answer only 202 with `{"accepted":true}`; they expose no
   identifier existence or recipient/delivery counts. Private function logs
   retain operational outcomes.

Until pairing is complete, an installation without `PUSH_SHARED_SECRET` keeps
legacy delivery and logs a warning once per worker. That installation is still
exposed to publishable-key callers; deploying the code alone does not complete
the security rollout. Once configured, only the matching trigger header or the
exact service credential authorizes delivery. Decoding a JWT role is insufficient.

A 202 confirms request handling, never device delivery. Reminder reconciliation
records this opaque result as unknown, preserving the recorded reminder and debt.
Historical responses with delivery counts retain their historical interpretation.

## 4. Verify

- Run the app on a phone: Settings → Advanced shows *Push notifications
  are active*.
- `select count(*) from push_endpoints where endpoint like 'fcm:%';`
  goes above zero.
- Have an admin overrule a reservation from another account: the
  displaced member's phone shows *Reservation removed* — killed app
  included.

Behavior notes: foregrounded apps replace the push with their own
LOCALIZED notification; background/killed shows the generic English
per-kind text (payloads never carry names or times — the 0012 privacy
doctrine).
