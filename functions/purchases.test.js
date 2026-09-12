"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {generateKeyPairSync} = require("node:crypto");
const {validateRequest, googleEntitlement, appleEntitlement, verifyApple, verifyGoogle} = require("./purchases");
const now = Date.parse("2026-09-13T00:00:00Z");
const monthly = "spellbee_premium_monthly";
const yearly = "spellbee_premium_yearly";
const lifetime = "spellbee_premium_lifetime";
const apple = (extra = {}) => ({bundleId: "com.idealai.spellbee", productId: monthly,
  environment: "Production", expiresDate: now + 60000, originalTransactionId: "123456", ...extra});
const google = (state, extra = {}) => ({subscriptionState: state,
  lineItems: [{productId: monthly, expiryTime: new Date(now + 60000).toISOString()}], ...extra});
const jws = (data) => `unused.${Buffer.from(JSON.stringify(data)).toString("base64url")}.unused`;
const response = (body, status = 200) => ({ok: status === 200, status, json: async () => body});
const ecKey = generateKeyPairSync("ec", {namedCurve: "prime256v1"}).privateKey.export({type: "pkcs8", format: "pem"});

test("request restricts products, store and purchase identifiers", () => {
  assert.throws(() => validateRequest({source: "app_store", productId: "other", credential: "123456"}));
  assert.throws(() => validateRequest({source: "app_store", productId: monthly, credential: "../../other"}));
  assert.throws(() => validateRequest({source: "google_play", productId: monthly, credential: ""}));
  validateRequest({source: "app_store", productId: monthly, credential: "123456"});
});
test("Google cancellation preserves paid-through access and expiry is exact", () => {
  for (const status of ["ACTIVE", "CANCELED", "IN_GRACE_PERIOD"]) {
    const value = googleEntitlement(monthly, google(`SUBSCRIPTION_STATE_${status}`), now);
    assert.equal(value.active, true);
    assert.equal(value.expiresAt, new Date(now + 60000).toISOString());
    assert.equal(googleEntitlement(monthly, google(`SUBSCRIPTION_STATE_${status}`), now + 60000).active, false);
  }
});
test("Google hold, pause, pending, expired and revoked lifetime never grant", () => {
  for (const state of ["ON_HOLD", "PAUSED", "PENDING", "EXPIRED", "PENDING_PURCHASE_CANCELED"]) {
    assert.equal(googleEntitlement(monthly, google(`SUBSCRIPTION_STATE_${state}`), now).active, false);
  }
  assert.equal(googleEntitlement(lifetime, {purchaseState: 1}, now).active, false);
  assert.equal(googleEntitlement(lifetime, {purchaseState: 2}, now).active, false);
  assert.equal(googleEntitlement(lifetime, {purchaseState: 0}, now).active, true);
  assert.throws(() => googleEntitlement(yearly, google("SUBSCRIPTION_STATE_ACTIVE"), now));
});
test("Apple validates bundle, product, environment and lifetime type", () => {
  assert.throws(() => appleEntitlement(monthly, apple({bundleId: "other"}), 1, null, now));
  assert.throws(() => appleEntitlement(yearly, apple(), 1, null, now));
  assert.throws(() => appleEntitlement(monthly, apple({environment: "Xcode"}), 1, null, now));
  assert.throws(() => appleEntitlement(lifetime, apple({productId: lifetime}), null, null, now));
});
test("Apple refunds and expired or billing-retry subscriptions remove access", () => {
  assert.equal(appleEntitlement(monthly, apple({revocationDate: now - 1}), 1, null, now).active, false);
  for (const status of [2, 3, 5]) assert.equal(appleEntitlement(monthly, apple(), status, null, now).active, false);
  assert.equal(appleEntitlement(monthly, apple({expiresDate: now}), 1, null, now).active, false);
  assert.equal(appleEntitlement(lifetime, apple({productId: lifetime, type: "Non-Consumable", revocationDate: now}), null, null, now).active, false);
});
test("Apple configured grace uses store grace expiry only", () => {
  const value = appleEntitlement(monthly, apple({expiresDate: now - 1}), 4, {gracePeriodExpiresDate: now + 60000}, now);
  assert.equal(value.active, true);
  assert.equal(value.expiresAt, new Date(now + 60000).toISOString());
  assert.throws(() => appleEntitlement(monthly, apple(), 4, {}, now));
});
test("Apple production-first sandbox fallback and latest upgraded subscription", async () => {
  const urls = [];
  const request = async (url) => {
    urls.push(url);
    if (urls.length === 1) return response({errorCode: 4040010}, 404);
    if (urls.length === 2) return response({signedTransactionInfo: jws(apple({environment: "Sandbox"}))});
    return response({data: [{lastTransactions: [{status: 1, signedTransactionInfo: jws(apple({productId: yearly, environment: "Sandbox", expiresDate: now + 120000}))}]}]});
  };
  const result = await verifyApple({productId: monthly, credential: "123456"}, ecKey, request, now);
  assert.equal(result.productId, yearly);
  assert.equal(result.active, true);
  assert.match(urls[1], /storekit-sandbox/);
  assert.equal(result.environment, "Sandbox");
});
test("Apple API authentication failure does not fall back or grant", async () => {
  let calls = 0;
  await assert.rejects(() => verifyApple({productId: monthly, credential: "123456"}, ecKey, async () => {
    calls++; return response({}, 401);
  }, now));
  assert.equal(calls, 1);
});
test("Apple numeric identifier outside provider range is a client error", async () => {
  await assert.rejects(() => verifyApple({productId: monthly, credential: "99999999999999999999"}, ecKey,
    async () => response({errorCode: 4000006}, 400), now),
  (error) => error.code === "invalid_request" && error.status === 400);
});
test("Google package is server-fixed and credentials are sent only to Google", async () => {
  const privateKey = generateKeyPairSync("rsa", {modulusLength: 2048}).privateKey.export({type: "pkcs8", format: "pem"});
  const urls = [];
  const result = await verifyGoogle({productId: monthly, credential: "store-purchase-token", packageName: "evil"},
    JSON.stringify({client_email: "test@example.invalid", private_key: privateKey}), async (url) => {
      urls.push(url);
      return urls.length === 1 ? response({access_token: "mock-token"}) : response(google("SUBSCRIPTION_STATE_ACTIVE"));
    }, now);
  assert.equal(result.active, true);
  assert.match(urls[1], /applications\/com.idealai.spellbee\/purchases\/subscriptionsv2/);
});
