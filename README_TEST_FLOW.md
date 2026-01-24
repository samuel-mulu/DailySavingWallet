# README_TEST_FLOW

This file describes a practical end-to-end test flow for the current app (AuthGate + roles + AppLock + Wallet).

## 0) Prerequisites
- Firebase project configured and app can sign in with email/password.
- Cloud Functions deployed (or running in emulator) for:
  - `recordDailySaving`
  - `requestWithdraw`
  - `approveWithdraw`
  - `rejectWithdraw`
- Firestore rules deployed.

## 1) Create / promote an admin user
1. Create an account in the app (email/password) and sign in once.
2. In Firestore, set the role in `users/{uid}`:
   - `role: "admin"` (or `"superadmin"`)
   - `status: "active"`

Notes:
- The app auto-creates `users/{uid}` on first login; by default it creates `role: "customer"`.

## 2) Customer first login + App Lock
1. Sign in as a customer.
2. If no PIN is set, you’ll be asked to create a 4-digit PIN.
3. Close and re-open the app; you should see the Unlock screen.
4. Toggle biometric unlock in **Customer → Settings** and verify:
   - When enabled and device supports biometrics, Unlock screen can use fingerprint.

## 3) Record a daily saving (Admin)
1. Sign in as admin.
2. Go to **Admin → Daily Check**.
3. Enter:
   - Customer UID (copy from Firebase Auth users or customer dashboard)
   - Amount (ETB)
   - Optional note
4. Submit.

Expected:
- `wallets/{customerId}` exists and `balanceCents` increased.
- `wallets/{customerId}/ledger/*` contains a `DAILY_PAYMENT` entry.

## 4) Customer requests a withdraw
1. Sign in as customer.
2. Go to **Customer → Home** → “Request Withdraw”.
3. Enter amount + reason, confirm dialog, submit.

Expected:
- `withdrawRequests/{id}` created with `status: "PENDING"`.
- Ledger contains `WITHDRAW_REQUEST` entry (no balance change yet).

## 5) Admin approves or rejects
1. Sign in as admin.
2. Go to **Admin → Approvals**.
3. For a pending request:
   - Approve: confirm dialog, submit.
   - Reject: enter optional note, confirm, submit.

Expected approve:
- Request status becomes `APPROVED`, `reviewedByUid` set.
- Wallet balance decreases by amount.
- Ledger contains `WITHDRAW_APPROVE` entry.

Expected reject:
- Request status becomes `REJECTED`, `reviewedByUid` set.
- Wallet balance unchanged.
- Ledger contains `WITHDRAW_REJECT` entry.

## 6) Offline / cache behavior
1. Open **Customer → Home** while online (wallet balance visible).
2. Turn off internet (airplane mode).
3. Re-open the app or return to Home.

Expected:
- Offline banner shows “Offline — showing cached data when available”.
- Balance card may show “Cached” / “Waiting to sync…” when Firestore serves cached snapshot.

## Launcher icons
After setting `flutter_launcher_icons` config in `pubspec.yaml`, run:

```bash
flutter pub run flutter_launcher_icons
```

