// Waitlist service — captures emails for the landing page.
//
// Currently uses localStorage as a zero-dependency fallback.
// When Firebase web credentials are configured, swap this for Firestore.
//
// To switch to Firestore:
// 1. `pnpm add firebase`
// 2. Create a firebase.ts config with the project's web credentials
// 3. Replace saveWaitlistEntry with a Firestore set() call

export interface WaitlistEntry {
  name: string;
  email: string;
  createdAt: string;
  source: string;
}

const STORAGE_KEY = 'pagate_waitlist';

export async function saveWaitlistEntry(entry: WaitlistEntry): Promise<void> {
  // Store in localStorage
  const existing = JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]');
  existing.push(entry);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(existing));

  // Also try to send via a beacon/analytics if available
  try {
    // TODO: Replace with Firestore when web credentials are configured
    // Example Firestore integration:
    // import { db } from './firebase';
    // import { collection, addDoc } from 'firebase/firestore';
    // await addDoc(collection(db, 'waitlist'), entry);

    console.log('Waitlist entry saved:', entry.email);
  } catch (e) {
    // localStorage is the reliable fallback
    console.warn('Could not send waitlist entry to server:', e);
  }
}

export function getWaitlistCount(): number {
  try {
    const existing = JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]');
    return existing.length;
  } catch {
    return 0;
  }
}
