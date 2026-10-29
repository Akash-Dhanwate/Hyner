# Purchases, customer history and reports

These modules use the same account-scoped SQLite database as inventory and
sales. They do not require Firestore writes, Cloud Functions or Firebase Blaze.

## Purchases

Open **Purchases → Record purchase**, optionally choose a supplier, add as many
different inventory products as needed, then enter each received quantity and
purchase unit cost. Saving records the supplier invoice, adds stock and updates
the product's weighted-average cost in one transaction. The product's selling
price does not change.

Open a purchase record to manually mark the supplier invoice paid after paying
outside Hyner, or record items returned to the supplier. A return records its
reason, reduces available stock and cannot exceed the remaining purchase
quantity or the stock currently on hand. Supplier details are managed from the
Purchases page and can be left blank on a purchase.

## Customer bill history

Open a customer from **Customers** to see bills saved for that customer, their
totals and manual payment status. **Build bill for this customer** opens a new
bill with that customer selected. Existing customer details and bill snapshots
stay on this device.

## Reports

Select a currency and one of Today, This month, Last 30 days or All time. The
report shows bill totals and paid/unpaid amounts, estimated gross profit, cost
of goods sold, current stock value, purchase totals and supplier returns, plus
top products by units sold. Currencies are never combined or converted.

Gross profit uses the cost saved with each bill. Older bills without a cost
snapshot are called out and excluded from the gross-profit estimate. The report
does not include taxes, operating expenses or payment-provider settlement; use
it as an operational summary rather than an accounting statement.

## Storage and verification

Records remain in the signed-in account's local database file. Google sign-in
does not synchronize that file, and clearing app data or uninstalling may
remove the business records. Flutter static analysis passed for this update;
automated tests and physical-device installation are separate verification
steps.
