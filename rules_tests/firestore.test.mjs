import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, serverTimestamp, setDoc, Timestamp, updateDoc } from 'firebase/firestore';

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
