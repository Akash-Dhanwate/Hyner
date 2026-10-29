# Phase 2 — Inventory

Started 23 October 2026 at the owner's request. Phase 1 is accepted by the
owner for continuing development; historical untested device/cloud checks remain
documented in `TESTING.md`. They are not retroactively marked passed.

## Scope and order

1. Product model, validation, account-scoped repository and Firestore rules.
2. Product catalogue, creation, editing and archive/restore, with automated checks.
3. Opening balances, explicit stock adjustments and immutable movement history.
4. Navigation, account isolation, failures, layouts and APK verification.
5. Owner publishes the tested rules and performs device/live acceptance.

General retail, whole units is the working assumption. SKU/product code is
required, uppercase, unique within the account, and immutable. Archived codes
cannot be reused. Name/category and prices can be edited. Prices are integer
minor units, never binary floating-point amounts. Currency is selected explicitly
at creation (INR default, USD/EUR/GBP also supported) and remains immutable.
Maximum stock/threshold: 1,000,000,000 units. Negative stock is rejected.
No photos, fractional stock, barcode scanning or push notifications in this slice.

Inventory queries are bounded and paginated. Prefix search by product name or
code is server-side. Active and archived lists are separate. Low-stock labels
use the actual product quantity and threshold; no invented totals are shown.
Writes require connectivity. There is no pretend local save/offline queue.

## Boundaries

`lib/features/inventory/domain/`: product/movement types, exact parsers and
validation, repository contract and page cursor values.
`data/`: Firestore transactions, strict decoding and inventory-specific errors.
`presentation/`: UID-scoped Riverpod state and list/detail/form screens.

Data lives under `users/{uid}/products/{SKU}` and
`users/{uid}/products/{SKU}/movements/{operationId}`. Existing profile paths and
sign-in behavior are preserved. No shared business/team access is introduced.
Creation and stock changes atomically write the product and matching movement.
Rules validate the before/after quantities, revision, actor, timestamps and
matching operation ID. Movements and products cannot be deleted. Archive requires
zero stock. Repeated stock submissions with the same operation ID do not apply
the quantity twice. Stale edits fail visibly rather than overwriting newer data.

Each new account selection resets inventory state. Late reads/writes from a
previous account cannot populate the next account's UI.

## UI direction

Visual thesis: Hyner's quiet violet workspace with plain product rows, readable
stock counts and one clear primary action.
Content plan: catalogue and search first; product facts and actions on detail;
focused forms; movement history with dated before/after quantities.
Interaction thesis: existing short page fades, Material form/sheet transitions,
and clear inline progress/retry feedback respecting reduced-motion settings.

## Cost and manual setup

Uses the existing Firestore database, transactions and indexes, compatible with
Spark quotas. No paid service, Storage, Cloud Functions or new package is needed.
Each stock transaction writes two documents; reads/rules checks also consume
quota. See [Firestore pricing](https://firebase.google.com/docs/firestore/pricing).

After local rule tests pass, publish the complete updated `firestore.rules` in
Firebase Console → the existing Hyner project → Build → Firestore Database →
Rules → replace the editor content → Publish. This enables owner-only inventory
paths; the Phase 1 rules intentionally deny them. Do not enable test mode or
globally allow authenticated users. No new database or configuration JSON is
required. Live publication requires the owner's confirmation and is never
assumed complete. No screen access is required.

## Deferred at the owner's request

Profile editing and additional sign-in methods (email/password or phone) are
later account-management work. No authentication provider changes in Phase 2.
Sales, billing, purchases, suppliers, customer operations, returns, payments,
profit/loss, business analytics and notifications remain future features.

References: [transactions](https://firebase.google.com/docs/firestore/manage-data/transactions),
[atomic rule validation](https://firebase.google.com/docs/firestore/security/rules-conditions),
[query cursors](https://firebase.google.com/docs/firestore/query-data/query-cursors).
