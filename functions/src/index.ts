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

export const recordDailySaving = functions.https.onCall(
  async (data: any, context: functions.https.CallableContext) => {
  const callerUid = requireAuth(context);
  await requireAdmin(callerUid);

  const customerId = requireString(data?.customerId, 'customerId', { max: 128 });
  const amountCents = requireIntCents(data?.amountCents, 'amountCents');
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
      type: 'DAILY_PAYMENT',
      direction: 'IN',
      amountCents,
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

  const reqRef = withdrawReqRef();
  const requestId = reqRef.id;

  await db.runTransaction(async (tx: Tx) => {
    // Ensure wallet exists so the client can always stream a small snapshot doc.
    const wRef = walletRef(callerUid);
    const wSnap = await tx.get(wRef);
    if (!wSnap.exists) {
      tx.set(wRef, { balanceCents: 0, updatedAt: FieldValue.serverTimestamp() });
    }

    tx.set(reqRef, {
      customerId: callerUid,
      amountCents,
      reason,
      status: 'PENDING',
      requestedByUid: callerUid,
      reviewedByUid: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const lRef = ledgerRef(callerUid);
    tx.set(lRef, {
      type: 'WITHDRAW_REQUEST',
      direction: 'OUT',
      amountCents,
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

    if (bal < amountCents) {
      throw new functions.https.HttpsError('failed-precondition', 'Insufficient wallet balance.');
    }

    tx.set(
      wRef,
      { balanceCents: bal - amountCents, updatedAt: FieldValue.serverTimestamp() },
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
      createdAt: FieldValue.serverTimestamp(),
      createdByUid: callerUid,
      meta: { requestId, ...(note ? { note } : {}) },
    });
  });

    return { ok: true };
  },
);

