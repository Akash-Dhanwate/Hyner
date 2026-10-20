# Hyner setup

## What is already available locally

Flutter 3.47.7 stable and Dart 3.13.5 are installed in
`/Users/akash/develop/flutter`. Android Studio, its bundled Java 21 runtime, the
Android SDK, platform tools, and command-line tools are present. Flutter doctor
validated the Android toolchain and reports all required Android licenses as
accepted. Full Xcode is unnecessary for this Android-only project.

Restart your terminal to pick up the Flutter PATH entry, or use `./tool/flutterw`.
The project has its own Git repository and no remote repository has been created.

## Required account setup

These steps require access to your Google/Firebase account. No authenticated
Firebase CLI session or accessible browser session was available during
development, so none of these cloud operations has been assumed complete.
Do not paste account passwords, private signing keys, or service-account files
into chat. Complete account login in Google's own interface.

### 1. Decide the Android application ID

Why: Firebase and Google OAuth bind the Android package name to its signing
certificate. Renaming a registered package later requires another app registration.

1. The unconfigured local debug build uses Flutter's generated
   `com.example.hyner` identifier.
2. Before registering the app you intend to ship, select the permanent reverse
   domain identifier belonging to your organization. Do not assume Hyner owns
   any particular internet domain.
3. Use that exact identifier in Firebase's Android package-name field.
4. The configuration script below extracts it from the downloaded registration
   and passes it to Android at build time. The Kotlin source namespace may stay
   `com.example.hyner`; it does not determine the installed package identifier.
5. For separate development and production installations, register separate
   package identifiers and use separate Firebase projects/configuration files.

### 2. Create the Firebase project on Spark

Why: Firebase Authentication and Firestore need an actual project owned by you.

1. Open [Firebase Console](https://console.firebase.google.com/) and sign in.
2. Click **Create a project** (or **Add project**).
3. Enter the project display name for Hyner, marking it as development if this is
   your development environment. Review the console-generated project ID.
4. Decline optional AI/Analytics integrations if prompted; they are not used here.
5. Complete Google's project-creation prompts using your account.
6. On the project overview, verify the plan is **Spark**. Do not attach a billing
   account or select an upgrade.

Phase 1 needs only Google Authentication and one standard Firestore database
within the Spark quotas. Cloud Functions, Cloud Storage, SMS authentication, and
paid backup features are not needed. Check the current
[Firebase pricing page](https://firebase.google.com/pricing) before adding services.

### 3. Obtain debug signing fingerprints

Why: Google Sign-In verifies that the installed Android package was signed by a
registered certificate. Both the package name and signing fingerprints must match.

The verified fingerprints for this machine's generated debug APK are already
recorded in [APK_BUILD.md](APK_BUILD.md). You can use those for this local debug
key, or regenerate them using the steps below.

1. Open a terminal in this project.
2. Run the signing report:

   ```sh
   cd /Users/akash/Hyner/android
   ./gradlew signingReport --console=plain
   ```

3. In the **debug** variant output, copy the **SHA1** and **SHA-256** values.
4. These certificate fingerprints are public identifiers, not private signing keys.
5. Debug fingerprints are valid only for your local debug keystore. Production
   builds need their own release certificate fingerprints; Play-distributed
   builds also need the Play App Signing certificate fingerprints.

### 4. Register the Android app

Why: This produces configuration specific to the selected package and Firebase
project. An Android application ID is not interchangeable with a Firebase project ID.

1. Open Firebase **Project overview → Android icon / Add app → Android**.
2. Enter the exact application ID selected in step 1.
3. Set the app nickname to **Hyner Android** or **Hyner Android Development**.
4. Enter the debug SHA-1 fingerprint and click **Register app**.
5. Go to **Project settings → General → Your apps → Android app**.
6. Under **SHA certificate fingerprints**, click **Add fingerprint** and add the
   debug SHA-256 fingerprint. Add SHA-1 here too if it was not supplied earlier.
7. Continue to authentication setup before downloading the final config file.

### 5. Enable Google authentication

Why: Installing the SDK does not enable the provider on your Firebase project.

1. Open **Build → Authentication → Get started**.
2. Open **Sign-in method** (or **Sign-in providers**).
3. Select **Google**, enable it, set the public app name to **Hyner**, and choose
   the project support email from your own account or organization.
4. Click **Save**.
5. Return to **Project settings → General → Your apps → Android app** and download
   a fresh **google-services.json**. Save it as
   `/Users/akash/Hyner/android/app/google-services.json`.
6. Run the configuration importer from the project root:

   ```sh
   python3 tool/configure_firebase.py --google-services android/app/google-services.json
   ```

7. If the file contains several Android clients, also pass
   `--application-id YOUR_REGISTERED_PACKAGE_NAME`.
8. If the importer reports a missing web OAuth client, verify Google is enabled
   and download the file again. Do not invent a client ID or use an Android
   OAuth client as `serverClientId`.

The Google Services Gradle plugin 4.5.0 is declared in `android/build.gradle.kts`
and applied in `android/app/build.gradle.kts`. It processes this native JSON.
The Flutter bootstrap also uses explicit `FirebaseOptions` and the real web OAuth
`serverClientId` extracted from that same JSON. Firebase's Flutter Auth/Core/
Firestore packages already manage their native SDK dependencies; no separate
Analytics dependency or manually overridden Firebase BoM is needed for Phase 1.
The importer writes an ignored `config/firebase.development.json` and never prints
its API key. Firebase client API keys are not service-account/private keys;
Firestore rules enforce database authorization.

### 6. Create Firestore and publish the tested rules

Why: The app requires a real database, and local rule tests do not publish rules
to your Firebase project.

1. In Firebase Console, open **Build → Firestore Database → Create database**.
2. Select **Standard edition** and the default database, if prompted.
3. Select the region appropriate to where the business operates. Review this
   carefully; the database location cannot be changed in place later.
4. Choose **Production mode** to start with restricted access. Do not use open
   test-mode rules.
5. Complete database creation.
6. Open the database's **Rules** tab.
7. Replace the editor contents with the complete project `firestore.rules` file.
8. Click **Publish** and confirm the console reports successful publication.
9. No collections need manual creation. The first authenticated profile
   transaction creates `users/{firebaseUid}`.

The six fields are `uid`, `displayName`, `email`, `photoUrl`, `createdAt`, and
`lastLoginAt`. User documents use Firebase UID as their document identifier.
Creation time is immutable. Timestamps are server-generated. Unknown collections,
collection listing, cross-user reads/writes, and profile deletion are denied.

### 7. Run the configured application

Why: Cloud configuration changes must be included in a fresh app build; hot
reload does not change compile-time environment values.

```sh
cd /Users/akash/Hyner
./tool/flutterw run --dart-define-from-file=config/firebase.development.json
```

Use a connected Android phone or an Android emulator image with Google Play.
Follow all device tests in `docs/TESTING.md`. Passing local tests alone does not
verify live OAuth configuration or native session persistence.

## APK builds and installation

For an unconfigured foundation build:

```sh
./tool/flutterw build apk --debug
```

For the configured development build:

```sh
./tool/flutterw build apk --debug --dart-define-from-file=config/firebase.development.json
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

For a substantially smaller AOT phone performance-test build, use the profile
commands and matching ARM64/ARM32 APK in [PERFORMANCE.md](PERFORMANCE.md).
The original universal debug APK is for development tooling.

Find **Hyner** in the Android launcher and open it. A phone must have Developer
options and USB debugging enabled, and its USB debugging authorization dialog
must be accepted on the phone. `adb devices -l` should show an authorized device.

For an emulator, open **Android Studio → Tools → Device Manager → + / Create
Virtual Device**, select a phone, then an **ARM64 Google Play** system image for
this Apple Silicon Mac. Download it, finish creation, and click its Run button.

## Production release signing

1. Finalize the production application ID, production Firebase registration,
   production database region, deployed rules, and release certificate fingerprints.
2. Create and securely back up a production upload/signing keystore using
   Android Studio **Build → Generate Signed App Bundle / APK → APK → Create new**.
   Keep all passwords and private keys local and outside version control.
3. Create the ignored `android/key.properties` locally with `storeFile` (absolute
   keystore path), `storePassword`, `keyAlias`, and `keyPassword`.
4. Replace `android/app/google-services.json` with the actual production
   registration, then import it. Always keep the native registration and selected
   Flutter environment configuration on the same Firebase project/app:

   ```sh
   python3 tool/configure_firebase.py --google-services android/app/google-services.json --environment production
   ./tool/flutterw build apk --release --split-per-abi --split-debug-info=build/symbols --dart-define-from-file=config/firebase.production.json
   ```

5. The build rejects missing production values, a template application ID, or
   missing signing configuration. It never falls back to a debug signing key.
6. Install and repeat the device checklist against the production build before
   distribution. Store submission, privacy disclosures, account deletion policy,
   and publication are separate release tasks, not completed by generating an APK.

References: [Firebase Flutter setup](https://firebase.google.com/docs/flutter/setup),
[Google authentication](https://firebase.google.com/docs/auth/android/google-signin),
[Firestore setup](https://firebase.google.com/docs/firestore/quickstart), and
[Flutter Android release guide](https://docs.flutter.dev/deployment/android).
