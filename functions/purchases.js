"use strict";

// Store credentials never leave Cloud Functions. Client-provided JWS claims,
// prices, dates and entitlement flags are never trusted.
const crypto = require("node:crypto");
const BUNDLE = "com.idealai.spellbee";
const LIFETIME = "spellbee_premium_lifetime";
const PRODUCTS = new Set([LIFETIME, "spellbee_premium_monthly", "spellbee_premium_yearly"]);
const APPLE_KEY_ID = "V5W3Y45SP4";
const APPLE_ISSUER = "69a6de93-7bad-47e3-e053-5b8c7c11a4d1";

class VerificationError extends Error {
  constructor(code, status = 503) { super(code); this.code = code; this.status = status; }
}
function jwt(header, payload, key, algorithm) {
  const unsigned = [header, payload].map((v) => Buffer.from(JSON.stringify(v)).toString("base64url")).join(".");
  const signature = crypto.sign(algorithm, Buffer.from(unsigned), {key, dsaEncoding: "ieee-p1363"});
  return `${unsigned}.${signature.toString("base64url")}`;
}
async function jsonRequest(url, options = {}, request = fetch) {
  const response = await request(url, {...options, signal: AbortSignal.timeout(12000)});
  let body;
  try { body = await response.json(); } catch (_) { body = {}; }
  if (!response.ok) {
    // Do not propagate provider payloads (which can contain receipts).
    const error = new VerificationError("store_unavailable");
    error.providerStatus = response.status;
    error.providerCode = body.errorCode;
    throw error;
  }
  return body;
}
function validateRequest(body) {
  if (!body || !PRODUCTS.has(body.productId) || !["google_play", "app_store"].includes(body.source)) {
    throw new VerificationError("invalid_request", 400);
  }
  if (body.source === "app_store" && !/^\d{5,30}$/.test(body.credential || "")) {
    throw new VerificationError("invalid_request", 400);
  }
  if (body.source === "google_play" && (typeof body.credential !== "string" || body.credential.length < 10 || body.credential.length > 8192)) {
    throw new VerificationError("invalid_request", 400);
  }
}
function entitlement(productId, active, expiresAt, now, environment = "Production") {
  return {productId, active, expiresAt: expiresAt ? new Date(expiresAt).toISOString() : null,
    verifiedAt: new Date(now).toISOString(), environment};
}
function googleEntitlement(productId, purchase, now = Date.now()) {
  if (productId === LIFETIME) {
    // products.get is scoped to both our package and requested product.
    return entitlement(productId, purchase.purchaseState === 0, null, now);
  }
  const line = (purchase.lineItems || []).filter((v) => v.productId === productId)
    .sort((a, b) => Date.parse(b.expiryTime) - Date.parse(a.expiryTime))[0];
  if (!line) throw new VerificationError("product_mismatch", 422);
  const expiry = Date.parse(line.expiryTime);
  if (!Number.isFinite(expiry)) throw new VerificationError("invalid_store_response");
  const eligible = ["SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_CANCELED", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"].includes(purchase.subscriptionState);
  return entitlement(productId, eligible && expiry > now, expiry, now);
}
// Only decode signed data obtained directly over authenticated HTTPS from
// Apple's Server API. Never use this on a JWS sent by the client.
function decodeAppleResponse(jws) {
  try { return JSON.parse(Buffer.from(jws.split(".")[1], "base64url").toString()); }
  catch (_) { throw new VerificationError("invalid_store_response"); }
}
function appleEntitlement(productId, transaction, status, renewal, now = Date.now()) {
  if (transaction.bundleId !== BUNDLE || transaction.productId !== productId) {
    throw new VerificationError("product_mismatch", 422);
  }
  if (!["Production", "Sandbox"].includes(transaction.environment)) throw new VerificationError("invalid_store_response");
  if (productId === LIFETIME) {
    if (transaction.type !== "Non-Consumable") throw new VerificationError("product_mismatch", 422);
    return entitlement(productId, !transaction.revocationDate, null, now, transaction.environment);
  }
  const expiry = status === 4 ? Number(renewal?.gracePeriodExpiresDate) : Number(transaction.expiresDate);
  if (!Number.isFinite(expiry) || expiry <= 0) throw new VerificationError("invalid_store_response");
  return entitlement(productId, [1, 4].includes(status) && !transaction.revocationDate && expiry > now, expiry, now, transaction.environment);
}
let googleToken;
async function verifyGoogle(body, credentials, request = fetch, now = Date.now()) {
  if (!googleToken || googleToken.until < now) {
    const account = JSON.parse(credentials);
    const seconds = Math.floor(now / 1000);
    const assertion = jwt({alg: "RS256", typ: "JWT"}, {iss: account.client_email,
      scope: "https://www.googleapis.com/auth/androidpublisher", aud: "https://oauth2.googleapis.com/token", iat: seconds, exp: seconds + 3600}, account.private_key, "RSA-SHA256");
    const auth = await jsonRequest("https://oauth2.googleapis.com/token", {method: "POST",
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: new URLSearchParams({grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion}).toString()}, request);
    if (!auth.access_token) throw new VerificationError("store_unavailable");
    googleToken = {value: auth.access_token, until: now + 3000000};
  }
  const root = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${BUNDLE}/purchases`;
  const path = body.productId === LIFETIME ? `products/${body.productId}/tokens` : "subscriptionsv2/tokens";
  try {
    const result = await jsonRequest(`${root}/${path}/${encodeURIComponent(body.credential)}`, {headers: {Authorization: `Bearer ${googleToken.value}`}}, request);
    return googleEntitlement(body.productId, result, now);
  } catch (error) {
    // Expired subscription tokens become unavailable after 60 days.
    if (error.providerStatus === 410) return entitlement(body.productId, false, null, now);
    if (error.providerStatus === 400 || error.providerStatus === 404) throw new VerificationError("purchase_not_found", 422);
    throw error;
  }
}
async function verifyApple(body, key, request = fetch, now = Date.now()) {
  const seconds = Math.floor(now / 1000);
  const token = jwt({alg: "ES256", kid: APPLE_KEY_ID, typ: "JWT"},
    {iss: APPLE_ISSUER, iat: seconds, exp: seconds + 300, aud: "appstoreconnect-v1", bid: BUNDLE}, key, "sha256");
  const options = {headers: {Authorization: `Bearer ${token}`}};
  let host = "https://api.storekit.apple.com";
  let result;
  try {
    result = await jsonRequest(`${host}/inApps/v1/transactions/${body.credential}`, options, request);
  } catch (error) {
    if (error.providerCode === 4000006) throw new VerificationError("invalid_request", 400);
    // Apple's documented production-first flow supports TestFlight/review.
    if (error.providerCode !== 4040010) throw error;
    host = "https://api.storekit-sandbox.apple.com";
    try { result = await jsonRequest(`${host}/inApps/v1/transactions/${body.credential}`, options, request); }
    catch (sandboxError) {
      if (sandboxError.providerCode === 4000006) throw new VerificationError("invalid_request", 400);
      if (sandboxError.providerCode === 4040010) throw new VerificationError("purchase_not_found", 422);
      throw sandboxError;
    }
  }
  const transaction = decodeAppleResponse(result.signedTransactionInfo);
  // Reject other apps before requesting any further customer data.
  if (transaction.bundleId !== BUNDLE || transaction.productId !== body.productId) throw new VerificationError("product_mismatch", 422);
  if (body.productId === LIFETIME) return appleEntitlement(body.productId, transaction, null, null, now);
  const statuses = await jsonRequest(`${host}/inApps/v1/subscriptions/${body.credential}`, options, request);
  const candidates = (statuses.data || []).flatMap((group) => group.lastTransactions || [])
    .map((item) => ({...item, transaction: decodeAppleResponse(item.signedTransactionInfo)}))
    .filter((item) => item.transaction.originalTransactionId === transaction.originalTransactionId && PRODUCTS.has(item.transaction.productId))
    .sort((a, b) => Number(b.transaction.expiresDate) - Number(a.transaction.expiresDate));
  if (!candidates.length) throw new VerificationError("invalid_store_response");
  // A subscription upgrade/downgrade may change the product in the same chain.
  const latest = candidates[0];
  return appleEntitlement(latest.transaction.productId, latest.transaction, latest.status,
    latest.signedRenewalInfo ? decodeAppleResponse(latest.signedRenewalInfo) : null, now);
}
module.exports = {validateRequest, verifyGoogle, verifyApple, googleEntitlement, appleEntitlement, VerificationError};
