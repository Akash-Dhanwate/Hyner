# Verified Android build

Build date: 19 October 2026.

For current phone performance testing, use the newer **34.4 MB ARM64** or
**32.0 MB ARM32** profile APKs described in [PERFORMANCE.md](PERFORMANCE.md).
The original universal debug artifact below is retained as the size baseline.
Build 5 was compiled and verified on 20 October 2026; its distinct installable
copies and hashes are in `profile-apk-measurements.json`. The user reports login
and workspace access working in the prior installed app. Build-5 phone
installation and Back gestures remain NOT TESTED.

- **PASSED — debug build:** `./tool/flutterw build apk --debug`.
- Artifact: `build/app/outputs/flutter-apk/app-debug.apk`.
- Size: 201,832,403 bytes (universal debug build, not release-optimized).
- APK SHA-256: `bf581f90eab27dd4608837b8bd108b084a74c9a1983ce9ee58b2c24737ed84ab`.
- Application label: **Hyner**.
- Development application ID: `com.example.hyner`.
- Version: `1.0.0`, version code `1`.
- Minimum Android API: **24** (Android 7.0).
- Target / compile Android API: **36**.
- Native ABIs: `armeabi-v7a`, `arm64-v8a`, `x86_64`.
- Launcher activity: `com.example.hyner.MainActivity`.
- **PASSED — signature:** Android `apksigner verify --verbose --print-certs`
  verified its APK Signature Scheme v2 signature using the local Android debug key.
- **PASSED — bundled resources:** Manrope, Material Icons, and Google's sign-in
  image are present. The adaptive launcher icon and application label appear in
  Android package metadata.
- **PASSED — merged security settings:** backup and cleartext traffic disabled;
  Android data-extraction exclusions are attached. The build is intentionally
  marked debuggable because it is a local development build.

This APK has **no live Firebase configuration**. It displays welcome/sign-in with
an explicit setup notice and disabled Google sign-in. It never uses a fake user
to access the dashboard. Configure an actual Firebase registration and rebuild
before testing real authentication and profiles.

## Debug certificate fingerprints

These are the public certificate fingerprints of the key that signed this APK.
They can be registered in Firebase **Project settings → General → Your Android
app → SHA certificate fingerprints**. They are not private signing credentials.

SHA-1:

```text
CE:7E:4F:34:BC:7E:82:22:C7:D0:AE:AC:A4:57:CE:61:68:27:85:73
```

SHA-256:

```text
AB:DC:30:9A:A7:93:AD:B3:E7:62:26:FD:8A:6A:98:0A:00:BD:C3:93:02:2C:95:EF:89:56:C8:A8:D1:0A:85:17
```

Use fingerprints from the production release certificate or Play App Signing
certificate for production builds. Debug fingerprints must not be substituted
for those certificates.

## Install and verify

```sh
adb devices -l
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Open **Hyner** from the device launcher. Installation, native splash, Android
startup, real Google sign-in, and live Firestore synchronization are **NOT TESTED**
because no Android phone or virtual device was available. Follow `SETUP.md` and
the device checklist in `TESTING.md`; the successful build/signature checks above
do not replace that testing.

An unconfigured release task was tested separately and correctly rejected with
“Production Firebase configuration is required.” A configured, privately signed
production APK has **NOT BEEN BUILT**.
