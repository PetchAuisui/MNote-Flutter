// Security tests for firestore.rules.
//
// Each note, folder and ink page lives under users/{uid}/... . These tests
// check, against the real rules engine in the Firestore emulator, that only
// the signed-in owner can read or write that data.

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-mnote',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  // Alice already has a synced note, written past the rules.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/alice'), { displayName: 'Alice' });
    await setDoc(doc(db, 'users/alice/documents/d1'), {
      name: 'Diary.md',
      content: 'private text',
    });
  });
});

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();
const guest = () => env.unauthenticatedContext().firestore();

describe('owner', () => {
  test('reads their own note', () =>
    assertSucceeds(getDoc(doc(alice(), 'users/alice/documents/d1'))));

  test('lists their own notes', () =>
    assertSucceeds(getDocs(collection(alice(), 'users/alice/documents'))));

  for (const sub of ['documents', 'folders', 'ink']) {
    test(`writes their own ${sub}`, () =>
      assertSucceeds(
        setDoc(doc(alice(), `users/alice/${sub}/x1`), { name: 'x' }),
      ));
  }

  test('updates their profile', () =>
    assertSucceeds(setDoc(doc(alice(), 'users/alice'), { displayName: 'A' })));

  test('deletes their own note', () =>
    assertSucceeds(deleteDoc(doc(alice(), 'users/alice/documents/d1'))));
});

describe('another signed-in user', () => {
  test('cannot read the note', () =>
    assertFails(getDoc(doc(bob(), 'users/alice/documents/d1'))));

  test('cannot list the notes', () =>
    assertFails(getDocs(collection(bob(), 'users/alice/documents'))));

  test('cannot read the profile', () =>
    assertFails(getDoc(doc(bob(), 'users/alice'))));

  test('cannot overwrite the note', () =>
    assertFails(
      setDoc(doc(bob(), 'users/alice/documents/d1'), { content: 'hacked' }),
    ));

  test('cannot plant a new note', () =>
    assertFails(
      setDoc(doc(bob(), 'users/alice/documents/evil'), { content: 'x' }),
    ));

  test('cannot delete the note', () =>
    assertFails(deleteDoc(doc(bob(), 'users/alice/documents/d1'))));

  for (const sub of ['folders', 'ink']) {
    test(`cannot write ${sub}`, () =>
      assertFails(setDoc(doc(bob(), `users/alice/${sub}/x1`), { name: 'x' })));
  }
});

describe('signed-out visitor', () => {
  test('cannot read the note', () =>
    assertFails(getDoc(doc(guest(), 'users/alice/documents/d1'))));

  test('cannot write a note', () =>
    assertFails(
      setDoc(doc(guest(), 'users/alice/documents/d2'), { content: 'x' }),
    ));

  test('cannot list users', () =>
    assertFails(getDocs(collection(guest(), 'users'))));
});

describe('anything outside users/{uid}', () => {
  test('is closed even to signed-in users', async () => {
    await assertFails(getDoc(doc(alice(), 'admin/config')));
    await assertFails(setDoc(doc(alice(), 'public/x'), { a: 1 }));
  });

  test('the users collection cannot be listed', () =>
    assertFails(getDocs(collection(alice(), 'users'))));
});
