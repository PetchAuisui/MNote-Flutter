// Security tests for storage.rules.
//
// Pictures in notes are stored at users/{uid}/images/{name}. Only the owner
// may touch them, and uploads must be small images (the app shrinks pictures
// to fit; this keeps the bill inside the free tier even if a client misbehaves).

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteObject,
  getBytes,
  ref,
  uploadBytes,
} from 'firebase/storage';

const LIMIT = 1536 * 1024;
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-mnote',
    storage: { rules: readFileSync('../storage.rules', 'utf8') },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearStorage();
  await env.withSecurityRulesDisabled((ctx) =>
    uploadBytes(ref(ctx.storage(), 'users/alice/images/cat.png'), bytes(10), {
      contentType: 'image/png',
    }),
  );
});

const bytes = (n) => new Uint8Array(n);
const alice = () => env.authenticatedContext('alice').storage();
const bob = () => env.authenticatedContext('bob').storage();
const guest = () => env.unauthenticatedContext().storage();
const upload = (storage, path, size, contentType) =>
  uploadBytes(ref(storage, path), bytes(size), { contentType });

describe('owner', () => {
  test('reads their own picture', () =>
    assertSucceeds(getBytes(ref(alice(), 'users/alice/images/cat.png'))));

  for (const type of ['image/jpeg', 'image/png', 'image/gif', 'image/webp']) {
    test(`uploads a small ${type}`, () =>
      assertSucceeds(upload(alice(), 'users/alice/images/a', 1024, type)));
  }

  test('uploads a picture exactly at the size limit', () =>
    assertSucceeds(
      upload(alice(), 'users/alice/images/max.jpg', LIMIT, 'image/jpeg'),
    ));

  test('deletes their own picture', () =>
    assertSucceeds(deleteObject(ref(alice(), 'users/alice/images/cat.png'))));
});

describe('upload limits apply to the owner too', () => {
  test('a picture one byte over the limit is refused', () =>
    assertFails(
      upload(alice(), 'users/alice/images/big.jpg', LIMIT + 1, 'image/jpeg'),
    ));

  for (const type of [
    'text/html',
    'image/svg+xml',
    'application/javascript',
    'application/octet-stream',
  ]) {
    test(`${type} is refused`, () =>
      assertFails(upload(alice(), 'users/alice/images/x', 100, type)));
  }

  test('files outside images/ are refused', () =>
    assertFails(upload(alice(), 'users/alice/backup.zip', 100, 'image/png')));
});

describe('another signed-in user', () => {
  test('cannot read the picture', () =>
    assertFails(getBytes(ref(bob(), 'users/alice/images/cat.png'))));

  test('cannot overwrite the picture', () =>
    assertFails(upload(bob(), 'users/alice/images/cat.png', 10, 'image/png')));

  test('cannot delete the picture', () =>
    assertFails(deleteObject(ref(bob(), 'users/alice/images/cat.png'))));
});

describe('signed-out visitor', () => {
  test('cannot read the picture', () =>
    assertFails(getBytes(ref(guest(), 'users/alice/images/cat.png'))));

  test('cannot upload', () =>
    assertFails(upload(guest(), 'users/alice/images/x.png', 10, 'image/png')));
});
