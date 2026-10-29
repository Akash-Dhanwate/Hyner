import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, collectionGroup, deleteDoc, doc, getDoc, getDocs, limit, orderBy, query, runTransaction, serverTimestamp, setDoc, Timestamp, updateDoc, where, writeBatch } from 'firebase/firestore';
import assert from 'node:assert/strict';

let environment;
before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-hyner-foundation',
    firestore: { host: '127.0.0.1', port: 8080, rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
beforeEach(async () => environment.clearFirestore());
after(async () => environment?.cleanup());

const database = (uid = 'alice') => environment.authenticatedContext(uid, { email: `${uid}@example.test` }).firestore();
const reference = (db, uid = 'alice') => doc(db, 'users', uid);
const profile = (uid = 'alice') => ({ uid, email: `${uid}@example.test`, displayName: 'Rules Test Account', photoUrl: null, createdAt: serverTimestamp(), lastLoginAt: serverTimestamp() });
const seed = async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(reference(context.firestore()), { ...profile(), createdAt: Timestamp.fromMillis(1000), lastLoginAt: Timestamp.fromMillis(1000) });
  });
};

test('first-time owner can create a valid profile with server timestamps', async () => {
  const db = database();
  await assertSucceeds(setDoc(reference(db), profile()));
  await assertSucceeds(getDoc(reference(db)));
});
test('returning owner can refresh profile and last-login timestamp', async () => {
  await seed();
  await assertSucceeds(updateDoc(reference(database()), { displayName: 'Updated Name', lastLoginAt: serverTimestamp() }));
});
test('an owner can retrieve their profile', async () => {
  await seed();
  await assertSucceeds(getDoc(reference(database())));
});
test('unauthenticated users cannot read profiles', async () => {
  await seed();
  await assertFails(getDoc(reference(environment.unauthenticatedContext().firestore())));
});
test('unauthenticated users cannot create profiles', async () => {
  await assertFails(setDoc(reference(environment.unauthenticatedContext().firestore()), profile()));
});
test('another user cannot retrieve a profile', async () => {
  await seed();
  await assertFails(getDoc(reference(database('bob'))));
});
test('another user cannot create a profile on behalf of the owner', async () => {
  await assertFails(setDoc(reference(database('bob')), profile()));
});
test('another user cannot modify a profile', async () => {
  await seed();
  await assertFails(updateDoc(reference(database('bob')), { displayName: 'Other User', lastLoginAt: serverTimestamp() }));
});
test('collection listing is denied even to authenticated users', async () => {
  await seed();
  await assertFails(getDocs(collection(database(), 'users')));
});
test('the stored UID cannot impersonate another account', async () => {
  await assertFails(setDoc(reference(database()), { ...profile(), uid: 'bob' }));
});
test('the email must match the authentication token', async () => {
  await assertFails(setDoc(reference(database()), { ...profile(), email: 'bob@example.test' }));
});
test('extra fields including privilege escalation are rejected', async () => {
  await assertFails(setDoc(reference(database()), { ...profile(), role: 'admin' }));
});
test('missing required fields are rejected', async () => {
  const value = profile(); delete value.photoUrl;
  await assertFails(setDoc(reference(database()), value));
});
test('client-generated creation timestamps are rejected', async () => {
  await assertFails(setDoc(reference(database()), { ...profile(), createdAt: Timestamp.fromMillis(1000) }));
});
test('client-generated login timestamps are rejected', async () => {
  await assertFails(setDoc(reference(database()), { ...profile(), lastLoginAt: Timestamp.fromMillis(1000) }));
});
test('account creation timestamp is immutable', async () => {
  await seed();
  await assertFails(updateDoc(reference(database()), { createdAt: serverTimestamp(), lastLoginAt: serverTimestamp() }));
});
test('invalid field types are rejected', async () => {
  await assertFails(setDoc(reference(database()), { ...profile(), displayName: 12 }));
});
test('oversized names are rejected', async () => {
  await assertFails(setDoc(reference(database()), { ...profile(), displayName: 'x'.repeat(201) }));
});
test('insecure photo URLs are rejected', async () => {
  await assertFails(setDoc(reference(database()), { ...profile(), photoUrl: 'http://example.test/avatar.png' }));
});
test('missing name and photo are permitted without fabricated values', async () => {
  await assertSucceeds(setDoc(reference(database()), { ...profile(), displayName: null, photoUrl: null }));
});
test('profile deletion is denied in Phase 1', async () => {
  await seed();
  await assertFails(deleteDoc(reference(database())));
});
test('future business collections deny reads and writes', async () => {
  const target = doc(database(), 'inventory', 'an-item');
  await assertFails(setDoc(target, { quantity: 1 }));
  await assertFails(getDoc(target));
});

// Inventory uses real rule evaluation and atomic operations in the isolated emulator.
const productRef = (db, sku = 'ITEM-1', uid = 'alice') => doc(db, 'users', uid, 'products', sku);
const movementRef = (db, id = 'opening1', sku = 'ITEM-1', uid = 'alice') => doc(productRef(db, sku, uid), 'movements', id);
const productData = (quantity = 10) => ({
  sku: 'ITEM-1', name: 'Test Product', nameKey: 'test product', category: 'Tests', currency: 'INR',
  costMinor: 12345, priceMinor: 15000, quantity, reorderLevel: 2, archived: false, revision: 1,
  lastMovementId: 'opening1', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
});
const openingData = (quantity = 10) => ({
  type: 'opening', beforeQuantity: 0, afterQuantity: quantity, delta: quantity,
  reason: 'Opening stock', actorUid: 'alice', revision: 1, createdAt: serverTimestamp(),
});
function creation(db, { quantity = 10, product = {}, movement = {}, uid = 'alice' } = {}) {
  const batch = writeBatch(db);
  batch.set(productRef(db, 'ITEM-1', uid), { ...productData(quantity), ...product });
  batch.set(movementRef(db, 'opening1', 'ITEM-1', uid), { ...openingData(quantity), ...movement });
  return batch.commit();
}
async function seedProduct(quantity = 10) {
  await seed();
  await assertSucceeds(creation(database(), { quantity }));
}
function adjustment(db, { delta = -2, id = 'adjust1', before = 10, revision = 2, product = {}, movement = {} } = {}) {
  const batch = writeBatch(db);
  batch.update(productRef(db), { quantity: before + delta, lastMovementId: id, revision, updatedAt: serverTimestamp(), ...product });
  batch.set(movementRef(db, id), { type: 'adjustment', beforeQuantity: before, afterQuantity: before + delta,
    delta, reason: 'Stock count correction', actorUid: 'alice', revision, createdAt: serverTimestamp(), ...movement });
  return batch.commit();
}

test('inventory owner creates a product and opening balance atomically', async () => {
  await seedProduct();
  assert.equal((await getDoc(productRef(database()))).data().quantity, 10);
  assert.equal((await getDoc(movementRef(database()))).data().afterQuantity, 10);
});
test('zero opening stock and nullable-free optional category are valid', async () => {
  await seed();
  await assertSucceeds(creation(database(), { quantity: 0, product: { category: '' } }));
});
test('a synchronized profile is required before product creation', async () => {
  await assertFails(creation(database()));
});
test('product creation without an opening movement is rejected', async () => {
  await seed();
  await assertFails(setDoc(productRef(database()), productData()));
});
test('an opening movement without a product is rejected', async () => {
  await seed();
  await assertFails(setDoc(movementRef(database()), openingData()));
});
test('unauthenticated inventory reads and atomic creation are rejected', async () => {
  await seedProduct();
  const db = environment.unauthenticatedContext().firestore();
  await assertFails(getDoc(productRef(db)));
  await assertFails(creation(db, { uid: 'other' }));
});
test('another account cannot read, list or modify inventory or its history', async () => {
  await seedProduct();
  const db = database('bob');
  await assertFails(getDoc(productRef(db)));
  await assertFails(getDoc(movementRef(db)));
  await assertFails(getDocs(query(collection(db, 'users', 'alice', 'products'), limit(30))));
  await assertFails(adjustment(db));
  await assertFails(updateDoc(productRef(db), { name: 'Other', nameKey: 'other', revision: 2, updatedAt: serverTimestamp() }));
});
test('owner list and prefix-search queries have enforced page limits', async () => {
  await seedProduct();
  const target = collection(database(), 'users', 'alice', 'products');
  await assertSucceeds(getDocs(query(target, where('archived', '==', false), orderBy('nameKey'), limit(31))));
  await assertFails(getDocs(target));
  await assertFails(getDocs(query(target, limit(51))));
});
test('history can be paginated but not read without a bound', async () => {
  await seedProduct();
  const target = collection(productRef(database()), 'movements');
  await assertSucceeds(getDocs(query(target, orderBy('createdAt', 'desc'), limit(31))));
  await assertFails(getDocs(target));
});
test('product metadata can change without changing opening balance or history', async () => {
  await seedProduct();
  await assertSucceeds(updateDoc(productRef(database()), { name: 'Renamed', nameKey: 'renamed', priceMinor: 19000,
    category: 'New category', reorderLevel: 5, revision: 2, updatedAt: serverTimestamp() }));
  assert.equal((await getDoc(productRef(database()))).data().quantity, 10);
});
test('stock adjustment and matching movement commit together', async () => {
  await seedProduct();
  await assertSucceeds(adjustment(database()));
  assert.equal((await getDoc(productRef(database()))).data().quantity, 8);
  assert.equal((await getDoc(movementRef(database(), 'adjust1'))).data().delta, -2);
});
test('direct quantity edits without history cannot bypass stock rules', async () => {
  await seedProduct();
  await assertFails(updateDoc(productRef(database()), { quantity: 20, revision: 2, updatedAt: serverTimestamp() }));
});
test('movement creation cannot happen without its matching stock update', async () => {
  await seedProduct();
  await assertFails(setDoc(movementRef(database(), 'orphan'), { ...openingData(), type: 'adjustment', beforeQuantity: 10,
    afterQuantity: 12, delta: 2, revision: 2 }));
});
test('forged movement before quantity and delta are rejected atomically', async () => {
  await seedProduct();
  await assertFails(adjustment(database(), { movement: { beforeQuantity: 9 } }));
  await assertFails(adjustment(database(), { movement: { delta: 123 } }));
  assert.equal((await getDoc(productRef(database()))).data().quantity, 10);
});
test('forged movement actor or client timestamp is rejected', async () => {
  await seedProduct();
  await assertFails(adjustment(database(), { movement: { actorUid: 'bob' } }));
  await assertFails(adjustment(database(), { movement: { createdAt: Timestamp.fromMillis(1000) } }));
});
test('negative stock, fractional stock and stock above limits are rejected', async () => {
  await seedProduct();
  await assertFails(adjustment(database(), { delta: -11 }));
  await assertFails(adjustment(database(), { delta: 0.5 }));
  await assertFails(adjustment(database(), { delta: 1000000000 }));
});
test('zero adjustments and mixed metadata/quantity edits are rejected', async () => {
  await seedProduct();
  await assertFails(adjustment(database(), { delta: 0 }));
  await assertFails(adjustment(database(), { product: { priceMinor: 1 } }));
});
test('a stale revision cannot overwrite a newer product', async () => {
  await seedProduct();
  await assertSucceeds(adjustment(database()));
  await assertFails(adjustment(database(), { before: 8, revision: 2, id: 'stale' }));
});
test('movement IDs cannot be reused to apply stock twice', async () => {
  await seedProduct();
  await assertSucceeds(adjustment(database()));
  await assertFails(adjustment(database(), { before: 8, revision: 3 }));
  assert.equal((await getDoc(productRef(database()))).data().quantity, 8);
});
test('a transaction retry with a recorded operation ID does not apply stock twice', async () => {
  await seedProduct();
  const db = database();
  async function applyOnce() {
    await runTransaction(db, async (tx) => {
      const movement = await tx.get(movementRef(db, 'retry-safe'));
      if (movement.exists()) return;
      const existing = (await tx.get(productRef(db))).data();
      tx.update(productRef(db), { quantity: existing.quantity + 3, revision: existing.revision + 1,
        lastMovementId: 'retry-safe', updatedAt: serverTimestamp() });
      tx.set(movementRef(db, 'retry-safe'), { type: 'adjustment', beforeQuantity: existing.quantity,
        afterQuantity: existing.quantity + 3, delta: 3, reason: 'Count correction', actorUid: 'alice',
        revision: existing.revision + 1, createdAt: serverTimestamp() });
    });
  }
  await assertSucceeds(applyOnce());
  await assertSucceeds(applyOnce());
  assert.equal((await getDoc(productRef(db))).data().quantity, 13);
});
test('historical movements cannot be modified or deleted', async () => {
  await seedProduct();
  await assertFails(updateDoc(movementRef(database()), { reason: 'Hide history' }));
  await assertFails(deleteDoc(movementRef(database())));
});
test('products cannot be deleted or archived with stock remaining', async () => {
  await seedProduct();
  await assertFails(deleteDoc(productRef(database())));
  await assertFails(updateDoc(productRef(database()), { archived: true, revision: 2, updatedAt: serverTimestamp() }));
});
test('zero-stock product can be archived and restored', async () => {
  await seedProduct(0);
  const target = productRef(database());
  await assertSucceeds(updateDoc(target, { archived: true, revision: 2, updatedAt: serverTimestamp() }));
  await assertFails(adjustment(database(), { before: 0, delta: 1, revision: 3 }));
  await assertSucceeds(updateDoc(target, { archived: false, revision: 3, updatedAt: serverTimestamp() }));
});
test('product code, creation time and currency remain immutable', async () => {
  await seedProduct();
  for (const change of [{ sku: 'OTHER' }, { createdAt: serverTimestamp() }, { currency: 'USD' }]) {
    await assertFails(updateDoc(productRef(database()), { ...change, revision: 2, updatedAt: serverTimestamp() }));
  }
});
test('product types, money and normalized search key are validated', async () => {
  await seed();
  for (const change of [{ costMinor: -1 }, { priceMinor: 1.5 }, { quantity: 1.2 },
    { name: '' }, { nameKey: 'wrong' }, { category: 1 }, { reorderLevel: -1 }, { extra: 'hidden' }]) {
    await assertFails(creation(database(), { product: change }));
  }
});
test('a product code cannot overwrite a previous product and its history', async () => {
  await seedProduct();
  await assertFails(creation(database(), { product: { lastMovementId: 'otherOpening' } }));
});

test('different owners can use the same product code while remaining isolated', async () => {
  await seedProduct();
  const bob = database('bob');
  await assertSucceeds(setDoc(reference(bob, 'bob'), profile('bob')));
  await assertSucceeds(creation(bob, { uid: 'bob', product: { name: 'Bob product', nameKey: 'bob product' }, movement: { actorUid: 'bob' } }));
  assert.equal((await getDoc(productRef(bob, 'ITEM-1', 'bob'))).data().name, 'Bob product');
  await assertFails(getDoc(productRef(database(), 'ITEM-1', 'bob')));
});
test('collection group queries cannot expose all owners products', async () => {
  await seedProduct();
  await assertFails(getDocs(query(collectionGroup(database(), 'products'), limit(31))));
});
test('concurrent stale adjustments preserve one valid balance without overwriting', async () => {
  await seedProduct();
  const db = database();
  async function change(id) {
    return runTransaction(db, async (tx) => {
      const product = (await tx.get(productRef(db))).data();
      if (product.revision !== 1) throw new Error('Stale revision');
      tx.update(productRef(db), { quantity: product.quantity + 3, revision: 2, lastMovementId: id, updatedAt: serverTimestamp() });
      tx.set(movementRef(db, id), { type: 'adjustment', beforeQuantity: product.quantity, afterQuantity: product.quantity + 3,
        delta: 3, reason: 'Count correction', actorUid: 'alice', revision: 2, createdAt: serverTimestamp() });
    });
  }
  const results = await Promise.allSettled([change('concurrent1'), change('concurrent2')]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  assert.equal((await getDoc(productRef(db))).data().quantity, 13);
});

// Sales are committed by the trusted server; clients retain owner-only reads.
const saleRef = (db, id = 'sale1', uid = 'alice') => doc(db, 'users', uid, 'sales', id);
async function seedSavedSale() {
  await seedProduct();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(saleRef(db), { actorUid: 'alice', currency: 'INR', totalMinor: 20000,
      createdAt: Timestamp.fromMillis(2000),
      items: { 'ITEM-1': { name: 'Test Product', unitPriceMinor: 10000, quantity: 2, totalMinor: 20000 } } });
    await setDoc(movementRef(db, 'sale1'), { type: 'sale', beforeQuantity: 10, afterQuantity: 8, delta: -2,
      reason: 'Sale sale1', actorUid: 'alice', revision: 2, createdAt: Timestamp.fromMillis(2000) });
    await updateDoc(productRef(db), { quantity: 8, revision: 2, lastMovementId: 'sale1', updatedAt: Timestamp.fromMillis(2000) });
  });
}
test('clients cannot create bills directly, including the signed-in owner', async () => {
  await seedProduct();
  for (const db of [database(), database('bob'), environment.unauthenticatedContext().firestore()]) {
    await assertFails(setDoc(saleRef(db), { actorUid: 'alice', currency: 'INR', items: {}, totalMinor: 0, createdAt: serverTimestamp() }));
  }
});
test('clients cannot forge sale deductions with a movement or bill', async () => {
  await seedProduct();
  const db = database();
  const batch = writeBatch(db);
  batch.update(productRef(db), { quantity: 8, revision: 2, lastMovementId: 'fake-sale', updatedAt: serverTimestamp() });
  batch.set(movementRef(db, 'fake-sale'), { type: 'sale', beforeQuantity: 10, afterQuantity: 8, delta: -2,
    reason: 'Sale fake-sale', actorUid: 'alice', revision: 2, createdAt: serverTimestamp() });
  await assertFails(batch.commit());
  assert.equal((await getDoc(productRef(db))).data().quantity, 10);
});
test('saved bills and sale stock histories are immutable to clients', async () => {
  await seedSavedSale();
  const db = database();
  await assertFails(updateDoc(saleRef(db), { totalMinor: 1 }));
  await assertFails(deleteDoc(saleRef(db)));
  await assertFails(updateDoc(movementRef(db, 'sale1'), { delta: -1 }));
  await assertFails(deleteDoc(movementRef(db, 'sale1')));
});
test('owner reads saved bills and history; other accounts and anonymous users cannot', async () => {
  await seedSavedSale();
  await assertSucceeds(getDoc(saleRef(database())));
  await assertSucceeds(getDoc(movementRef(database(), 'sale1')));
  const list = (db) => collection(db, 'users', 'alice', 'sales');
  await assertSucceeds(getDocs(query(list(database()), orderBy('createdAt', 'desc'), limit(31))));
  await assertFails(getDocs(list(database())));
  await assertFails(getDocs(query(list(database()), limit(51))));
  for (const db of [database('bob'), environment.unauthenticatedContext().firestore()]) {
    await assertFails(getDoc(saleRef(db)));
    await assertFails(getDocs(query(list(db), limit(31))));
    await assertFails(getDoc(movementRef(db, 'sale1')));
  }
  await assertFails(getDocs(query(collectionGroup(database(), 'sales'), limit(31))));
});
test('ordinary stock adjustments remain available after server checkout', async () => {
  await seedSavedSale();
  await assertSucceeds(adjustment(database(), { before: 8, revision: 3, delta: 2 }));
  assert.equal((await getDoc(productRef(database()))).data().quantity, 10);
});
