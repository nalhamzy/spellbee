# Purchase reliability release checks

Updated 29 September 2026 for 1.3.0 (22). The verification backend and public support/privacy site are deployed. No real sandbox purchase lifecycle has been exercised in this session; no Android phone was connected. Store build/submission status is recorded separately in [release-1.3.0.md](release-1.3.0.md).

## Implemented and regression-tested

- [x] Access persistence succeeds before acknowledging a purchased/restored transaction.
- [x] Failed storage writes, including a `false` return, leave completion pending for recovery.
- [x] Concurrent transaction batches are serialized and duplicate identified transactions are handled once per service session.
- [x] Completion failures retry without repeating successful persistence in that session.
- [x] UI notification failures and individual transaction failures do not block later transactions.
- [x] Concurrent initialization creates one listener; unavailable stores can reconnect; disposal prevents a late listener.
- [x] Only supported, available product IDs appear as selectable plans; partial product responses have a usable default.
- [x] Displayed localized price, selected plan, disclosure and checkout agree.
- [x] Purchase launch and restore have busy/error handling; screenshot fixtures cannot buy or restore.
- [x] Narrow-phone layout with enlarged text and long localized prices passes widget checks.
- [x] All 146 Flutter unit/widget tests and 10 backend provider tests pass; static analysis is clean.
- [x] A fresh grown-up challenge precedes checkout; cancellation and exhausted attempts do not launch a purchase.
- [x] Verified purchase/restore returns to the feature that opened Premium. A late restore does not cause duplicate checkout after the grown-up challenge.
- [x] Premium automatically enables online custom-word voices when no explicit voice preference exists. Deliberate preferences survive upgrades and expiry.
- [x] Existing monthly/yearly plans provide the same Apple subscription service level; active products and localized prices were read from both stores without changing prices.

## Before release

- [x] Verify monthly/yearly/lifetime product availability in App Store Connect and through the Android Publisher product APIs, including active base plans/purchase options.
- [ ] On iOS and Android sandbox devices: buy each offered plan, cancel checkout, interrupt/relaunch, restore after reinstall, and exercise pending/Ask to Buy approval.
- [ ] Confirm the durable saved entitlement survives process restart. Test store failure during acknowledgement and recovery with Restore.
- [ ] Confirm no duplicate charges/launches under rapid taps and no duplicate access notifications during redelivery.
- [ ] Verify accurate pricing and layout in the principal territories with native fonts and accessibility settings.
- [ ] Recapture paywall store assets when replacing the existing listing screenshots; current screenshots predate these changes and were preserved.
- [ ] Check restore guidance on both platforms and record the outcome of an empty restore separately from successful entitlement delivery.

## Verified access in this release

Apple Server API and Google Android Publisher API determine access. Subscriptions use actual expiry; cached proofs refresh on launch, resume and Restore. Historical subscription restores cannot replace active lifetime access. Legacy local access keeps its original date on an outage and migrates through a native restore; a restore never restarts its window. Exports omit cached credentials. See `purchase-verification.md`.

The deployed endpoint was checked against both live provider APIs with nonexistent purchase proofs: both return 422 after successful authentication. Invalid products return 400. Real sandbox buy/renew/refund/restore remains distinct, unperformed validation; automated tests cover these state transitions with fixtures.

The busy state covers purchase-sheet/restore launch, not the full duration of a store-side deferred approval. This release does not add real-time store notification processing or cross-platform purchase transfer.
