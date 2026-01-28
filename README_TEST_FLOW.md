# README_TEST_FLOW

This file describes a practical end-to-end test flow for the current app (AuthGate + roles + AppLock + Wallet + Customer Management).

## 0) Prerequisites
- Firebase project configured and app can sign in with email/password.
- Cloud Functions deployed (or running in emulator) for:
  - `createCustomer`
  - `recordDailySaving`
  - `recordDeposit`
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

## 7) Customer Management (Admin)

### 7a) Create a customer with login credentials
1. Sign in as admin.
2. Go to **Admin → Customers** tab.
3. Tap the **"Add Customer"** FAB.
4. Fill in the form:
   - Full Name: "John Doe"
   - Phone: "+251912345678"
   - Company Name: "ABC Trading"
   - Address: "Addis Ababa, Ethiopia"
   - Email: "johndoe@example.com"
   - Password: "password123"
   - Daily Target: 500 ETB
   - Credit Limit: 0 (unlimited) or e.g., 5000 ETB
5. Submit.
6. Credentials dialog appears with email and password.
7. Copy or note the credentials.

Expected:
- Customer appears in the customer list.
- Firebase Auth account created for customer.
- `users/{uid}` document created with `customerId` link and `role: 'customer'`.
- Customer has an initial wallet with 0 balance.
- Customer document in `customers/{customerId}` with `authUid` link.
- Customer can log in with provided credentials.

### 7b) Search for customers
1. In **Admin → Customers**, use the search bar.
2. Search by name, phone, or company.

Expected:
- Results filter in real-time.
- Customer cards show name, company, phone, and current balance.

### 7c) View customer details
1. Tap on a customer card.
2. View customer profile and wallet balance.

Expected:
- Profile info displayed.
- Wallet balance shows (with gradient background).
- Quick action buttons visible.

### 7d) Customer login test
1. Log out from admin account.
2. Sign in with customer credentials (from 7a).
   - Email: johndoe@example.com
   - Password: password123
3. Navigate to Customer Home.

Expected:
- Customer can view their wallet balance.
- Balance card displays correctly (with gradient).
- Customer can view transaction history.
- Customer can request withdrawals.
- Balance shows current balance from their linked wallet (customerId from users/{uid}).
- If no customerId link exists, shows "Customer profile not linked" message.

## 8) Record Deposit (Admin)

1. Sign in as admin.
2. Go to **Admin → Daily Check**.
3. Switch to the **"Deposit"** tab.
4. Search and select a customer.
5. Enter amount and optional note.
6. Submit.

Expected:
- `wallets/{customerId}` balance increases.
- Ledger contains a `DEPOSIT` entry with `balanceAfterCents`.

## 9) Negative Balance & Credit Limit

### 9a) Approve withdraw that creates debt
1. Sign in as admin.
2. Create a customer with credit limit 5000 ETB (500,000 cents).
3. Record a daily saving of 100 ETB.
4. Request a withdraw of 200 ETB (more than balance).
5. Go to **Admin → Approvals**.
6. Review the request.

Expected:
- Approval dialog shows warning "Will create debt".
- Shows current balance, after balance (negative).
- Shows credit limit info.
- After approval, balance becomes -100 ETB.
- Ledger shows `WITHDRAW_APPROVE` with negative `balanceAfterCents`.

### 9b) Verify credit limit enforcement
1. With a customer having credit limit 5000 ETB.
2. Request a withdraw of 6000 ETB (exceeds credit limit).
3. Try to approve.

Expected:
- Cloud Function throws error: "Credit limit exceeded".
- Balance remains unchanged.

### 9c) Unlimited credit (credit limit = 0)
1. Create a customer with credit limit 0 (unlimited).
2. Record 100 ETB daily saving.
3. Request withdraw of 10,000 ETB.
4. Approve.

Expected:
- Approval succeeds.
- Balance becomes -9,900 ETB.
- No credit limit error.

## 10) UI & Color Scheme

### 10a) Verify professional theme
1. Navigate through the app.

Expected:
- Primary color: Deep Blue (#1565C0).
- Secondary color: Teal (#00897B).
- Balance card has gradient background (blue to teal for positive, red to amber for negative).
- Transaction tiles are color-coded:
  - Daily Payment: Green
  - Deposit: Blue
  - Withdraw Approve: Red
  - Withdraw Request: Amber
- Status chips use appropriate colors (pending=amber, approved=green, rejected=red).
- Cards have elevation and rounded corners.
- Negative balances show in red with "DEBT" indicator.

## 11) Launcher icons
After setting `flutter_launcher_icons` config in `pubspec.yaml`, run:

```bash
flutter pub run flutter_launcher_icons
```

## 12) Deployment Checklist

1. **Cloud Functions:**
   ```bash
   cd functions
   npm run build
   firebase deploy --only functions
   ```

2. **Firestore Rules:**
   ```bash
   firebase deploy --only firestore:rules
   ```

3. **Test the complete flow:**
   - Admin creates customer
   - Admin records daily saving
   - Admin records deposit
   - Admin/Customer requests withdraw
   - Admin approves withdraw (positive and negative balance cases)
   - Admin rejects withdraw
   - Verify all ledger entries have `balanceAfterCents`
   - Verify credit limit enforcement
   - Check UI theme and colors
   - Test customer search
   - Test offline mode
