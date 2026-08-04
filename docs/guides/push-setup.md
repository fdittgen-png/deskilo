# Push setup — the owner's one-time Firebase checklist (#426, ADR 0011)

The FCM stack ships DISABLED: `lib/core/push/firebase_options.dart` is a
stub returning null, so the app falls back to UnifiedPush and everything
builds and runs. These steps light FCM up on Android, iOS, web and
macOS. Nothing here can be automated — every step needs the owner's
Google/Apple accounts.

## 1. Firebase project

1. https://console.firebase.google.com → *Add project* (suggested name
   `deskilo`). Analytics OFF.
2. `dart pub global activate flutterfire_cli`
3. In the repo root: `flutterfire configure` — select the project and
   the android/ios/web/macos platforms. This writes
   `lib/firebase_options.dart` and the native config files.
4. Edit `lib/core/push/firebase_options.dart`: import the generated
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

## 4. Verify

- Run the app on a phone: Settings → Advanced shows *Push notifications
  are active* without any distributor app.
- `select count(*) from push_endpoints where endpoint like 'fcm:%';`
  goes above zero.
- Have an admin overrule a reservation from another account: the
  displaced member's phone shows *Reservation removed* — killed app
  included.

Behavior notes: foregrounded apps replace the push with their own
LOCALIZED notification; background/killed shows the generic English
per-kind text (payloads never carry names or times — the 0012 privacy
doctrine). UnifiedPush users keep working unchanged.
