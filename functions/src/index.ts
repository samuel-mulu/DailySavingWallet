import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

admin.initializeApp();

const db = admin.firestore();
const { FieldValue } = admin.firestore;
type Tx = admin.firestore.Transaction;

type UserRole = 'customer' | 'admin' | 'superadmin';

function requireAuth(context: functions.https.CallableContext): string {
  const uid = context.auth?.uid;
  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  return uid;
}

async function requireAdmin(uid: string): Promise<void> {
  const snap = await db.doc(`users/${uid}`).get();
  const role = (snap.data()?.role as UserRole | undefined) ?? 'customer';
  if (role !== 'admin' && role !== 'superadmin') {
    throw new functions.https.HttpsError('permission-denied', 'Admin role required.');
  }
}

function requireIntCents(v: unknown, fieldName: string): number {
  if (typeof v !== 'number' || !Number.isInteger(v)) {
    throw new functions.https.HttpsError('invalid-argument', `${fieldName} must be an integer.`);
  }
  if (v <= 0) {
    throw new functions.https.HttpsError('invalid-argument', `${fieldName} must be > 0.`);
  }
  if (v > 1e12) {
    throw new functions.https.HttpsError('invalid-argument', `${fieldName} is too large.`);
  }
  return v;
}

function requireString(v: unknown, fieldName: string, { min = 1, max = 500 } = {}): string {
  if (typeof v !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', `${fieldName} must be a string.`);
  }
  const s = v.trim();
  if (s.length < min) {
    throw new functions.https.HttpsError('invalid-argument', `${fieldName} is required.`);
  }
  if (s.length > max) {
    throw new functions.https.HttpsError('invalid-argument', `${fieldName} is too long.`);
  }
  return s;
}

function walletRef(customerId: string) {
  return db.doc(`wallets/${customerId}`);
}

function ledgerRef(customerId: string, txId?: string) {
  const col = walletRef(customerId).collection('ledger');
  return txId ? col.doc(txId) : col.doc();
}

function withdrawReqRef(requestId?: string) {
  const col = db.collection('withdrawRequests');
  return requestId ? col.doc(requestId) : col.doc();
}

function idempotencyRef(callerUid: string, key: string) {
  return db.doc(`idempotency/${callerUid}/keys/${key}`);
}

function customerRef(customerId?: string) {
  const col = db.collection('customers');
  return customerId ? col.doc(customerId) : col.doc();
}

function requireIntCentsOptional(v: unknown, fieldName: string): number {
  if (v == null || v === undefined) return 0;
  if (typeof v !== 'number' || !Number.isInteger(v)) {
    throw new functions.https.HttpsError('invalid-argument', `${fieldName} must be an integer.`);
  }
  if (v < 0) {
    throw new functions.https.HttpsError('invalid-argument', `${fieldName} must be >= 0.`);
  }
  if (v > 1e12) {
    throw new functions.https.HttpsError('invalid-argument', `${fieldName} is too large.`);
  }
  return v;
}

function requireTimestamp(v: unknown, fieldName: string): number {
  if (typeof v !== 'number') {
    throw new functions.https.HttpsError('invalid-argument', `${fieldName} must be a number.`);
  }
  if (v < 0 || v > Date.now() + 86400000) {
    throw new functions.https.HttpsError('invalid-argument', `${fieldName} is invalid.`);
  }
  return v;
}

function optionalTimestamp(v: unknown): admin.firestore.Timestamp | admin.firestore.FieldValue {
  if (v == null || v === undefined) {
    return FieldValue.serverTimestamp();
  }
  if (typeof v !== 'number') {
    return FieldValue.serverTimestamp();
  }
  return admin.firestore.Timestamp.fromMillis(v);
}

export const createCustomer = functions.https.onCall(
  async (data: any, context: functions.https.CallableContext) => {
  const callerUid = requireAuth(context);
  await requireAdmin(callerUid);

  const fullName = requireString(data?.fullName, 'fullName', { max: 200 });
  const phone = requireString(data?.phone, 'phone', { max: 50 });
  const companyName = requireString(data?.companyName, 'companyName', { max: 200 });
  const address = requireString(data?.address, 'address', { max: 500 });
  const email = requireString(data?.email, 'email', { max: 200 });
  const password = requireString(data?.password, 'password', { min: 6, max: 128 });
  const dailyTargetCents = requireIntCents(data?.dailyTargetCents, 'dailyTargetCents');
  const creditLimitCents = requireIntCentsOptional(data?.creditLimitCents, 'creditLimitCents');

  // Step 1: Create Firebase Auth account
  let userRecord;
  try {
    userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: fullName,
    });
  } catch (error: any) {
    if (error.code === 'auth/email-already-exists') {
      throw new functions.https.HttpsError('already-exists', 'Email already exists.');
    }
    throw new functions.https.HttpsError('internal', `Failed to create auth account: ${error.message}`);
  }

  const uid = userRecord.uid;
  const custRef = customerRef();
  const customerId = custRef.id;

  try {
    await db.runTransaction(async (tx: Tx) => {
      // Step 2: Create customer document with authUid link
      tx.set(custRef, {
        fullName,
        phone,
        companyName,
        address,
        dailyTargetCents,
        creditLimitCents,
        status: 'active',
        authUid: uid,
        createdAt: FieldValue.serverTimestamp(),
        createdByUid: callerUid,
      });

      // Step 3: Create user document with customerId link
      const userRef = db.doc(`users/${uid}`);
      tx.set(userRef, {
        role: 'customer',
        status: 'active',
        customerId,
        createdAt: FieldValue.serverTimestamp(),
      });

      // Step 4: Create initial wallet
      const wRef = walletRef(customerId);
      tx.set(wRef, {
        balanceCents: 0,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    // Step 5: Return all IDs
    return { ok: true, customerId, uid, email };
  } catch (error) {
    // Rollback: Delete the auth account if transaction fails
    try {
      await admin.auth().deleteUser(uid);
    } catch (deleteError) {
      // Log but don't throw - original error is more important
      console.error('Failed to rollback auth account:', deleteError);
    }
    throw error;
  }
  },
);

export const recordDailySaving = functions.https.onCall(
  async (data: any, context: functions.https.CallableContext) => {
  console.log('🟢 [recordDailySaving] Function called');
  
  try {
    // 1. Validate authentication
    console.log('   Step 1: Checking authentication...');
    if (!context.auth) {
      console.error('   ❌ No authentication context');
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
    }
    const callerUid = context.auth.uid;
    console.log(`   ✓ Authenticated as uid: ${callerUid}`);

    // 2. Validate required inputs
    console.log('   Step 2: Validating inputs...');
    if (!data || typeof data !== 'object') {
      console.error('   ❌ Invalid data object');
      throw new functions.https.HttpsError('invalid-argument', 'Request data must be an object.');
    }

    console.log(`   Received data:`, JSON.stringify({
      customerId: data?.customerId,
      amountCents: data?.amountCents,
      txDateMillis: data?.txDateMillis,
      hasNote: !!data?.note,
      hasIdempotencyKey: !!data?.idempotencyKey,
    }));

    const customerId = requireString(data?.customerId, 'customerId', { max: 128 });
    const amountCents = requireIntCents(data?.amountCents, 'amountCents');
    const txDateMillis = requireTimestamp(data?.txDateMillis, 'txDateMillis');
    const note = data?.note == null ? undefined : requireString(data.note, 'note', { max: 500 });
    const idempotencyKey =
      data?.idempotencyKey == null ? undefined : requireString(data.idempotencyKey, 'idempotencyKey', { max: 128 });

    console.log(`   ✓ Validated: customerId=${customerId}, amountCents=${amountCents}, txDateMillis=${txDateMillis}`);

    // 3. Verify role is admin or superadmin (BEFORE transaction)
    console.log('   Step 3: Checking user role...');
    const userRef = db.doc(`users/${callerUid}`);
    const userSnap = await userRef.get();
    
    if (!userSnap.exists) {
      console.error(`   ❌ User doc not found for uid=${callerUid}`);
      throw new functions.https.HttpsError('permission-denied', 'User profile not found.');
    }

    const userData = userSnap.data();
    const role = userData?.role;
    console.log(`   User role: ${role}`);
    
    if (role !== 'admin' && role !== 'superadmin') {
      console.error(`   ❌ Invalid role=${role} for uid=${callerUid}`);
      throw new functions.https.HttpsError('permission-denied', 'Access denied. Admin role required.');
    }
    console.log('   ✓ Role authorized');

    const txDate = admin.firestore.Timestamp.fromMillis(txDateMillis);

    // 4. Execute transaction (ALL READS FIRST, THEN WRITES)
    console.log('   Step 4: Executing Firestore transaction...');
    let idempotent = false;
    await db.runTransaction(async (tx: Tx) => {
      // === ALL READS FIRST ===
      
      // Read 1: Check idempotency
      let iSnap = null;
      if (idempotencyKey != null) {
        const iRef = idempotencyRef(callerUid, idempotencyKey);
        iSnap = await tx.get(iRef);
        if (iSnap.exists) {
          console.log('   ⚠️ Idempotent request detected');
          idempotent = true;
          return;
        }
      }

      // Read 2: Get current wallet balance
      const wRef = walletRef(customerId);
      const wSnap = await tx.get(wRef);

      // === ALL READS COMPLETE, NOW WRITES ===
      
      const current = (wSnap.data()?.balanceCents as number | undefined) ?? 0;
      const next = current + amountCents;
      console.log(`   Wallet: current=${current}, adding=${amountCents}, new=${next}`);

      // Write 1: Idempotency key (if needed)
      if (idempotencyKey != null && iSnap && !iSnap.exists) {
        const iRef = idempotencyRef(callerUid, idempotencyKey);
        tx.set(iRef, { createdAt: FieldValue.serverTimestamp() });
      }

      // Write 2: Update wallet
      if (!wSnap.exists) {
        console.log('   Creating new wallet');
        tx.set(wRef, { balanceCents: next, updatedAt: FieldValue.serverTimestamp() });
      } else {
        console.log('   Updating existing wallet');
        tx.set(wRef, { balanceCents: next, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
      }

      // Write 3: Create ledger entry
      const lRef = ledgerRef(customerId);
      const ledgerData = {
        type: 'DAILY_PAYMENT',
        direction: 'IN',
        amountCents,
        balanceAfterCents: next,
        txDate,
        createdAt: FieldValue.serverTimestamp(),
        createdByUid: callerUid,
        ...(note ? { meta: { note } } : {}),
      };
      console.log('   Writing ledger entry:', JSON.stringify({...ledgerData, txDate: txDateMillis}));
      tx.set(lRef, ledgerData);
    });

    console.log('   ✓ Transaction completed successfully');

    // 5. Return success payload
    console.log('✅ [recordDailySaving] Success');
    return { ok: true, idempotent };
  } catch (error: any) {
    // Log the full error with stack trace
    console.error('❌ [recordDailySaving] Error occurred:');
    console.error('   Error type:', error.constructor.name);
    console.error('   Error message:', error.message);
    console.error('   Error code:', error.code);
    console.error('   Full error:', error);
    if (error.stack) {
      console.error('   Stack trace:', error.stack);
    }

    // Re-throw HttpsError as-is
    if (error instanceof functions.https.HttpsError) {
      console.error('   Re-throwing HttpsError');
      throw error;
    }

    // Convert unknown errors to HttpsError
    console.error('   Converting to HttpsError');
    throw new functions.https.HttpsError(
      'internal',
      `Failed to record daily saving: ${error.message || 'Unknown error'}`,
    );
  }
  },
);

export const recordDeposit = functions.https.onCall(
  async (data: any, context: functions.https.CallableContext) => {
  const callerUid = requireAuth(context);
  await requireAdmin(callerUid);

  const customerId = requireString(data?.customerId, 'customerId', { max: 128 });
  const amountCents = requireIntCents(data?.amountCents, 'amountCents');
  const txDate = optionalTimestamp(data?.txDateMillis);
  const note = data?.note == null ? undefined : requireString(data.note, 'note', { max: 500 });
  const idempotencyKey =
    data?.idempotencyKey == null ? undefined : requireString(data.idempotencyKey, 'idempotencyKey', { max: 128 });

  let idempotent = false;
  await db.runTransaction(async (tx: Tx) => {
    if (idempotencyKey != null) {
      const iRef = idempotencyRef(callerUid, idempotencyKey);
      const iSnap = await tx.get(iRef);
      if (iSnap.exists) {
        idempotent = true;
        return;
      }
      tx.set(iRef, { createdAt: FieldValue.serverTimestamp() });
    }

    const wRef = walletRef(customerId);
    const wSnap = await tx.get(wRef);

    const current = (wSnap.data()?.balanceCents as number | undefined) ?? 0;
    const next = current + amountCents;

    if (!wSnap.exists) {
      tx.set(wRef, { balanceCents: next, updatedAt: FieldValue.serverTimestamp() });
    } else {
      tx.set(wRef, { balanceCents: next, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    }

    const lRef = ledgerRef(customerId);
    tx.set(lRef, {
      type: 'DEPOSIT',
      direction: 'IN',
      amountCents,
      balanceAfterCents: next,
      txDate,
      createdAt: FieldValue.serverTimestamp(),
      createdByUid: callerUid,
      ...(note ? { meta: { note } } : {}),
    });
  });

    return { ok: true, idempotent };
  },
);

export const requestWithdraw = functions.https.onCall(
  async (data: any, context: functions.https.CallableContext) => {
  const callerUid = requireAuth(context);

  const amountCents = requireIntCents(data?.amountCents, 'amountCents');
  const reason = requireString(data?.reason, 'reason', { max: 500 });
  
  // Support admin creating withdraw request for a customer
  let customerId: string;
  if (data?.customerId != null) {
    // Admin creating on behalf of customer
    await requireAdmin(callerUid);
    customerId = requireString(data.customerId, 'customerId', { max: 128 });
  } else {
    // Customer creating for themselves
    customerId = callerUid;
  }

  const reqRef = withdrawReqRef();
  const requestId = reqRef.id;

  await db.runTransaction(async (tx: Tx) => {
    // Ensure wallet exists so the client can always stream a small snapshot doc.
    const wRef = walletRef(customerId);
    const wSnap = await tx.get(wRef);
    const currentBalance = (wSnap.data()?.balanceCents as number | undefined) ?? 0;
    
    if (!wSnap.exists) {
      tx.set(wRef, { balanceCents: 0, updatedAt: FieldValue.serverTimestamp() });
    }

    tx.set(reqRef, {
      customerId,
      amountCents,
      reason,
      status: 'PENDING',
      requestedByUid: callerUid,
      reviewedByUid: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const lRef = ledgerRef(customerId);
    tx.set(lRef, {
      type: 'WITHDRAW_REQUEST',
      direction: 'OUT',
      amountCents,
      balanceAfterCents: currentBalance, // No balance change on request
      txDate: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
      createdByUid: callerUid,
      meta: { requestId, reason },
    });
  });

    return { ok: true, requestId };
  },
);

export const approveWithdraw = functions.https.onCall(
  async (data: any, context: functions.https.CallableContext) => {
  const callerUid = requireAuth(context);
  await requireAdmin(callerUid);

  const requestId = requireString(data?.requestId, 'requestId', { max: 128 });
  const idempotencyKey =
    data?.idempotencyKey == null ? undefined : requireString(data.idempotencyKey, 'idempotencyKey', { max: 128 });
  const reqRef = withdrawReqRef(requestId);

  let idempotent = false;
  await db.runTransaction(async (tx: Tx) => {
    if (idempotencyKey != null) {
      const iRef = idempotencyRef(callerUid, idempotencyKey);
      const iSnap = await tx.get(iRef);
      if (iSnap.exists) {
        idempotent = true;
        return;
      }
      tx.set(iRef, { createdAt: FieldValue.serverTimestamp(), requestId });
    }

    const reqSnap = await tx.get(reqRef);
    if (!reqSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Withdraw request not found.');
    }

    const req = reqSnap.data() as any;
    if (req.status !== 'PENDING') {
      throw new functions.https.HttpsError('failed-precondition', 'Request is not pending.');
    }

    const customerId = req.customerId as string;
    const amountCents = requireIntCents(req.amountCents, 'amountCents');

    const wRef = walletRef(customerId);
    const wSnap = await tx.get(wRef);
    const bal = (wSnap.data()?.balanceCents as number | undefined) ?? 0;
    const newBalance = bal - amountCents;

    // Check credit limit if balance will go negative
    if (newBalance < 0) {
      const custRef = customerRef(customerId);
      const custSnap = await tx.get(custRef);
      
      if (custSnap.exists) {
        const creditLimitCents = (custSnap.data()?.creditLimitCents as number | undefined) ?? 0;
        
        // creditLimitCents = 0 means unlimited credit
        // creditLimitCents > 0 means limit the negative balance
        if (creditLimitCents > 0 && Math.abs(newBalance) > creditLimitCents) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            `Credit limit exceeded. Limit: ${creditLimitCents} cents, would be: ${Math.abs(newBalance)} cents debt.`,
          );
        }
      }
    }

    tx.set(
      wRef,
      { balanceCents: newBalance, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );

    tx.set(
      reqRef,
      { status: 'APPROVED', reviewedByUid: callerUid, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );

    const lRef = ledgerRef(customerId);
    tx.set(lRef, {
      type: 'WITHDRAW_APPROVE',
      direction: 'OUT',
      amountCents,
      balanceAfterCents: newBalance,
      txDate: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
      createdByUid: callerUid,
      meta: { requestId },
    });
  });

    return { ok: true, idempotent };
  },
);

export const rejectWithdraw = functions.https.onCall(
  async (data: any, context: functions.https.CallableContext) => {
  const callerUid = requireAuth(context);
  await requireAdmin(callerUid);

  const requestId = requireString(data?.requestId, 'requestId', { max: 128 });
  const note = data?.note == null ? undefined : requireString(data.note, 'note', { max: 500 });

  const reqRef = withdrawReqRef(requestId);

  await db.runTransaction(async (tx: Tx) => {
    const reqSnap = await tx.get(reqRef);
    if (!reqSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Withdraw request not found.');
    }

    const req = reqSnap.data() as any;
    if (req.status !== 'PENDING') {
      throw new functions.https.HttpsError('failed-precondition', 'Request is not pending.');
    }

    const customerId = req.customerId as string;
    const amountCents = requireIntCents(req.amountCents, 'amountCents');

    // Get current balance (no change on reject)
    const wRef = walletRef(customerId);
    const wSnap = await tx.get(wRef);
    const currentBalance = (wSnap.data()?.balanceCents as number | undefined) ?? 0;

    tx.set(
      reqRef,
      { status: 'REJECTED', reviewedByUid: callerUid, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );

    const lRef = ledgerRef(customerId);
    tx.set(lRef, {
      type: 'WITHDRAW_REJECT',
      direction: 'OUT',
      amountCents,
      balanceAfterCents: currentBalance, // No balance change on reject
      txDate: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
      createdByUid: callerUid,
      meta: { requestId, ...(note ? { note } : {}) },
    });
  });

    return { ok: true };
  },
);

