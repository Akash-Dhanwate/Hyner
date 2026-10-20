# Hyner — Phase 1 status

**Status: foundation implemented; acceptance incomplete.**

## Implemented

- Android-first Flutter project, modular feature boundaries, Riverpod state
  management, and protected go_router navigation.
- Hyner monogram, adaptive and legacy launcher icons, native and Flutter splash,
  bundled Manrope typography, light/dark/device themes, saved appearance.
- Welcome, Google Sign-In, Dashboard, Inventory, Sales, Purchases, Customers,
  Reports, Settings, and User Profile screens.
- Firebase/Google authentication adapter, Firebase-owned native session
  persistence, secure logout sequencing, explicit asynchronous and failure states.
- Firestore profile transaction, first-account creation, returning-account reuse,
  server timestamps, validation, and recovery from synchronization failures.
- Ownership-only Firestore rules, field restrictions, immutable creation time,
  and deny-by-default future collections.
- No persistent Firestore disk cache, account backup disabled, HTTPS-only
  application traffic, no app passwords or stored auth tokens in user documents.
- Explicit development/production build configuration and a registration
  importer. Missing configuration never becomes a fake user or guest bypass.
- Production build checks for configuration, final application ID, and local
  release signing credentials. Debug signing is not used for release.

## Executed checks

Flutter static analysis passed. All 47 Flutter tests, all 22 Firestore
rules tests, and all 6 registration-import tests passed. Widget rendering passed.
The final local npm dependency audit reported zero vulnerabilities.

APK build: **PASSED**. The universal debug APK was generated at
`build/app/outputs/flutter-apk/app-debug.apk`. Its Android signature, package
metadata, bundled fonts, and three native architectures were inspected. See
`APK_BUILD.md` for the final artifact hash and signing fingerprints.

The first build failed on a Maven download timeout; its automatic retry stalled
on stale NDK inventory. Restarting that specific build with the installed NDK
resolved the issue. Missing production Firebase configuration was verified to
block a release task with the intended error.

Installation, Google login, and workspace access: **PASSED, user-reported on
20 October 2026 for the previously installed app**. The installed build number
was not independently confirmed. Earlier Google cancellation and Firestore
permission failures are resolved in that report.

Build-5 phone APKs: **PASSED locally**, **34.4 MB (ARM64)** / **32.0 MB (ARM32)**.
Signatures, version codes 2005/1005, actual native/Dart Firebase configuration,
and copied artifact hashes were verified. Current files are
`build/deliverables/Hyner-build5-arm64.apk` and `Hyner-build5-arm32.apk`.

The reported Back-to-exit bug was reproduced in a failing widget test, then
fixed by preserving visited pages. Nine new navigation regressions pass. Menus
close before their underlying page; Home resets history; logout clears all
protected pages. Analysis and all 47 Flutter tests pass. **NOT TESTED:** physical
Android gestures, build-5 installation/launch, and device performance. No phone
or emulator was connected or screen accessed for this fix.

## Outstanding acceptance work

- Install build 5 as an update and verify Home → Inventory → Sales → Back →
  Inventory → Back → Home, menus, profile/settings, and logout history clearing.
- Verify live profile fields, deployed rules, cross-account isolation, document
  reuse on returning login, native logout cleanup, and restart persistence.
- Verify splash, real network-failure behavior, device layouts/accessibility,
  and measured performance. User-reported successful login does not complete
  these separate acceptance checks.
- Finalize the production Android application ID; the current development ID is
  `com.example.hyner`. Configure private production release signing before
  distribution. No paid service was enabled for this change.

## Known maintenance limitations

The current stable Firebase Auth/Core plugins still emit Kotlin Gradle Plugin
migration warnings with Flutter's current Android template. The debug build
succeeds using the template's compatibility flags. Revalidate the plugin and
Gradle combination before future major Flutter/Android Gradle upgrades. This is
not a verified failure of the current build.

The original universal debug APK remains unconfigured. The replacement ARM64 and
ARM32 profile APKs contain actual Firebase development values. No phone is
connected; the user will install build 5 manually and check native navigation.
Protected screens require an authenticated and synchronized account. UI review
images use test fixtures; they are not evidence of live Firebase authentication.

Exact instructions are in `SETUP.md`; scenario results and the device test
procedure are in `TESTING.md`. No billing activation or publication was performed. Live checks are identified
as user-reported or unverified rather than inferred from local tests.

## Future phases

No inventory, sales, purchasing, billing, customer management, reporting,
payments, supplier, return, notification, or analytics business logic has been
implemented. No business collections were added. After Phase 1 acceptance,
select the next individual feature and apply planning, implementation, testing,
fixing, and verification before any later feature. Phase 2 has not started.
