import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { checkout } from './sales.js';

initializeApp();

// No idle instances. The app uses this same explicit region.
export const createSale = onCall({
  region: 'asia-south1', minInstances: 0, maxInstances: 3,
  timeoutSeconds: 120, memory: '256MiB',
}, (request) => checkout(request, getFirestore()));
