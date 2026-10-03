# deskilo-ci-release — reference

## Android on AGP 9 (#1792)

- AGP 9.0.1 needs Gradle ≥ 9.1.0. Flutter wants Kotlin ≥ 2.3.20.
- `android.applicationVariants` is gone, so the F-Droid per-ABI versionCode (#795,
  `versionCode * 10 + abi`) lives in `androidComponents.onVariants`.
- Flutter's own split-per-abi code (`abi * 1000 + code`) then runs AFTER ours and
  wraps it (1031/2031/4031), so `gradle.properties` carries
  `force-version-code-ignoring-abi=true`.
- Verify with `aapt2 dump badging` on the split APKs (31/32/33) and the universal
  APK (3). The AGP 10 opt-outs (`android.builtInKotlin`, `android.newDsl`) stay until
  the plugins support it.

## The train's history (#1073)

The train used to take `-f track=beta` and resolve it to Play's `alpha`; the log
read `TRACK: beta` three lines above `--track "alpha"`, which produced a wrong
"never use the alpha track" rule. The input now IS the Play track (`alpha` or
`production`). Alpha is the CLOSED test whose 12-tester / 14-day countdown gates
production; Play's open beta is not a track this project ships to.

## Owner-side blockers

Kept in the memory file, not here (they change with the owner's actions):
store secrets such as `BETA_CONTACT_PHONE`, the Play listing review, the logo upload.
