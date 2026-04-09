# README_TEST_FLOW

End-to-end test flow for the app (AuthGate + roles + AppLock + Wallet + customer management) against the **Node/Postgres API**, not Firebase.

## 0) Prerequisites

- **Backend:** Wallet API running (default local: `http://127.0.0.1:4000/api/v1`). Configure the Flutter app with `--dart-define=NODE_API_BASE_URL=...` if not using the default in [`lib/core/config/backend_feature_flags.dart`](lib/core/config/backend_feature_flags.dart).
- **Database:** Migrations applied on the wallet API; `DATABASE_URL` and JWT secrets configured for that service.
- **Media (optional):** Cloudinary env vars on the backend if you exercise profile/customer photos.

## 1) Create / promote an admin user

1. Register or seed users via the backend (e.g. `npm run seed:admins` in the backend repo, or create a customer and update `User.role` in Postgres to `ADMIN` or `SUPERADMIN`).
2. Sign in from the app with that account’s email and password.

## 2) Customer first login + App Lock

1. Sign in as a customer.
2. If no PIN is set, create a 4-digit PIN when prompted.
3. Close and re-open the app; you should see the Unlock screen.
4. Toggle biometric unlock in **Customer → Settings** and verify behavior on a device that supports biometrics.

## 3) Record a daily saving (Admin)

1. Sign in as admin.
2. Go to **Admin → Daily Check**.
3. Enter:
   - Customer identifier (customer id or as shown in the admin UI / API)
   - Amount (ETB)
   - Optional note
4. Submit.

**Expected:** Wallet balance increases for that customer; ledger shows a `DAILY_PAYMENT` entry (via **Customer → History** or admin views backed by the API).

## 4) Customer requests a withdraw

1. Sign in as customer.
2. **Customer → Home** → Request withdraw.
3. Enter amount + reason, confirm, submit.

**Expected:** A pending withdraw request exists; ledger shows `WITHDRAW_REQUEST` with no final settlement until approval.

## 5) Admin approves or rejects

1. Sign in as admin.
2. **Admin → Approvals**.
3. Approve or reject a pending request.

**Expected (approve):** Status `APPROVED`, balance decreases, ledger `WITHDRAW_APPROVE`.

**Expected (reject):** Status `REJECTED`, balance unchanged, ledger `WITHDRAW_REJECT`.

## 6) Offline / connectivity

1. Open **Customer → Home** while online (balance visible).
2. Disable network.
3. Return to Home or cold-start the app.

**Expected:** Offline/connectivity messaging; UI may show cached or stale values depending on last successful API poll.

## 7) Customer management (Admin)

### 7a) Create a customer with login credentials

1. Sign in as admin.
2. **Admin → Customers** → **Add Customer**.
3. Fill the form (name, phone, company, address, email, password, daily target, credit limit).
4. Submit and note the credentials from the dialog.

**Expected:** Customer appears in the list; the backend creates a `User` + `Customer` + wallet; the new user can sign in with the given email/password.

### 7b) Search customers

Use the search bar in **Admin → Customers**; results should filter by name, phone, or company.

### 7c) Customer details

Open a customer card; profile and balance should match API data.

### 7d) Customer login

Log out, sign in with the customer from 7a, open **Customer → Home**.

**Expected:** Balance and history load; withdraw request flow works. If the session/user is not linked to a customer record, the app should surface a clear “not linked” style message.

## 8) Record deposit (Admin)

1. **Admin → Daily Check** → **Deposit** tab.
2. Select customer, amount, optional note, submit.

**Expected:** Balance increases; ledger shows `DEPOSIT` with `balanceAfterCents` (or equivalent in API payloads).

## 9) Negative balance and credit limit

Exercise the same scenarios as before (approve withdraw beyond balance, reject over credit limit, unlimited credit) and confirm the **API** returns the expected errors and ledger rows—e.g. credit limit violations should be rejected by the backend without changing balance.

## 10) UI and theme

Spot-check primary/secondary colors, balance card gradient, transaction tile colors, and chips (pending / approved / rejected).

## 11) Launcher icons

After configuring `flutter_launcher_icons` in `pubspec.yaml`:

```bash
dart run flutter_launcher_icons
```

## 12) Deployment checklist (API + app)

1. **Backend:** Deploy the Node service; run `prisma migrate deploy` (or your hosting equivalent); set secrets (JWT, DB URL, optional Cloudinary).
2. **Mobile:** Build the Flutter app with `--dart-define=NODE_API_BASE_URL=https://your-api.example.com/api/v1` (and any other defines you use).
3. **Smoke test:** Admin creates customer → daily saving / deposit → withdraw request → approve/reject → customer history → media upload (if enabled) → forgot-password / reset-password email flow (if configured on the server).
