# Phase 2 Inventory verification

23 October 2026. **Implemented locally; live/device acceptance pending.**
The owner authorized Phase 2 and deferred profile editing and alternative login.

## Implemented

- Active/archived product catalogue, bounded pagination and server prefix search
  by name or immutable, account-unique uppercase product code.
- Add/view/edit products: name, optional category, explicit currency, exact cost
  and selling price, opening whole-unit stock and low-stock threshold.
- Atomic opening balance and explicit positive/negative adjustments, with a reason,
  matching before/after history, server timestamps and same-operation retry IDs.
- Negative stock and stale revision rejection. Products with stock cannot be
  archived. Archive/restore keeps product identity and movement history; deletion
  and history modification are forbidden by rules.
- Busy/error/retry states, dirty-form Back confirmation, network-result warning,
  payload freezing during uncertain saves, UID-specific state and late-result guards.
- Inventory marked available on the dashboard. Other business modules remain
  placeholders. Account login/profile behavior and production release guards
  remain unchanged. No new dependency or paid service was added.

## PASSED

1. **Flutter:** 80 unit/widget tests. Eleven domain/codec tests, seven Inventory
   state tests, fifteen Inventory UI tests and the existing 47 foundation tests.
   New cases cover exact amounts, invalid data, account switching, late responses,
   list retry/pagination, form validation, create/edit, stock history, negative
   stock, archive/restore, uncertain network retry, stale edits, double submission,
   unsaved Back and 320 × 568 layouts with 1.6× text in both themes/keyboard states.
2. **Firestore emulator:** 51 actual rules tests, including original profile cases,
   own-account products/history, atomic creation/adjustment, malformed/forged writes,
   bounded reads, immutable history, archive restrictions, duplicate movement IDs,
   cross-user and collection-group denial, and concurrent stale adjustments.
3. **Static analysis:** no errors, warnings or lints. Dart formatting checked.
4. **Visual review:** five widget-rendered, explicitly labelled fixture images,
   with bundled fonts; reviewed locally without accessing the user's screen.
5. **Android build:** ARM64 and ARM32 profile APKs, version 1.1.0/build 6.
6. **Artifact verification:** signatures match the previous app certificate;
   version codes 2006/1006; actual native and compiled Dart Firebase values match;
   intended ABI only; AOT present; debug Dart kernel/validation layer absent;
   known test-account identifiers absent; copied APK SHA-256 hashes match.

ARM64: **35,326,577 bytes (35.3 MB)**.
ARM32: **32,901,439 bytes (32.9 MB)**.
Hashes and full package checks: `phase2-apk-measurements.json`.

## Failures found and resolved

Small-screen search dropdown overflow, a constrained low-stock row overflow,
and the stock dialog's keyboard-height overflow were reproduced and fixed.
Unit tests were adjusted to keep providers actively observed, matching widget
consumption. A sandbox-only localhost restriction prevented one full test run
from starting; the rerun with the existing test-runner permission passed all 80.

## NOT TESTED / remaining acceptance

- Live rule publication and composite-index readiness: owner confirmation pending.
- Native Flutter Inventory repository on an Android device/live Firestore.
  Emulator tests use the web SDK; UI/state tests use controlled repositories.
  The emulator does not prove live indexes exist.
- Build-6 installation/launch, live account isolation, real product persistence
  after restart, stock retries across real connectivity failures, hardware/swipe
  Back, TalkBack and physical-device performance.
- Privately signed production release distribution. These APKs are locally signed
  profile builds. The development package remains `com.example.hyner`.

No live Firestore business data was created, changed or deleted for this work.
Do not mark Phase 2 complete until the setup/device checklist in
`PHASE_2_SETUP.md` is confirmed and any observed failures are fixed.

## Limits and deferred work

Whole units only, one owner's account catalogue, prefix (not full-text) search,
manual refresh for changes on another device, four explicit currencies without
conversion, no photos/barcodes/notifications. Transaction writes require internet.
A retry reuses the operation ID while its form is open. Pending commands are not
persisted across app restarts; after an uncertain result and restart, inspect
server stock/history before another adjustment. SKU uniqueness includes archives.

The existing build emits Firebase Kotlin migration, SDK XML tooling, and unused
Cupertino font-family warnings; the build succeeds. No toolchain/plugin upgrades
were mixed into this feature. Sales, purchases, billing, customer management,
reporting and additional authentication remain future work.

## Reproduce

```sh
./tool/flutterw analyze
./tool/flutterw test --concurrency=2 --reporter expanded
npm run test:rules
./tool/flutterw test tool/render_inventory_test.dart
./tool/flutterw build apk --profile --no-pub --target-platform android-arm,android-arm64 --split-per-abi --build-number 6 --dart-define-from-file=config/firebase.development.json
```
