# Firebase connection checkpoint

Updated 20 October 2026. No screen/browser access was used for this update.

- **PASSED locally:** actual Android registration is at
  `android/app/google-services.json`; imported Flutter development values are at
  `config/firebase.development.json`. Both are excluded from Git. The importer
  creates its output with owner-only permissions.
- **PASSED locally:** Google Services Gradle plugin 4.5.0 is declared/applied.
  Native profile processing and matching native/Dart Firebase values were checked.
  Flutter dependencies already manage Auth/Core/Firestore; the unrelated native
  Analytics example was not added.
- **PASSED during earlier console troubleshooting:** SHA-1 and SHA-256 were saved
  in Firebase, and the Android OAuth client matched the development application
  ID and signing SHA-1. No credentials were invented or private keys requested.
- **PASSED, user-reported on 20 October:** Google login and workspace access now
  work after the user completed database setup. The installed build number and
  live document fields were not independently inspected.
- **PASSED locally, build 5:** ARM64/ARM32 APKs compile, signatures match the
  existing debug certificate, and actual Firebase values match both native
  resources and compiled Dart code. Navigation-only changes preserve the
  authentication and database configuration. All 47 Flutter tests pass.
- **PASSED earlier locally:** 22 Firestore rules tests and six configuration
  importer tests. Neither area changed for the navigation fix.
- **NOT TESTED:** live deployed rule contents and cross-account access, detailed
  profile field accuracy, returning-account document reuse, native restart
  persistence, and build-5 phone installation/Google login.

The earlier Google cancellation and Firestore permission-denied errors are
historical failures; the user's latest report says login and app access work.
No new Firebase console change is required for the navigation fix.

Use the matching `build/deliverables/Hyner-build5-*.apk` as an update. USB debugging
is not needed. Follow `TESTING.md` for remaining device acceptance. Hashes and
sizes are in `profile-apk-measurements.json`. The original universal debug APK
remains an unconfigured size baseline, not the current phone-test artifact.
