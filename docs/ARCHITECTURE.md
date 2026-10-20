# Hyner — Phase 1 architecture

Status: implementation in progress. Phase 1 is not complete until real Firebase
authentication, Firestore rules, session restoration, and Android installation
have been verified.

## Scope

An Android-first Flutter application. Authentication, profile retrieval, logout,
appearance preferences, and navigation belong to this phase. Inventory, sales,
purchases, customers, and reports have presentation-only placeholders. No business
data, fabricated transactions, or business collections are introduced.

## Design direction

- Visual thesis: a quiet ink-and-violet workspace with generous spacing, precise
  typography, and a geometric H monogram.
- Content plan: welcome and sign-in introduce Hyner; the dashboard gives access
  to the workspace; modules explain their future purpose without invented data;
  profile and settings expose real account state and appearance controls.
- Interaction thesis: short fade transitions, clear asynchronous feedback, and
  smooth theme changes, respecting the device's reduced-motion preference.

## Boundaries

Features own their presentation, domain models/contracts, and data adapters.
Riverpod provides state management and dependency injection without code
generation. go_router protects routes according to Firebase authentication.
Firebase SDK objects stay inside data adapters; widgets consume plain models.

Protected pages share the `WorkspaceShell` layout on a single Navigator. Each
section/profile/settings entry uses a push, skipping the currently visible
route; Home explicitly resets to the dashboard. The Scaffold drawer belongs to
its page so Back closes local overlays before popping that page. Session
redirects clear protected history on logout and public history after login.
No custom Back interception or authentication bypass is used.

The bootstrap layer initializes Firebase only when real configuration exists.
A missing configuration produces an explicit setup state. There is no guest
session, hardcoded Firebase project, fallback user, or authentication bypass.
Tests may replace repositories through the dependency-injection boundary.

Authentication and profile synchronization are separate operations. A Firestore
failure after successful authentication must be visible and retryable; it must
not silently authorize access to an incomplete account. Session restoration
uses Firebase Authentication's native persistence. Account state is scoped to
the UID and disposed on logout.

## Data

Only `users/{uid}` is required. The document contains uid, displayName, email,
photoUrl, createdAt, and lastLoginAt. Server timestamps determine creation and
login times. Rules deny all unspecified paths, prevent cross-user access and
collection listing, validate fields, and protect immutable account fields.
Firestore disk persistence is disabled in Phase 1 to avoid leaving account
profile records in a shared-device disk cache. Auth session persistence remains
managed by Firebase Authentication.

## Environments and cost

Development and production are selected explicitly through build configuration.
Firebase values must come from an actual registered Firebase Android app.
Missing production configuration is a release-build failure, not a dummy value.
Use Firebase Spark with Google Authentication and one Firestore database.
Phase 1 does not require Cloud Functions or Cloud Storage.

## Verification

Run Dart formatting, Flutter analysis, unit and widget tests, Firestore emulator
rules tests, and an Android build. Test cold-start authentication, real Google
Sign-In, network failures, and installation separately on a Google Play-enabled
Android device. Report PASS, FAIL, and NOT TESTED using actual evidence.
