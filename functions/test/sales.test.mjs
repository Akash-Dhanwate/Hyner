import { after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { checkout, validateDraft } from '../sales.js';

// This suite refuses to use credentials or a real project.
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8080');
const app = initializeApp({ projectId: 'demo-hyner-foundation' }, 'checkout-tests');
const db = getFirestore(app);
beforeEach(async () => {
  const response = await fetch('http://127.0.0.1:8080/emulator/v1/projects/demo-hyner-foundation/databases/(default)/documents', { method: 'DELETE' });
  assert.equal(response.ok, true);
});
after(() => deleteApp(app));
const user = (uid = 'alice') => db.collection('users').doc(uid);
const productRef = (sku = 'ITEM-0', uid = 'alice') => user(uid).collection('products').doc(sku);
const saleRef = (id = 'sale1', uid = 'alice') => user(uid).collection('sales').doc(id);
const movementRef = (sku = 'ITEM-0', id = 'sale1') => productRef(sku).collection('movements').doc(id);
const product = (sku) => ({ sku, name: `Product ${sku}`, nameKey: `product ${sku.toLowerCase()}`,
  category: '', currency: 'INR', costMinor: 500, priceMinor: 1550, quantity: 10,
  reorderLevel: 2, archived: false, revision: 1, lastMovementId: 'opening1',
  createdAt: Timestamp.fromMillis(1000), updatedAt: Timestamp.fromMillis(1000) });
async function seed(count = 1, uid = 'alice') {
  const batch = db.batch(); batch.set(user(uid), { uid });
  for (let i = 0; i < count; i++) batch.set(productRef(`ITEM-${i}`, uid), product(`ITEM-${i}`));
  await batch.commit();
}
function request({ id = 'sale1', count = 1, quantity = 2, price = 1200, uid = 'alice' } = {}) {
  return { auth: { uid }, data: { id, accountUid: uid, currency: 'INR', lines: Array.from({ length: count }, (_, i) => ({
    sku: `ITEM-${i}`, name: `Product ITEM-${i}`, quantity, unitPriceMinor: price,
  })) } };
}
const rejects = (action, code) => assert.rejects(action, (error) => error.code === code);

test('checkout saves discounted bill and deducts stock without changing inventory price', async () => {
  await seed();
  assert.deepEqual(await checkout(request(), db), { id: 'sale1' });
  const bill = (await saleRef().get()).data(); const item = (await productRef().get()).data();
  assert.equal(bill.totalMinor, 2400); assert.equal(bill.items['ITEM-0'].unitPriceMinor, 1200);
  assert.equal(item.quantity, 8); assert.equal(item.priceMinor, 1550); assert.equal(item.revision, 2);
  const movement = (await movementRef().get()).data();
  assert.equal(movement.delta, -2); assert.equal(movement.reason, 'Sale sale1');
  assert.equal(movement.createdAt.toMillis(), bill.createdAt.toMillis());
});
test('100-product sale commits every line without the former five-product cap', async () => {
  await seed(100); await checkout(request({ count: 100 }), db);
  const bill = (await saleRef().get()).data();
  assert.equal(Object.keys(bill.items).length, 100); assert.equal(bill.totalMinor, 240000);
  const products = await user().collection('products').get();
  assert.equal(products.size, 100);
  assert.ok(products.docs.every((doc) => doc.data().quantity === 8 && doc.data().lastMovementId === 'sale1'));
  assert.equal((await movementRef('ITEM-99').get()).data().delta, -2);
});
test('a shortage on the last line rolls back the entire larger bill', async () => {
  await seed(20); await productRef('ITEM-19').update({ quantity: 1 });
  await rejects(() => checkout(request({ count: 20 }), db), 'failed-precondition');
  assert.equal((await saleRef().get()).exists, false);
  assert.equal((await productRef().get()).data().quantity, 10);
  assert.equal((await movementRef().get()).exists, false);
});
test('retry and simultaneous requests with the same reference deduct only once', async () => {
  await seed(6); const data = request({ count: 6 });
  await Promise.all([checkout(data, db), checkout(data, db)]); await checkout(data, db);
  assert.equal((await productRef().get()).data().quantity, 8);
  assert.equal((await user().collection('sales').get()).size, 1);
});
test('reusing a sale ID with a changed price or quantity is rejected', async () => {
  await seed(); await checkout(request(), db);
  await rejects(() => checkout(request({ price: 1100 }), db), 'already-exists');
  await rejects(() => checkout(request({ quantity: 1 }), db), 'already-exists');
  assert.equal((await productRef().get()).data().quantity, 8);
});
test('concurrent separate sales cannot oversell the same product', async () => {
  await seed();
  const results = await Promise.allSettled([checkout(request({ id: 'first', quantity: 7 }), db), checkout(request({ id: 'second', quantity: 7 }), db)]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  assert.equal((await productRef().get()).data().quantity, 3);
  assert.equal((await user().collection('sales').get()).size, 1);
});
test('unauthenticated and switched-account requests cannot save', async () => {
  await seed(); const data = request();
  await rejects(() => checkout({ data: data.data }, db), 'unauthenticated');
  await rejects(() => checkout({ ...data, auth: { uid: 'bob' } }, db), 'permission-denied');
  assert.equal((await saleRef().get()).exists, false);
});
test('each account can use the same product and sale ID without accessing another account', async () => {
  await seed(); await seed(1, 'bob');
  await checkout(request(), db); await checkout(request({ uid: 'bob', quantity: 3 }), db);
  assert.equal((await productRef().get()).data().quantity, 8);
  assert.equal((await productRef('ITEM-0', 'bob').get()).data().quantity, 7);
  assert.equal((await saleRef('sale1', 'bob').get()).data().actorUid, 'bob');
});
test('missing profile, product, archived product and currency changes reject the bill', async () => {
  await rejects(() => checkout(request(), db), 'failed-precondition');
  await seed(); await productRef().delete();
  await rejects(() => checkout(request(), db), 'failed-precondition');
  await seed(); await productRef().update({ archived: true, quantity: 0 });
  await rejects(() => checkout(request(), db), 'failed-precondition');
  await seed(); await productRef().update({ currency: 'USD' });
  await rejects(() => checkout(request(), db), 'failed-precondition');
});
test('stock changes are reread; current inventory price does not override owner-chosen price', async () => {
  await seed(); await productRef().update({ priceMinor: 2000, revision: 2, quantity: 3 });
  await checkout(request(), db);
  assert.equal((await productRef().get()).data().quantity, 1);
  assert.equal((await productRef().get()).data().priceMinor, 2000);
  assert.equal((await saleRef().get()).data().items['ITEM-0'].unitPriceMinor, 1200);
});
test('invalid prices, quantities, duplicate SKUs and arbitrary client totals are rejected', () => {
  for (const changes of [{ quantity: 0 }, { quantity: -1 }, { quantity: 1.5 }, { price: -1 }, { price: 1.5 },
    { price: 999999999999, quantity: 1000000000 }]) {
    assert.throws(() => validateDraft(request(changes).data), (e) => e.code === 'invalid-argument');
  }
  const data = request().data;
  for (const invalid of [{ ...data, lines: [] }, { ...data, lines: [data.lines[0], data.lines[0]] },
    { ...data, totalMinor: 1 }, { ...data, currency: 'XXX' }, { ...data, id: '../other' }]) {
    assert.throws(() => validateDraft(invalid), (e) => e.code === 'invalid-argument');
  }
});
test('zero price is supported for a fully discounted product', async () => {
  await seed(); await checkout(request({ price: 0 }), db);
  assert.equal((await saleRef().get()).data().totalMinor, 0);
  assert.equal((await productRef().get()).data().quantity, 8);
});
test('overall monetary and document byte limits fail before writing', () => {
  const data = request({ count: 2, quantity: 1, price: 999999999999 }).data;
  assert.throws(() => validateDraft(data), (e) => e.code === 'invalid-argument');
  const large = request({ count: 10000, quantity: 1 }).data;
  assert.throws(() => validateDraft(large), (e) => e.code === 'invalid-argument');
});
test('existing unrelated stock history cannot be overwritten by a sale', async () => {
  await seed(); await movementRef().set({ type: 'adjustment', reason: 'Existing record' });
  await rejects(() => checkout(request(), db), 'already-exists');
  assert.equal((await productRef().get()).data().quantity, 10);
  assert.equal((await saleRef().get()).exists, false);
});
