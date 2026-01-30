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
      txDay: data?.txDay,
      hasNote: !!data?.note,
      hasIdempotencyKey: !!data?.idempotencyKey,
    }));

    const customerId = requireString(data?.customerId, 'customerId', { max: 128 });
    const amountCents = requireIntCents(data?.amountCents, 'amountCents');
    const txDateMillis = requireTimestamp(data?.txDateMillis, 'txDateMillis');
    const txDay = requireString(data?.txDay, 'txDay', { min: 10, max: 10 }); // Expect YYYY-MM-DD
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
        customerId, // Explicitly save customerId for collectionGroup queries
        amountCents,
        balanceAfterCents: next,
        txDate,
        txDay,
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

export const recordDepositV2 = functions.https.onCall(
  async (data: any, context: functions.https.CallableContext) => {
    console.log('🟢 [recordDeposit] Function called');
    
    try {
      // 1. Validate authentication
      console.log('   Step 1: Checking authentication...');
      const callerUid = requireAuth(context);
      console.log(`   ✓ Authenticated as uid: ${callerUid}`);

      // 2. Validate required inputs
      console.log('   Step 2: Validating inputs...');
      if (!data || typeof data !== 'object') {
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
      const txDateMillis = data?.txDateMillis;
      const note = data?.note == null ? undefined : requireString(data.note, 'note', { max: 500 });
      const idempotencyKey =
        data?.idempotencyKey == null ? undefined : requireString(data.idempotencyKey, 'idempotencyKey', { max: 128 });

      // 3. Verify role is admin or superadmin
      console.log('   Step 3: Checking user role...');
      await requireAdmin(callerUid);
      console.log('   ✓ Role authorized');

      const txDate = optionalTimestamp(txDateMillis);

      // 4. Execute transaction
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

        // Write 1: Idempotency key
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
          type: 'DEPOSIT',
          direction: 'IN',
          customerId,
          amountCents,
          balanceAfterCents: next,
          txDate,
          createdAt: FieldValue.serverTimestamp(),
          createdByUid: callerUid,
          ...(note ? { meta: { note } } : {}),
        };
        console.log('   Writing ledger entry');
        tx.set(lRef, ledgerData);
      });

      console.log('   ✓ Transaction completed successfully');

      // 5. Return success payload
      console.log('✅ [recordDeposit] Success');
      return { ok: true, idempotent };
    } catch (error: any) {
      console.error('❌ [recordDeposit] Error occurred:');
      console.error('   Error message:', error.message);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        'internal',
        `Failed to record deposit: ${error.message || 'Unknown error'}`,
      );
    }
  },
);

export const requestWithdraw = functions.https.onCall(
  async (data: any, context: functions.https.CallableContext) => {
    console.log('🟢 [requestWithdraw] Function called');
    try {
      const callerUid = requireAuth(context);
      const amountCents = requireIntCents(data?.amountCents, 'amountCents');
      const reason = requireString(data?.reason, 'reason', { max: 500 });
      
      const reqRef = withdrawReqRef();
      const requestId = reqRef.id;

      await db.runTransaction(async (tx: Tx) => {
        // 1. Determine and Validate Customer ID
        let customerId: string;
        
        const userRef = db.doc(`users/${callerUid}`);
        const userSnap = await tx.get(userRef);
        
        if (!userSnap.exists) {
          throw new functions.https.HttpsError('permission-denied', 'User profile not found.');
        }
        
        const userData = userSnap.data()!;
        const role = userData.role;

        if (data?.customerId != null) {
          // Admin creating on behalf of customer
          if (role !== 'admin' && role !== 'superadmin') {
            throw new functions.https.HttpsError('permission-denied', 'Only admins can specify a customerId.');
          }
          customerId = requireString(data.customerId, 'customerId', { max: 128 });
        } else {
          // Customer creating for themselves
          customerId = userData.customerId;
          if (!customerId) {
            console.error(`   ❌ User ${callerUid} has no linked customerId`);
            throw new functions.https.HttpsError('failed-precondition', 'User profile is not linked to a customer account.');
          }
        }

        console.log(`   Resolved Customer ID: ${customerId}`);

        // 2. Validate Customer & Wallet existence
        const custRef = customerRef(customerId);
        const wRef = walletRef(customerId);
        
        const [custSnap, wSnap] = await Promise.all([
          tx.get(custRef),
          tx.get(wRef)
        ]);

        if (!custSnap.exists) {
          console.error(`   ❌ Customer ${customerId} document not found`);
          throw new functions.https.HttpsError('failed-precondition', 'Linked customer profile not found.');
        }

        const currentBalance = (wSnap.data()?.balanceCents as number | undefined) ?? 0;
        
        if (!wSnap.exists) {
          tx.set(wRef, { balanceCents: 0, updatedAt: FieldValue.serverTimestamp() });
        }

        // 3. Create Request
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

        // 4. Create Ledger Entry
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

      console.log('✅ [requestWithdraw] Success');
      return { ok: true, requestId };
    } catch (error: any) {
      console.error('❌ [requestWithdraw] Error:', error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError('internal', `Failed to create withdraw request: ${error.message || 'Unknown error'}`);
    }
  },
);

export const approveWithdraw = functions.https.onCall(
  async (data: any, context: functions.https.CallableContext) => {
    console.log('🟢 [approveWithdraw] Function called');
    try {
      const callerUid = requireAuth(context);
      console.log(`   Caller UID: ${callerUid}`);
      
      const requestId = requireString(data?.requestId, 'requestId', { max: 128 });
      const idempotencyKey = data?.idempotencyKey == null ? undefined : requireString(data.idempotencyKey, 'idempotencyKey', { max: 128 });
      console.log(`   Request ID: ${requestId}, Idempotency Key: ${idempotencyKey}`);
      
      const reqRef = withdrawReqRef(requestId);

      let idempotent = false;
      await db.runTransaction(async (tx: Tx) => {
        console.log('   Starting transaction...');
        
        // --- 1. ALL READS FIRST ---
        
        // A. Verify admin role
        console.log('   [READ] Verifying admin role...');
        const userSnap = await tx.get(db.doc(`users/${callerUid}`));
        
        // B. Idempotency check
        let iRef = null;
        let iSnap = null;
        if (idempotencyKey != null) {
          console.log('   [READ] Checking idempotency...');
          iRef = idempotencyRef(callerUid, idempotencyKey);
          iSnap = await tx.get(iRef);
        }

        // C. Request validation
        console.log('   [READ] Validating withdraw request...');
        const reqSnap = await tx.get(reqRef);
        
        // D. Early return for idempotency (before further reads if possible, but keep reads organized)
        if (iSnap?.exists) {
          console.log('   ⚠️ Idempotent request detected');
          idempotent = true;
          return;
        }

        // --- 2. VALIDATION LOGIC (Uses data from reads) ---
        
        if (!userSnap.exists) {
          console.error(`   ❌ User profile not found for ${callerUid}`);
          throw new functions.https.HttpsError('permission-denied', 'User profile not found.');
        }
        const role = userSnap.data()?.role;
        console.log(`       Role: ${role}`);
        if (role !== 'admin' && role !== 'superadmin') {
          console.error('   ❌ Permission denied: Not an admin');
          throw new functions.https.HttpsError('permission-denied', 'Admin role required.');
        }

        if (!reqSnap.exists) {
          console.error(`   ❌ Request ${requestId} not found`);
          throw new functions.https.HttpsError('not-found', 'Withdraw request not found.');
        }
        const req = reqSnap.data() as any;
        console.log(`       Request status: ${req.status}, Amount: ${req.amountCents}`);
        if (req.status !== 'PENDING') {
          console.error(`   ❌ Request is not pending (status: ${req.status})`);
          throw new functions.https.HttpsError('failed-precondition', 'Request is not pending.');
        }

        const customerId = req.customerId as string;
        if (!customerId) {
          console.error('   ❌ Request has no customerId');
          throw new functions.https.HttpsError('failed-precondition', 'Request has no customerId.');
        }

        const amountCents = requireIntCents(req.amountCents, 'amountCents');

        // E. More Reads (Customer and Wallet)
        console.log(`   [READ] Validating customer ${customerId} and wallet...`);
        const custRef = customerRef(customerId);
        const wRef = walletRef(customerId);
        
        const [custSnap, wSnap] = await Promise.all([
          tx.get(custRef),
          tx.get(wRef)
        ]);

        if (!custSnap.exists) {
          console.error(`   ❌ Customer profile ${customerId} not found`);
          throw new functions.https.HttpsError('failed-precondition', 'Customer profile not found.');
        }
        
        const creditLimitCents = (custSnap.data()?.creditLimitCents as number | undefined) ?? 0;
        console.log(`       Credit limit: ${creditLimitCents}`);

        const bal = (wSnap.data()?.balanceCents as number | undefined) ?? 0;
        const newBalance = bal - amountCents;
        console.log(`       Current balance: ${bal}, New balance: ${newBalance}`);

        if (newBalance < 0) {
          console.log('       Balance will go negative, verifying limit...');
          if (creditLimitCents > 0 && Math.abs(newBalance) > creditLimitCents) {
            console.error(`   ❌ Credit limit exceeded: debt=${Math.abs(newBalance)}, limit=${creditLimitCents}`);
            throw new functions.https.HttpsError(
              'failed-precondition',
              `Credit limit exceeded. Limit: ${creditLimitCents} cents, would be: ${Math.abs(newBalance)} cents debt.`,
            );
          }
        }

        // --- 3. ALL WRITES LAST ---
        
        console.log('   [WRITE] Applying database updates...');
        
        if (iRef) {
          tx.set(iRef, { createdAt: FieldValue.serverTimestamp(), requestId });
          console.log('       Idempotency key recorded');
        }

        tx.set(wRef, { balanceCents: newBalance, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
        tx.set(reqRef, { status: 'APPROVED', reviewedByUid: callerUid, updatedAt: FieldValue.serverTimestamp() }, { merge: true });

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
        console.log('       Ledger entry created');
      });

      console.log('✅ [approveWithdraw] Success');
      return { ok: true, idempotent };
    } catch (error: any) {
      console.error('❌ [approveWithdraw] Error:', error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError('internal', `Failed to approve withdraw: ${error.message || 'Unknown error'}`);
    }
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

