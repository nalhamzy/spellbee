# Store verification — 2026-09-13

SpellBee retains native `in_app_purchase`. New purchases and restores are checked against the store's current server record before access is saved and the transaction is acknowledged. No client-reported dates or JWS claims grant access.

## Deployment contract

Deploy `functions:spellbee:spellbeeVerifyPurchase` to `rhyme-aa29b` before publishing this client. Endpoint: `https://us-central1-rhyme-aa29b.cloudfunctions.net/spellbeeVerifyPurchase`.

Server-only Firebase secrets:

- `SPELLBEE_PLAY_SERVICE_ACCOUNT`: service account JSON with Android Publisher API access and Play Console order/subscription permissions for `com.idealai.spellbee`.
- `SPELLBEE_APPLE_IAP_KEY`: team In-App Purchase private key contents. Configured public key ID `V5W3Y45SP4`, issuer `69a6de93-7bad-47e3-e053-5b8c7c11a4d1`.

POST JSON: `{ "source": "google_play" | "app_store", "productId": "spellbee_premium_monthly" | "spellbee_premium_yearly" | "spellbee_premium_lifetime", "credential": "..." }`.

Google credential is `serverVerificationData` (purchase token); Apple credential is the native `purchaseID` (transaction ID). The endpoint uses the fixed SpellBee package/bundle, never a client-provided app identifier. Apple's transaction/status JWS is decoded only after retrieval directly from Apple's authenticated HTTPS API, never from a client JWS. Production is queried first; transaction-not-found retries sandbox for TestFlight and review. No account or learner data is submitted.

200 response: `{ "productId": "...", "active": true | false, "expiresAt": "ISO timestamp" | null, "verifiedAt": "ISO timestamp", "environment": "Production" | "Sandbox" }`. An Apple subscription upgrade can return the new product from the same original transaction chain. Invalid requests return 400; purchase/product mismatch 422; provider/configuration failures 503; rate caps 429. No tokens, identifiers or provider response bodies are logged.

Hourly request quotas are enforced atomically in Firestore (120/IP; 10,000 global). Configure Firestore TTL on `spellbee_purchase_quota.expiresAt` to clean old counters; merely writing this field does not enable TTL. Quota failures preserve cached access and prevent a new grant.

## Existing customers and offline behavior

- Existing lifetime customers keep access while migrating through native restore. Legacy monthly/yearly cache retains its original 35/370-day deadline during outages; restore never resets that date.
- Verified subscriptions use the exact store expiry, including a provider-authorized grace period. Cancellation retains paid-through access. Paused/on-hold/pending/expired/revoked states do not grant access. There is no new locally invented subscription grace period.
- A verified lifetime purchase is available offline. Its saved proof is rechecked on launch/resume and explicit Restore so refunds are removed even if native restore omits them. Refund detection requires connectivity; the app does not poll stores while offline or backgrounded.
- Cached proof is saved locally with the entitlement so launch/resume/Restore can refresh it. Support exports redact the bearer credential. It is sent only over HTTPS to the verification endpoint and to the relevant provider from the server.
- Historical subscription restores cannot downgrade an active lifetime purchase. New delivery is acknowledged only after server verification and durable persistence. Transient verification/save failures remain retryable through native redelivery/Restore.

This release does not add real-time store webhooks, user accounts, cross-platform purchase sharing, or remote enforcement for locally modified binaries. Revocation is checked when the app contacts the server.

## Validation and operational probes

Run `npm test` and `npm run lint` in `functions`, plus Flutter billing tests. Tests cover genuine paid-through cancellation, exact expiry, grace, revocation/refund, mismatched app/product, sandbox fallback, subscription upgrades, migration, offline errors and restore ordering.

Safe credential probes after deployment: an unknown product must return 400; a valid product with an intentionally nonexistent Apple numeric transaction (for example `1234567890123456`) should yield 422 after authenticated production and sandbox lookups; an invalid Google token should yield 422 after authenticated Play lookup. Apple rejects out-of-range numeric identifiers with `4000006`, mapped to HTTP 400. A 503 may indicate unavailable credentials/API/permissions; inspect only sanitized provider status. These probes are not substitutes for real sandbox purchases, renewal, refund and restore checks before public promotion.

Live Apple credential probe on 2026-09-13 returned HTTP 422 `purchase_not_found` for `1234567890123456`, confirming the deployed function could authenticate and query both production and sandbox. The earlier all-nines 20-digit probe was outside Apple's transaction ID range, not an authentication failure.

Official references: [Apple Server API](https://developer.apple.com/documentation/appstoreserverapi), [Apple subscription statuses](https://developer.apple.com/documentation/appstoreserverapi/get-all-subscription-statuses), [Google subscription resource](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2), [Google one-time purchase lookup](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products/get).
