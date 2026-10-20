# Firebase build configuration

The actual Firebase Android registration belongs at
`android/app/google-services.json` and is ignored by Git. Do not create dummy values.

After enabling Google authentication for your registered Firebase Android app,
download its actual `google-services.json` and run:

```sh
python3 tool/configure_firebase.py --google-services android/app/google-services.json
./tool/flutterw run --dart-define-from-file=config/firebase.development.json
```

The Google Services Gradle plugin is declared in `android/build.gradle.kts` and
applied in `android/app/build.gradle.kts`; it processes the native registration.
The importer also supplies FirebaseOptions, the web OAuth client ID, and the
registered Android package name to the Flutter build. Both must come from the
same active `google-services.json`. Generated configs
are ignored by Git. Firebase client API keys identify an app; database access is
protected by Authentication and deployed Firestore rules, not by hiding those keys.
Never put service-account keys, passwords, or signing credentials here.

When changing environments, put that environment's real registration at
`android/app/google-services.json` before importing it and building. For production
use `--environment production` with the production registration.
See `docs/SETUP.md` for full console instructions and signing requirements.
