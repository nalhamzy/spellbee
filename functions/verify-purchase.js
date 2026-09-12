"use strict";
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {logger} = require("firebase-functions");
const {createHash} = require("node:crypto");
const {validateRequest, verifyApple, verifyGoogle, VerificationError} = require("./purchases");
const playAccount = defineSecret("SPELLBEE_PLAY_SERVICE_ACCOUNT");
const appleKey = defineSecret("SPELLBEE_APPLE_IAP_KEY");

exports.spellbeeVerifyPurchase = onRequest({region: "us-central1", timeoutSeconds: 60,
  memory: "256MiB", maxInstances: 10, cors: false, secrets: [playAccount, appleKey]}, async (req, res) => {
  res.set("Cache-Control", "no-store");
  if (req.method !== "POST") { res.status(405).json({error: "POST required"}); return; }
  try {
    validateRequest(req.body);
    // No account required: the store credential is a bearer purchase proof.
    // IP/global caps bound provider quota consumption. Fail closed if metering
    // is down; the app preserves its existing, dated offline entitlement.
    const hour = Math.floor(Date.now() / 3600000);
    const ip = createHash("sha256").update(req.ip || "unknown").digest("hex").slice(0, 24);
    const db = getFirestore();
    await db.runTransaction(async (tx) => {
      const refs = [db.doc(`spellbee_purchase_quota/${hour}_${ip}`), db.doc(`spellbee_purchase_quota/${hour}_global`)];
      const snapshots = await tx.getAll(...refs);
      const counts = snapshots.map((snapshot) => snapshot.data()?.requests || 0);
      if (counts[0] >= 120 || counts[1] >= 10000) throw new VerificationError("try_later", 429);
      refs.forEach((ref, index) => tx.set(ref, {requests: counts[index] + 1, expiresAt: Timestamp.fromMillis((hour + 48) * 3600000)}));
    });
    const result = req.body.source === "google_play" ?
      await verifyGoogle(req.body, playAccount.value()) : await verifyApple(req.body, appleKey.value());
    res.status(200).json(result);
  } catch (error) {
    const known = error instanceof VerificationError;
    // Never log req.body, credentials, transaction IDs, or provider bodies.
    logger.warn("Purchase verification unsuccessful", {code: known ? error.code : "unavailable", status: error.providerStatus || null});
    res.status(known ? error.status : 503).json({error: known ? error.code : "store_unavailable"});
  }
});
