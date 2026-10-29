# Hyner — foundation architecture

Current implementation (27 October 2026): Google sign-in uses Firebase
Authentication. Products, stock movements, customers, suppliers, purchases,
purchase returns, bills, payment status and UPI settings are stored in SQLite
on the device. Firestore is used only for a one-time attempt to import existing
inventory. Sales do not call a Cloud Function, and payments are made and checked
in external UPI apps. Customer bill history and business reports use the local
records.

Status: local-first register is implemented in source. Sign-in, import from the
live Firestore project, and installation of the new Android build still need
device verification. Firestore rules matter only for the optional legacy
inventory import.

## Scope

An Android-first Flutter application. Authentication, local register data,
appearance preferences, and navigation are implemented. Business records stay
on the device; cloud sync and backup are not included.

## Design direction

- Visual thesis: a quiet ink-and-violet workspace with generous spacing, precise
  typography, and a geometric H monogram.
- Content plan: welcome and sign-in introduce Hyner; the dashboard gives access
  to the workspace; business modules show information entered on this device;
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

Firebase Authentication provides Google sign-in and restores the signed-in
account. Profile display data is kept locally. The account UID scopes the local
workspace database file; signing out does not erase on-device business data.

## Data

SQLite tables store products, stock movements, customers, suppliers, purchases,
purchase returns, sales, payment state and UPI settings. Sale creation and stock
deduction run in one local database transaction. Purchase creation adds stock
and updates weighted-average product cost in one transaction; supplier returns
deduct stock and create a return record. Selling prices remain independent.
Bill lines snapshot selling and cost prices for history and gross-profit
estimates. No business record is sent to Firestore. On first inventory access,
a migration attempts to copy existing products and movements from the signed-in
user's Firestore paths; it never deletes or updates the cloud copies.

## Environments and cost

Development and production are selected explicitly through build configuration.
Firebase values must come from an actual registered Firebase Android app.
Missing production configuration is a release-build failure, not a dummy value.
Firebase Spark is sufficient for Google Authentication and does not process
customer payments. Ordinary inventory and sales operations use local storage,
so they require no Cloud Function deployment or Blaze upgrade. A pre-existing
Firestore database is needed only if the user wants the one-time legacy product
import. Future cloud backup/sync would be a separate feature and deployment.

## Verification

Run Dart formatting, Flutter analysis, unit and widget tests, Firestore emulator
rules tests, and an Android build. Test cold-start authentication, real Google
Sign-In, network failures, and installation separately on a Google Play-enabled
Android device. Report PASS, FAIL, and NOT TESTED using actual evidence.

## Phase 2 Inventory extension — 23 October 2026

Inventory originally used Firestore paths under `users/{uid}/products/{SKU}`.
The active adapter is now SQLite; it retains the prior product rules and stock
movement history and offers a one-time import from those older Firestore paths.
Prices are integer minor units, stock is whole units, and product codes remain
reserved after archiving. See `PHASE_2_INVENTORY.md` for the historical cloud
schema and `PHASE_3_SETUP.md` for current behavior.
