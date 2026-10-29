# Phone build size and performance

## Current local register APK — 27 October 2026

Build 2011 / version 1.3.3: ARM64 **36,439,507 bytes (36.4 MB)**. File:
`build/deliverables/Hyner-build2011-arm64.apk`. This profile APK includes local
Purchases, customer account history and Reports. Its package, ARM64 ABI, version
and debug signature matching build 9 were verified. SHA-256 and validation
status are in `phase4-apk-measurements.json`.
Physical-device installation, speed, installed size, memory and battery remain
NOT TESTED. This is a local profile build, not a privately signed production
release.

## Previous Sales APK — 26 October 2026

Build 9 / version 1.3.1: ARM64 **45,521,959 bytes (45.5 MB)**. File:
`build/deliverables/Hyner-build9-arm64.apk`. Its package/version, intended ABI,
existing signing certificate, zip alignment and SHA-256 were checked; see
`phase3-apk-measurements.json`. This development update has no ARM32 copy.
Physical-device speed, installed size, memory and battery behavior remain
NOT TESTED. The artifact is a local profile build, not a privately signed
production release.

## Historical Inventory APKs — 23 October 2026

Build 6 / version 1.1.0: ARM64 **35,326,577 bytes (35.3 MB)**;
ARM32 **32,901,439 bytes (32.9 MB)**. Files are
`build/deliverables/Hyner-build6-arm64.apk` and `Hyner-build6-arm32.apk`.
Signatures, single-ABI AOT contents, Firebase configuration and copied hashes
passed verification. Exact records are in `phase2-apk-measurements.json`.
Device speed, installed size, memory and battery behavior remain NOT TESTED.
The original 201.8 MB debug artifact is not the current phone build.

## Historical build-5 measurements

Updated 20 October 2026. The original universal debug APK is not a production
size or performance baseline. New AOT profile APKs were built for phone testing.
The current profile APKs contain the supplied Firebase development configuration.
These are local profile builds, not privately signed production releases. The
user reports login/workspace access now works in the prior installed app. Build 5
has not been tested on a phone.

## Measured files

- Original universal debug APK: **201,832,403 bytes**.
- ARM64 profile APK: **34,408,625 bytes** (34.4 MB), **82.95% smaller**.
  Path: `build/app/outputs/flutter-apk/app-arm64-v8a-profile.apk`.
- ARM32 profile APK: **31,967,099 bytes** (32.0 MB), **84.16% smaller**.
  Path: `build/app/outputs/flutter-apk/app-armeabi-v7a-profile.apk`.

Current manual-install copies have distinct names:
`build/deliverables/Hyner-build5-arm64.apk` and
`build/deliverables/Hyner-build5-arm32.apk`. Build 5 fixes section navigation
history so Android Back can return to the previous page. Nine new regression
tests pass. Physical-device gestures remain NOT TESTED for this update.

Exact file hashes and package-content checks are recorded in
`profile-apk-measurements.json`. These are on-disk APK bytes, not installed size,
memory usage, Play Store download estimates, or runtime performance measurements.

Both signatures passed `apksigner verify` and match the supplied SHA-1. Imported
Firebase values and the Google web client ID were verified in native resources
and compiled Dart code. Each APK contains only its intended
CPU architecture and precompiled `libapp.so`. Neither contains the Dart debug
`kernel_blob.bin` or the debug Vulkan validation layer. Material Icons were
reduced to 5,536 uncompressed bytes by icon tree shaking.

Profile builds retain performance instrumentation and the Android template marks
them debuggable. They use the local Android debug certificate. Production
configuration and release signing checks remain intact.

## Source changes

- Removed the welcome screen's explicit IntrinsicHeight layout pass, preserving
  its bottom-aligned action and scrolling with enlarged text.
- The welcome screen subscribes only to the session failure it displays.
- Account photos decode to their displayed pixel size rather than an unrestricted
  full-resolution bitmap.

Static analysis and all 47 Flutter regression tests passed after these changes.
No frame-rate or memory improvement is claimed without a physical-device trace.

## Rebuild the phone test APKs

```sh
./tool/flutterw build apk --profile --target-platform android-arm,android-arm64 --split-per-abi --build-number 5 --dart-define-from-file=config/firebase.development.json
```

To identify a connected phone's supported architectures:

```sh
adb shell getprop ro.product.cpu.abilist
```

Use the ARM64 APK if `arm64-v8a` is listed; otherwise use ARM32 if
`armeabi-v7a` is listed. Install only the matching APK. Without USB debugging, transfer it to the phone,
open it in Files, and choose Update. With an authorized debugging device:

```sh
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-profile.apk
```

The ARM64 APK version code is 2005 and ARM32 is 1005, from build number 5 plus
Flutter's ABI version offsets. Switching back to an older debug version may be
rejected as a downgrade.
Do not uninstall an app containing real data just to change build variants;
prefer increasing the local test build number.

## Verify reported lag

**NOT TESTED for build 5:** device installation, startup latency, frame timing,
memory, and battery behavior. The user reports successful login/workspace access
in the prior installed app. No Android phone is connected here. A phone model,
Android version, and the specific slow interaction are needed for targeted diagnosis.

1. Use an actual affected phone with USB debugging authorized. Complete Firebase
   setup to include authenticated-screen behavior in the measurement.
2. Run `./tool/flutterw devices` to find its device identifier.
3. Start `./tool/flutterw run --profile -d DEVICE_ID` with the Firebase development
   configuration argument above. `DEVICE_ID` must be replaced with the detected
   identifier, not a fabricated value.
4. Open the DevTools address printed by Flutter. Record cold and warm startup,
   welcome/sign-in transitions, authenticated navigation, scrolling, and theme
   changes. Repeat the same actions before comparing builds.
5. Inspect UI/raster frame times and memory using DevTools. A 60 Hz display has
   about 16.7 ms per frame; use the actual display's refresh rate when assessing
   missed frames. Keep authentication/network waiting time separate from UI jank.
6. Investigate the measured hot path before changing rendering backends, adding
   caches, or introducing more dependencies. Do not infer smoothness from an APK
   size reduction or widget-test speed.

## Future-feature checks

Adding a feature does not duplicate the Flutter engine. It can still add code,
native libraries, assets, data volume, or work on the UI thread. For each future
phase, compare APK growth and repeat target-device profiling. Introduce bounded
queries, lazy lists, and background computation when the actual feature requires
them. These are development requirements, not implemented business features.

For distribution, use a configured, privately signed release build with ABI
splits or an Android App Bundle. Flutter's current release Gradle integration
already enables code/resource shrinking. Keep debug symbols outside the shipped
APK using `--split-debug-info`, retaining them securely for crash diagnosis.
No production APK size has been measured yet.

References: [Flutter build modes](https://docs.flutter.dev/testing/build-modes),
[size guidance](https://docs.flutter.dev/perf/app-size), and
[physical-device profiling](https://docs.flutter.dev/perf/ui-performance).
