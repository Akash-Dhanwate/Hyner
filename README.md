# Hyner

A Flutter application foundation for an Android business workspace. Phase 1
contains Google/Firebase account integration, profile synchronization, navigation,
branding, and appearance settings. Business modules are clearly marked placeholders.

**Phase 1 is not complete:** configured phone-test APKs now include the supplied
Firebase registration. The user reports successful login and workspace access;
restart persistence, live account-isolation checks, and full Android acceptance
remain pending. An unconfigured debug build shows welcome and
sign-in with an explicit setup notice. It never creates a fake account or opens
protected routes.

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

## Smaller phone test builds

For phone performance evaluation, use the precompiled profile APKs instead of
the original 201.8 MB universal debug APK:

```sh
./tool/flutterw build apk --profile --target-platform android-arm,android-arm64 --split-per-abi --build-number 5 --dart-define-from-file=config/firebase.development.json
```

The verified ARM64 APK is **34.4 MB** and ARM32 is **32.0 MB**. They are local
profile builds containing the actual Firebase development configuration.
See [performance results and instructions](docs/PERFORMANCE.md).
Current manually installable copies are `build/deliverables/Hyner-build5-arm64.apk`
and `build/deliverables/Hyner-build5-arm32.apk`. Build 5 preserves section history
for Android Back, dismisses open menus first, avoids duplicate selections, and
clears protected history on logout. All 47 Flutter tests and analysis pass.
Native gestures and installation of build 5 are NOT TESTED on a phone.

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
lib/features/profile/     Profile model, Firestore adapter, account screen
lib/features/onboarding/  Splash and welcome
lib/features/dashboard/   Workspace landing screen
lib/features/settings/    Persisted light/dark/device appearance
lib/features/workspace/   Navigation and shared placeholder presentation
lib/features/*/           Presentation-only business module entry points
test/                     Unit and widget tests with isolated test repositories
rules_tests/              Firestore authorization and validation tests
tool/                     Flutter wrapper, configuration, rendering, rule runner
docs/                     Architecture, setup, testing, and current status
```

## Review and handoff

- [Architecture and scope](docs/ARCHITECTURE.md)
- [Firebase, Android identity, and signing setup](docs/SETUP.md)
- [Automated results and device test procedure](docs/TESTING.md)
- [Phase 1 status](docs/PHASE_1_STATUS.md)
- [Verified APK and debug certificate fingerprints](docs/APK_BUILD.md)
- [Smaller phone APKs and performance verification](docs/PERFORMANCE.md)
- [UI review images](docs/previews/README.md)

Production builds require real production configuration, a final application ID,
and a locally held release signing key. Release builds never use debug signing.
No service-account keys, passwords, business data, paid services, or Phase 2
features have been added.
