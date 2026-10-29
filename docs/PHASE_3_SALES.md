# Sales: local register behavior

The active sales architecture is local-first. The previous callable Cloud
Function checkout was replaced because it required Blaze and put ordinary
register operations in the cloud. Firebase is not used to write a new bill,
change stock, store payment status, or generate the QR.

## Bill flow

- A bill can contain multiple in-stock products.
- Each line begins with the inventory selling price. A bill-only override is
  saved with that bill and does not change the product's inventory price.
- Completing a bill writes its items, customer snapshot, pending payment state,
  stock changes and stock movement history in one local SQLite transaction.
- Bills remain on the device and appear in local Sales history.
- The local database rejects insufficient stock and applies a stock deduction
  at most once for a bill reference.

## UPI and payment status

Settings stores the merchant UPI ID and business name locally. For an INR bill,
the detail screen displays a UPI payment-intent QR with the bill total as its
amount. The customer scans it with PhonePe, Google Pay or another UPI app. Hyner
does not process the payment or receive a payment confirmation. The owner checks
their UPI app and manually marks the bill paid.

## Local data and Firebase

Products, stock history, customer details, bills and payment status are stored
on the device. There is no cloud sync or backup yet. Google sign-in remains for
workspace access. On first inventory access, a one-time import attempts to copy
the signed-in owner's previous Firestore products and stock history. A visible
Inventory warning appears if those legacy reads fail. New business changes are
not written back to Firestore.

No Cloud Function deployment or Blaze upgrade is needed. See
[Local Sales and UPI setup](PHASE_3_SETUP.md) for the phone workflow and data
limits.

## Validation status

Flutter analysis reported no issues. The ARM64 profile APK
`build/deliverables/Hyner-build2011-arm64.apk` built successfully as version
1.3.3 / Android version code 4011. Its package is `com.example.hyner`, its ABI
is ARM64, and its signing certificate matches build 9.

Flutter tests were not run in this change. The APK was not installed on a
physical phone; legacy import against the live project and end-to-end UPI scan
and payment were not performed.
