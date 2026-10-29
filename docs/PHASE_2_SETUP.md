# Enable Inventory in the existing Firebase project

The old Phase 1 rules deliberately deny product paths. Inventory also needs
two composite indexes for its account-scoped, ordered search. These changes use
the existing database and Spark quotas. No new project, credentials, JSON,
billing upgrade or app authentication change is needed.

Do these steps in your own browser. No screen access or password sharing is
required. Do not assume a live change is complete until you confirm it.

## 1. Publish the tested rules

1. Open [Firebase Console](https://console.firebase.google.com/) and select the
   same Hyner project used by your currently working login.
2. Open **Firestore Database** (under **Build**, or **Databases & Storage →
   Firestore**, depending on the console layout).
3. Select the existing **(default)** database. Do not create another database.
4. Open its **Rules** tab.
5. Open `/Users/akash/Hyner/firestore.rules` in VS Code. Copy the entire file.
6. Replace the entire Rules editor content with that file and click **Publish**.
7. Confirm there are no compilation errors and the console shows the published
   rules. Profile ownership rules remain included; do not paste only the
   inventory section or switch to test mode.

Why: the tested rules permit only each signed-in owner's products and movement
history, validate field types, and require atomic stock/history updates. A rule
such as `allow read, write: if request.auth != null` is not an acceptable substitute.

## 2. Create both composite indexes

1. In the same database, select **Indexes → Composite**.
2. Click **Add index** / **Create index**.
3. Set **Collection ID** to `products`.
4. Add field `archived`, direction **Ascending**.
5. Add field `nameKey`, direction **Ascending**.
6. Set **Query scope** to **Collection**, then click **Create**.
7. Create a second index with **Collection ID** `products`, field `archived`
   **Ascending**, field `sku` **Ascending**, scope **Collection**.
8. Leave the automatically added document-name ordering unchanged. Wait until
   both indexes show **Enabled** / ready rather than **Building**.

Why: these support the Active/Archived catalogue and prefix name/code search.
The emulator verifies rules and queries but does not verify that live composite
indexes exist. Index creation can take several minutes.

The exact deployment definitions are in `firestore.indexes.json`, linked from
`firebase.json`. If a trusted Firebase CLI is already configured, it can deploy
the same rules and indexes to your explicitly selected project; installing a
CLI or changing billing is not required for this manual workflow.

## 3. Confirm, then install and test

Tell the developer **Rules published; both indexes enabled**. The live setup
remains NOT VERIFIED until that confirmation; local builds may be prepared
independently. Then transfer the matching `Hyner-build6-*.apk` to your phone and
install it as an **Update**. Keep the current app installed. USB debugging is
not required.

1. Open Inventory. With a genuinely empty account, it should show **No products
   yet**, without an access/index error.
2. Add a disposable test product with a unique product code, explicit currency,
   cost `10.10`, selling price `15.50`, opening stock `5`, threshold `2`.
3. Open it. Check the fields and **Opening stock: 0 → 5** in Stock history.
4. Edit its name and selling price. Quantity must remain `5`; SKU and currency
   must stay fixed.
5. Add `3` units with a reason. Check stock becomes `8` and the movement is shown.
6. Attempt to remove `9`; it must fail without a saved change. Remove `8` with
   a reason; stock becomes `0` and **Out of stock** appears.
7. Archive the product. Check Archived finds it and its history remains. Restore
   it and verify it returns to Active.
8. Search using the start of a name, then by product code. Refresh and check
   products persist after restarting the app.
9. Test an interrupted connection. No failed save may be presented as successful.
   An uncertain result keeps the submitted values for a retry using the same
   operation ID. If you leave/restart, refresh and inspect the saved product and
   history before submitting another adjustment; pending requests are not stored
   across app restarts in this slice.
10. Visit Home → Inventory → product → Edit. Check Back/unsaved-change handling.
    Sign out, switch accounts, and confirm the previous products and profile
    never appear. Use disposable data for this verification.

Record device model, Android version, APK build, and each result as PASSED,
FAILED or NOT TESTED. No live data migration or example products are inserted.

References: [Firebase index setup](https://firebase.google.com/docs/firestore/query-data/indexing),
[atomic rules](https://firebase.google.com/docs/firestore/security/rules-conditions),
[transactions and offline behavior](https://firebase.google.com/docs/firestore/manage-data/transactions),
[Spark pricing](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans).
