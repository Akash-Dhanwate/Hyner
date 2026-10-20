# UI review images

These images are rendered directly from the Flutter widgets at 390 × 844 logical
pixels, with the bundled Manrope and Material Icons fonts. They are layout review
artifacts, not photographs of a running Android device.

**All signed-in screens use isolated test fixtures.** Alice Test and the
example.test email address are synthetic values from `test/support/fakes.dart`.
They are never part of the application runtime, an APK, or a real Firestore account.
The sign-in image also uses test dependencies and does not demonstrate working OAuth.

- `welcome.png` — welcome and Hyner branding.
- `sign-in.png` — Google Sign-In layout.
- `dashboard-test-fixture.png` — workspace with presentation-only modules.
- `inventory-test-fixture.png` — the shared module placeholder layout.
- `profile-test-fixture.png` — account information layout.
- `settings-test-fixture.png` — appearance preferences.
- `dashboard-dark-test-fixture.png` — dark theme.

Regenerate with:

```sh
./tool/flutterw test tool/render_screens_test.dart
```
