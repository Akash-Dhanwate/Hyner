# Hyner verification

## Current local-first checkpoint — 27 October 2026

Products, stock movements, customers, suppliers, purchases, purchase returns,
bills, payment status, UPI settings and reports now use account-scoped SQLite
databases on-device. The app attempts a one-time read-only import of legacy
Firestore products and stock history. Bill writes do not use Cloud Functions.
UPI QR codes prefill the INR bill amount; payment receipt is checked manually
in the owner's UPI app.

Flutter analysis completed with no issues. The ARM64 profile APK
`build/deliverables/Hyner-build2011-arm64.apk` built successfully as version
1.3.3 / Android version code 4011; package, ABI and matching debug signature
were checked against build 9. **NOT RUN in this change:** unit or widget tests,
physical installation, legacy import against the live project, or an end-to-end
UPI scan/payment. Build 9 is the previous cloud-checkout build. See
`PHASE_3_SALES.md`, `PHASE_3_SETUP.md` and `PHASE_4_PURCHASES_REPORTS.md`.

## Historical Phase 2 checkpoint — 23 October 2026

**PASSED:** all 80 Flutter unit/widget tests, 51 Firestore emulator tests,
static analysis, five fixture-based UI renders, and ARM64/ARM32 profile APK
builds. Signatures, version 1.1.0/build 6, native/Dart Firebase values, ABI
contents and copied hashes were checked. No dependencies were added/upgraded.

**NOT TESTED:** publishing the updated rules, enabling both live indexes,
native Flutter Inventory operations against the live project, build-6 phone
installation, restart persistence of real products, and real gesture/performance
behavior. The rules tests use the web SDK against Google's isolated emulator;
the UI/controller tests use isolated repositories. Neither is a native Android
adapter integration test. Index existence is not enforced by the emulator.

See `PHASE_2_RESULTS.md` and `PHASE_2_SETUP.md` for the current acceptance checklist.
No screen access or live data writes were performed. The owner authorized Phase 2
based on the working installed app; older untested checks below remain untested.

## Historical Phase 1 checkpoint

Updated: 20 October 2026. Platform: Apple Silicon macOS. Flutter 3.47.7 stable,
Dart 3.13.5, Java 21, Node 26.7.0. Android minimum API 24 / target API 36.

**PASSED means a check was actually executed successfully.** Test repository
results do not prove that Google OAuth, native authentication persistence, or
your live Firebase project works. Live checks distinguish user reports from
independently executed tests. Unverified scenarios remain NOT TESTED.

## Executed automated checks

- **PASSED — Flutter static analysis:** no errors, warnings, or lint findings.
- **PASSED — Flutter unit/widget tests:** 47 tests. Authentication-state
  transitions, restored identity handling, profile retry, cancellation, network
  errors, logout and in-flight request races, cross-account response rejection,
  protected routing, all screens, profile fixture accuracy, appearance persistence
  calls, write-error feedback, and 320 × 568 layouts with 1.6× text in both themes.
  Provider cleanup failures after logout remain visible on welcome, including
  after a delayed signed-out event.
  Google cancellation now remains visible with a safe provider reference;
  a small-screen retry and a Firestore failure screen are covered. Provider
  descriptions, tokens, and account details are excluded from reference messages.
  Nine new navigation regressions cover simulated system Back through sections,
  drawer and More dismissal, dashboard/profile/settings links, duplicate
  selections, Home reset, wide layouts, and Welcome/Sign-In history. The existing
  logout test now starts with several stacked protected pages and checks that
  logout clears them, including offstage profile data. Login clears public history.
- **PASSED — Firestore rules emulator:** 22 tests, using the actual
  `firestore.rules` file and Google's emulator 1.22.0. Owner creation/retrieval and
  updates succeed. Unauthenticated access, cross-user operations, collection
  listing, forged UIDs/emails, extra/missing fields, invalid types, client
  timestamps, modified creation time, insecure photo URLs, profile deletion, and
  future business collections are denied.
- **PASSED — Firebase registration importer:** 6 Python tests. Actual source
  values are preserved, API keys are not printed, the output file has restricted
  local permissions, ambiguous registrations require explicit selection, missing
  OAuth/API values are rejected, empty configuration is rejected, and production
  rejects a template package name.
- **PASSED — Widget rendering utility:** seven review images generated from
  Flutter widgets. Actual Manrope and Material Icons fonts were loaded.
- **PASSED — npm dependency audit:** zero reported vulnerabilities after removing
  the unnecessary Firebase CLI dependency and using the patched gRPC dependency.
- **PASSED — Android toolchain inspection:** Flutter doctor recognizes the SDK,
  Java runtime, and accepted Android licenses.
- **PASSED — Production configuration guard:** an offline release task without
  configuration failed with the expected “Production Firebase configuration is
  required” message. No production signing or configured release build was tested.
- **PASSED — smaller phone builds:** ARM64 and ARM32 AOT profile APKs built,
  signatures verified, single-ABI packaging and removal of the JIT debug kernel
  and Vulkan debug validation library verified. Static analysis and all 47
  Flutter tests passed after the welcome-layout and photo-decoding changes.
  Actual device frame times and memory usage are **NOT TESTED**; see `PERFORMANCE.md`.

Earlier large-text layout overflows were reproduced and fixed. The final test
run must stay green after further changes. Review images are explicitly labeled
as test fixtures in `docs/previews/README.md`; they do not show real user accounts.

## Commands

```sh
./tool/flutterw analyze
./tool/flutterw test --reporter expanded
python3 -m unittest discover -s test -p '*_test.py' -v
npm ci
npm run test:rules
npm audit
./tool/flutterw test tool/render_screens_test.dart
./tool/flutterw build apk --debug
```

The rules runner verifies the emulator SHA-256 hash, starts an isolated
loopback-only service using a reserved demo project, and terminates its own
process when finished. An already occupied port fails the run instead of
clearing a pre-existing database.

## Live/device acceptance status

1. **Google Sign-In and workspace access — PASSED, user-reported on 20 October.**
   The user confirms login and app access now work after Firebase setup. The
   previous cancellation/profile-permission errors are resolved in that report.
   First-time versus returning-account behavior was not separately recorded.
   The installed build number was not independently confirmed. Build 5 has not
   been installed or tested on a phone here.
2. **Returning user document reuse — NOT TESTED live.** Controlled repository
   tests pass; live UID, creation-time preservation, and document count need checks.
3. **Session persistence after app restart — NOT TESTED on Android.** Restored
   identity/profile behavior passes under controlled repositories.
4. **Logout — PASSED, user-reported during the earlier permission-error flow.**
   Native Google cleanup, logout after successful workspace access, and account
   switching remain NOT TESTED. Automated history-clearing and race checks pass.
5. **Login failure handling — PASSED for visible errors in earlier user reports.**
   Google cancellation and Firestore permission errors appeared with references.
   Controlled retry checks pass; intentional chooser cancellation on build 5 is
   NOT TESTED on Android.
6. **Internet failure — NOT TESTED on a device.** Controlled network-failure
   handling passes. Real airplane-mode behavior is pending.
7. **Firestore user creation — NOT TESTED by live document inspection.** The user
   reports successful workspace access; individual live fields and creation
   timestamps have not been inspected. Emulator creation checks pass.
8. **Firestore profile retrieval — NOT TESTED independently against the live
   native adapter.** The user reports workspace access after database setup;
   owner reads and fixture profile display pass in automated checks.
9. **Unauthorized database access — PASSED in 22 local rules tests on 19 October.**
   The live deployed rules and cross-account access remain NOT TESTED. Rules
   were unchanged by the navigation fix and were not rerun on 20 October.
10. **Navigation — PASSED in widget tests, including simulated system Back.**
    **FAILED in the user's earlier installed APK:** Back exits from a section.
    This was reproduced before the fix. All nine new navigation regressions pass
    after it. **NOT TESTED:** build-5 physical swipe, predictive gesture animation,
    hardware Back, and process recreation.
11. **Profile information accuracy — PASSED against fixture values.** Live account
    name, email, photo, and creation date still need a field-by-field comparison.
12. **APK installation/launch — PASSED, user-reported for the prior installed app.**
    Build 5 compiled for ARM64 and ARM32; signatures, incremented version codes,
    Firebase contents, and copied artifact hashes were verified locally.
    **NOT TESTED:** build-5 installation, native splash, and launch on a phone.

No physical device or emulator was started for this navigation change. The
user's screen was not accessed. Historical Python/rules/audit/rendering results
above were not rerun for this Dart-only change.

## Historical Phase 1 device test procedure — build 5

Prerequisites: complete `SETUP.md`, publish the rules to the intended project,
install a configured APK, and use an Android device or a Google Play-enabled
emulator. The historical build-5 copies are
`build/deliverables/Hyner-build5-arm64.apk` and
`build/deliverables/Hyner-build5-arm32.apk`. For current Sales phone acceptance,
use build 9 and follow `PHASE_3_SETUP.md`. Use separate Google accounts for
account-isolation testing. Do not use production business data for acceptance
tests.

### First-time sign-in and creation

1. Open Hyner. Check the branded native splash, then the welcome screen.
2. Tap **Get started → Continue with Google** and select a Google account.
3. Confirm the loading state prevents repeated sign-in submissions.
4. Confirm the dashboard opens only after the profile has synchronized.
5. In Firebase Console **Authentication → Users**, find the new account and UID.
6. Open **Firestore Database → Data → users → that UID**. Confirm the document ID
   and `uid` match, email/name/photo match Google (or nullable fields remain null),
   and `createdAt`/`lastLoginAt` are server timestamps. No passwords or tokens may
   appear in the document, and no business collections may be created.
7. Open **Your profile** and compare all displayed fields with the account and
   document, including the creation year. Verify photo fallback if loading fails.

### Returning login and session restoration

1. Record the UID, creation time, and number of user documents.
2. Sign out from **Your profile**. Verify welcome returns and Android Back cannot
   recover the dashboard or profile.
3. Sign in with the same Google account. Verify the same UID/document is reused,
   creation time remains unchanged, and last-login time advances.
4. While signed in, force-stop the app from Android Settings and reopen it.
   Verify the account restores without another account chooser and the correct
   profile is fetched. Repeat after removing the app from recent applications.
5. Sign in with a different account after logout. Verify no previous name, email,
   avatar, or profile date appears. Repeat by restarting after the switch.

### Failure and recovery

1. Cancel Google's account chooser. Verify welcome/sign-in remains available.
2. Enable airplane mode and attempt sign-in. Record the actual error and verify
   there is no crash or unauthorized access. Restore connectivity and retry.
3. Restart while offline with a previously authenticated account. The native auth
   session may restore, but this Phase 1 app requires a successful server profile
   fetch before workspace access. Verify a visible retry/sign-out state appears.
4. On a disposable development project, temporarily keep production-mode rules
   denying all access, then sign in. Verify account synchronization reports the
   failure and does not open the dashboard. Publish the tested rules again, tap
   **Try again**, and verify recovery. Restore the correct rules before other tests.
5. With two test accounts, run `npm run test:rules` and verify all isolation cases
   still pass. Inspect the live Rules tab to confirm the same tested file is
   published. The app never provides a way to browse another user's UID.

### Navigation, appearance, and installation

1. Visit Dashboard, Inventory, Sales, Purchases, Customers, Reports, Settings, and
   Your profile. Use the bottom bar, More sheet, drawer, and Android Back.
   From Home open Inventory, then Sales. Swipe Back once: Inventory must return;
   swipe again: Home must return. Only Back at Home may leave the app. Open a
   drawer or More sheet above a section: Back must close that overlay first.
   Open Settings then Profile: Back must return to Settings, then its prior page.
   Re-select a current section: one Back must still leave it. Choosing Home must
   clear earlier section history. Repeat with hardware Back if available. Sign
   out with several pages visited and verify Back cannot expose account data.
2. Confirm every business module is labeled as coming later, with no active
   stock/sales/billing actions, fake totals, or invented transactions.
3. Change Settings between Light, Dark, and Use device setting. Restart the app
   and verify the chosen appearance persists.
4. Test small and large phones, portrait/landscape, enlarged Android text, and
   TalkBack. Check visible labels, focus order, scrolling, photo fallback, and
   the sign-out button below the profile details.
5. Transfer the matching build-5 APK to the phone, open it in Files, and choose
   **Update**. USB debugging is not required. Open Hyner from the launcher and
   check icon, splash, and startup again after a cold start. If an authorized
   debugging device is available, use `adb install -r` with the configured APK
   instead. Do not uninstall the existing app to install this update.

Record actual device model, Android version, build version, test date, and each
result as PASSED, FAILED, or NOT TESTED. Phase 1 remains incomplete until all
required live/device acceptance checks pass.
