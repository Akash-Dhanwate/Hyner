# Hyner

An Android business register built with Flutter. Firebase is used for Google
sign-in; products, stock history, customers, supplier purchases, bills, paid
status and UPI details live in a local SQLite database on the device. UPI QR
codes prefill the bill's exact INR amount. Customers pay through their own UPI
app; the owner checks receipt and marks the bill paid in Hyner. Hyner does not
process or verify payments. Customer bill history, supplier returns and currency-separated
business reports are also available locally. There is no cloud sync or backup
in this version.

The current source saves new business records on-device. On first inventory
access it attempts a one-time import of the signed-in owner's previous product
catalogue and stock history from Firestore. Existing cloud Sales were not
available in the prior build because the checkout function had not been
deployed. This local-first UPI flow does not require Blaze or a Cloud Function.
Profile editing and additional sign-in methods are deferred at the owner's request.

## Local development

Validated SDK: Flutter 3.47.7 stable / Dart 3.13.5. Android minimum: API 24.
The local Flutter SDK is installed at `/Users/akash/develop/flutter` and has been
added to the login-shell PATH. `tool/flutterw` also locates that installation.

```sh
cd /Users/akash/Hyner
./tool/flutterw pub get
./tool/flutterw analyze
./tool/flutterw test
./tool/flutterw build apk --debug
```

The debug APK is written to `build/app/outputs/flutter-apk/app-debug.apk` when
the build succeeds. Its generated development application ID is
`com.example.hyner`; this is not a finalized production identifier.

## Connect actual Firebase services

Follow [the console setup guide](docs/SETUP.md), then run:

```sh
python3 tool/configure_firebase.py --google-services android/app/google-services.json
./tool/flutterw run --dart-define-from-file=config/firebase.development.json
```

Save the real Android registration as `android/app/google-services.json` first.
The script extracts its actual values and supplies the registered Android
application ID. No client identifiers or API keys are invented. The native Google
Services Gradle plugin and Flutter initialization use that same registration. Project
configuration and signing credentials are excluded from Git.

## Current installable build

- `build/deliverables/Hyner-build2011-arm64.apk` — version 1.3.3, Android
  version code 4011, package `com.example.hyner`, ARM64. Includes local
  Purchases, customer account history, and Reports.
- It is signed with the same development certificate as build 9 and can be
  installed as an update. **NOT TESTED on a physical phone.**
- Build 9 (`Hyner-build9-arm64.apk`) predates local SQLite bills, manual payment
  status and UPI QR. No Cloud Function deployment or Blaze upgrade is needed
  for the current flow. See [local Sales and UPI setup](docs/PHASE_3_SETUP.md).

## Security tests

Requires Node.js 22 or newer and Java 21. Node 26.7.0 was used for this build.

```sh
npm ci
npm run test:rules
npm audit
```

The test runner downloads Google's Firestore emulator, verifies its pinned
SHA-256 checksum, binds to loopback, and uses the reserved local project
`demo-hyner-foundation`. It never creates or connects to a live Firebase project.
It refuses to run if port 8080 is already occupied and stops its own emulator
after testing. The Firebase JavaScript packages are development dependencies
only and are not included in the Android application.

## Project structure

```text
android/                  Android application and native branding
assets/branding/          Hyner SVG, launcher artwork, official Google G
assets/fonts/             Bundled Manrope font and its OFL license
lib/app/                  Bootstrap, dependencies, configuration, routing, theme
lib/core/                 Shared error mapping and reusable widgets
lib/features/auth/        Google/Firebase adapter and session controller
lib/features/profile/     Profile model, local adapter, account screen
lib/features/inventory/   Product/stock domain, SQLite adapter and legacy import
lib/features/sales/       Local bills, stock deductions, payment status and UPI QR
lib/features/customers/   On-device customer directory and bill history
lib/features/purchases/   Supplier directory, purchase records and returns
lib/features/reports/     Local sales, payment, stock and purchase summaries
lib/features/onboarding/  Splash and welcome
lib/features/dashboard/   Workspace landing screen
lib/features/settings/    Appearance and local UPI QR configuration
lib/features/workspace/   Business module navigation
test/                     Unit and widget tests with isolated test repositories
rules_tests/              Firestore authorization and validation tests
tool/                     Flutter wrapper, configuration, rendering, rule runner
docs/                     Architecture, setup, testing, and current status
```

## Review and handoff

- [Architecture and scope](docs/ARCHITECTURE.md)
- [Firebase, Android identity, and signing setup](docs/SETUP.md)
- [Automated results and device test procedure](docs/TESTING.md)
- [Phase 1 checkpoint](docs/PHASE_1_STATUS.md)
- [Phase 2 Inventory scope](docs/PHASE_2_INVENTORY.md)
- [Inventory Firebase setup and device checklist](docs/PHASE_2_SETUP.md)
- [Phase 2 validation](docs/PHASE_2_RESULTS.md)
- [Sales implementation and validation](docs/PHASE_3_SALES.md)
- [Sales Firebase setup and phone checklist](docs/PHASE_3_SETUP.md)
- [Purchases, customer history, and reports](docs/PHASE_4_PURCHASES_REPORTS.md)
- [Verified APK and debug certificate fingerprints](docs/APK_BUILD.md)
- [Smaller phone APKs and performance verification](docs/PERFORMANCE.md)
- [UI review images](docs/previews/README.md)

Production builds require real production configuration, a final application ID,
and a locally held release signing key. Release builds never use debug signing.
No service-account keys, passwords, business data, or paid services have been added.
Authentication providers and profile fields were not changed.
