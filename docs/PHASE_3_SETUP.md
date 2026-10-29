# Local Sales and UPI setup

Current implementation: products, stock history, customers, bills, payment
status and UPI settings are saved in SQLite on the Android device. The app does
not call a payment processor or Cloud Function for sales. Firebase Blaze is
not needed for this flow.

## Firebase

Google sign-in remains enabled. On first inventory access, the app attempts to
copy the signed-in owner's older product catalogue and stock history from the
existing Firestore database into local storage. Keep the existing owner read
rules available until that import finishes. If the app shows an import warning,
check the connection and published inventory read rules, then refresh Inventory.
After import, normal product and bill operations are local and do not write to
Firestore.

Do not run `firebase deploy --only functions` for this version. No Blaze upgrade,
manual Firestore collection, sales index, or sales function deployment is
required. The old `functions/` checkout is not used by the local register.

## Set up the amount QR

1. Install `build/deliverables/Hyner-build2011-arm64.apk` (version 1.3.3,
   Android version code 4011) as an update. Build 9 is older and still uses the
   previous cloud checkout path.
2. Open **Settings → UPI payment QR**.
3. Enter your merchant UPI ID and the business name that should appear in the
   customer's UPI app. Save the details on the device.
4. Build a bill with INR products and tap **Save bill and continue**.
5. Show the QR to the customer. Their UPI app receives the exact bill amount.
6. Check the payment in your own UPI app. Only after confirming receipt, tap
   **I verified payment · Mark as paid** in Hyner.

The QR is a standard UPI payment intent. Hyner does not collect credentials,
move money, receive payment callbacks, or verify settlement. The paid marker is
the owner's manual confirmation. UPI QR is shown only for INR bills.

## Local data behavior

- Bills and stock deductions are committed together in a local SQLite
  transaction.
- Customer details and the bill's customer snapshot stay on the device.
- Customer account history shows locally saved bills and their manual payment
  status.
- Purchase records add received stock and update weighted-average cost while
  leaving each product's selling price unchanged. Supplier returns reduce stock.
- Reports summarize sales, payment status, purchase activity and stock value
  for one selected currency and period. Gross profit is an estimate based on
  cost snapshots saved with new bills.
- Changing a bill line's price does not change the inventory selling price.
- The app has no cloud backup or multi-device sync in this version. Clearing
  app data or uninstalling Hyner can remove local business records.
- Google sign-in identifies the workspace; it does not sync local business
  records.
