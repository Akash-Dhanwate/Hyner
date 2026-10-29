import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

const maxMoney = 999999999999;
const maxStock = 1000000000;
const currencies = new Set(['INR', 'USD', 'EUR', 'GBP']);
const identifier = /^[A-Za-z0-9_-]{1,64}$/;
const skuPattern = /^[A-Z0-9][A-Z0-9_-]{0,39}$/;
const fail = (code, message) => { throw new HttpsError(code, message); };
const object = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
const keysAre = (value, keys) => object(value) && Object.keys(value).length === keys.length && keys.every((key) => Object.hasOwn(value, key));
const integer = (value, min, max) => Number.isSafeInteger(value) && value >= min && value <= max;

export function validateDraft(data) {
  if (!keysAre(data, ['id', 'currency', 'lines', 'accountUid']) || typeof data.accountUid !== 'string' || typeof data.id !== 'string' ||
      !identifier.test(data.id) || !currencies.has(data.currency) || !Array.isArray(data.lines) || data.lines.length === 0) {
    fail('invalid-argument', 'Choose products in one currency and use a valid sale reference.');
  }
  const seen = new Set();
  let totalMinor = 0;
  const items = Object.create(null);
  for (const line of data.lines) {
    if (!keysAre(line, ['sku', 'name', 'unitPriceMinor', 'quantity']) ||
        typeof line.sku !== 'string' || !skuPattern.test(line.sku) || seen.has(line.sku) ||
        typeof line.name !== 'string' || line.name.trim().length === 0 || line.name.length > 120 ||
        !integer(line.quantity, 1, maxStock) || !integer(line.unitPriceMinor, 0, maxMoney) ||
        line.unitPriceMinor > Math.floor(maxMoney / line.quantity)) {
      fail('invalid-argument', 'Check product codes, quantities and prices. Each product can appear only once.');
    }
    seen.add(line.sku);
    const total = line.quantity * line.unitPriceMinor;
    totalMinor += total;
    if (totalMinor > maxMoney) fail('invalid-argument', 'This bill total is too large. Reduce the quantities.');
    items[line.sku] = { name: line.name, unitPriceMinor: line.unitPriceMinor, quantity: line.quantity, totalMinor: total };
  }
  // Firestore has a 1 MiB document limit. Use a byte budget, not an item-count cap.
  if (Buffer.byteLength(JSON.stringify(items), 'utf8') > 800 * 1024) {
    fail('invalid-argument', 'This bill is too large to store. Split it into separate bills.');
  }
  return { id: data.id, currency: data.currency, items, totalMinor };
}

function sameBill(saved, draft, uid) {
  return keysAre(saved, ['actorUid', 'currency', 'totalMinor', 'items', 'createdAt']) &&
    saved.createdAt instanceof Timestamp && saved.actorUid === uid && saved.currency === draft.currency && saved.totalMinor === draft.totalMinor &&
    object(saved.items) && Object.keys(saved.items).length === Object.keys(draft.items).length &&
    Object.entries(draft.items).every(([sku, line]) => {
      const old = saved.items[sku];
      return keysAre(old, ['name', 'unitPriceMinor', 'quantity', 'totalMinor']) &&
        Object.keys(line).every((key) => old[key] === line[key]);
    });
}

function validProduct(product, sku) {
  return keysAre(product, ['sku', 'name', 'nameKey', 'category', 'currency', 'costMinor', 'priceMinor',
    'quantity', 'reorderLevel', 'archived', 'revision', 'lastMovementId', 'createdAt', 'updatedAt']) &&
    product.sku === sku && typeof product.name === 'string' &&
    product.name.trim().length > 0 && product.name.length <= 120 &&
    typeof product.category === 'string' && product.category.length <= 80 &&
    product.nameKey === product.name.toLowerCase() && currencies.has(product.currency) &&
    integer(product.quantity, 0, maxStock) && integer(product.reorderLevel, 0, maxStock) &&
    integer(product.priceMinor, 0, maxMoney) && integer(product.costMinor, 0, maxMoney) &&
    integer(product.revision, 1, maxStock - 1) && typeof product.archived === 'boolean' &&
    typeof product.lastMovementId === 'string' && identifier.test(product.lastMovementId) &&
    product.createdAt instanceof Timestamp && product.updatedAt instanceof Timestamp &&
    product.updatedAt.toMillis() >= product.createdAt.toMillis();
}

export async function checkout(request, db) {
  // Only verified callable auth selects the account. The expected UID prevents
  // an in-flight request from following a client account switch.
  const uid = request.auth?.uid;
  if (typeof uid !== 'string' || !uid || uid.includes('/')) fail('unauthenticated', 'Sign in before saving a sale.');
  const draft = validateDraft(request.data);
  if (request.data.accountUid !== uid) fail('permission-denied', 'The signed-in account changed. Reopen Sales before saving.');
  const user = db.collection('users').doc(uid);
  const saleRef = user.collection('sales').doc(draft.id);
  const skus = Object.keys(draft.items);
  try {
    await db.runTransaction(async (tx) => {
      const existing = await tx.get(saleRef);
      if (existing.exists) {
        if (!sameBill(existing.data(), draft, uid)) {
          fail('already-exists', 'This reference belongs to a different bill. Check saved sales before creating another.');
        }
        return;
      }
      if (!(await tx.get(user)).exists) fail('failed-precondition', 'Your account setup is incomplete. Sign in again.');
      const productRefs = skus.map((sku) => user.collection('products').doc(sku));
      const movementRefs = productRefs.map((ref) => ref.collection('movements').doc(draft.id));
      const snapshots = await tx.getAll(...productRefs, ...movementRefs);
      const products = snapshots.slice(0, skus.length).map((doc) => doc.data());
      for (let i = 0; i < skus.length; i++) {
        const sku = skus[i];
        const product = products[i];
        const line = draft.items[sku];
        if (!validProduct(product, sku)) fail('failed-precondition', `${sku} is missing or needs correction in Inventory.`);
        if (product.archived || product.quantity < line.quantity) {
          fail('failed-precondition', `${product.name} has insufficient available stock. Review the quantity before saving.`);
        }
        if (product.currency !== draft.currency || product.name !== line.name) {
          fail('failed-precondition', `${product.name} changed. Remove it and add it again to review the current details.`);
        }
        if (snapshots[skus.length + i].exists) fail('already-exists', 'This reference is already used in stock history. Check saved sales.');
      }
      for (let i = 0; i < skus.length; i++) {
        const product = products[i];
        const line = draft.items[skus[i]];
        const after = product.quantity - line.quantity;
        tx.update(productRefs[i], { quantity: after, revision: product.revision + 1,
          lastMovementId: draft.id, updatedAt: FieldValue.serverTimestamp() });
        tx.create(movementRefs[i], { type: 'sale', beforeQuantity: product.quantity, afterQuantity: after,
          delta: -line.quantity, reason: `Sale ${draft.id}`, actorUid: uid, revision: product.revision + 1,
          createdAt: FieldValue.serverTimestamp() });
      }
      tx.create(saleRef, { actorUid: uid, currency: draft.currency, items: draft.items,
        totalMinor: draft.totalMinor, createdAt: FieldValue.serverTimestamp() });
    });
    return { id: draft.id };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    if (error.code === 8) fail('resource-exhausted', 'The service limit was reached. Check saved sales before retrying.');
    if ([4, 10, 14].includes(error.code)) fail('unavailable', 'The save could not be confirmed. Retry this same bill.');
    fail('internal', 'The save could not be confirmed. Retry this same bill.');
  }
}
