# SpellBee 1.2.0 release

## Scope

- Paste school words from lines or comma-separated text, edit preview, deduplicate, and preserve existing definitions, sentences and list identity.
- Today’s practice: 5 words for a new learner, then 8, mixing due words with the selected level.
- Report first-try results separately from completion; independent recall excludes hints, tiles, retries and same-day repetitions. Existing history is preserved, not relabeled as mastery.
- Native-store purchase verification, actual expiry, save-before-acknowledgement, safe historical restores, launch/resume/Restore refresh, credential-redacted exports and available-product paywall handling.
- Public support/privacy site restored at https://nalhamzy.github.io/spellbee/.

## Validation

- Flutter pub get completed; analyze: no issues; 118 unit/widget tests pass.
- 10 backend tests pass, including expiry, refund, grace, product/bundle mismatch, restore order, sandbox fallback and malformed Apple ID.
- Local release AAB (45.1MB), debug APK and release APK (54.7MB) built.
- iOS icon opaque; master is branded; privacy manifest registered correctly with four references and no project BOM.
- Live Google/Apple endpoint probes authenticated and rejected nonexistent purchases (422); malformed requests return 400. Purchase lifecycle fixtures are automated; no real sandbox buy/renew/refund was performed.
- Native build 19 walkthrough passed: bulk paste, duplicate removal, save, wrong→correct retry scoring, Stats, and persisted list/results after force-stop/relaunch. See release-evidence/2026-09-13/native-smoke-build19.md. Build 20 adds text/field-label contrast and hardens the already-assisted Daily Word entry route.

## Deployment

Source commit 407bf689a5376157bc796b8c9b669cb6279ef455; tag v1.2.0.
Codemagic build 6aa5c249c12cd81c2bdf6005 started 2026-09-12 21:21UTC, both platforms.
Firebase spellbeeVerifyPurchase deployed to project rhyme-aa29b, us-central1. Secrets remain in Firebase Secret Manager. Narrow deploy did not alter other portfolio functions.
GitHub Pages source main/docs enabled; privacy page HTTP 200 verified.
App Store version 8743ec5c-f77c-46b3-ba37-472c3f278b1c created with metadata and review notes; inherited phone/tablet screenshots retained.
Google Play English description and short description updated; Data safety answers saved for review. No advertising/tracking; processor transfers follow the service-provider exception.

## Store privacy answers

Google Play: purchase history collected ephemerally for functionality/fraud prevention; optional speech audio and pronunciation text collected for functionality; operational interactions and diagnostics retained for service monitoring; hashed network identifiers retained for functionality/monitoring/abuse prevention. All optional features; no app account; encrypted transit; deletion-contact URL points to support; existing Families commitment retained. No advertising or cross-app tracking. The privacy policy explains operating-system speech processing and third-party voice services.

App Store privacy nutrition label still requires a signed-in App Store Connect browser. The public API handles metadata but not that full questionnaire. A sign-in request was sent to the user while build work continued. Do not submit iOS publicly with the old “Data Not Collected” label without reviewing it against the current service behavior.

## Known boundaries

No real-time store notification processing, cross-store purchase transfer, learner profiles, cloud backup, weekly reports, photo OCR, or acquisition attribution added. Legacy premium caches retain their original expiry while awaiting a successful restore. Refunded lifetime access is removed after successful online verification, not instantly while offline. Quota docs have expiry timestamps but Firestore TTL is not yet enabled; privacy copy makes no automatic-deletion time promise.

## Growth baseline

Google Play Console viewed 13 September2026: last 28 days: 171 device acquisitions (+375%), 113 first opens (+352%), 145 monthly active devices (+480%); installed audience 123. These are console snapshots, not a causal impact claim for this unreleased version.


Build 19 first upload: Codemagic finished; publishing succeeded; Play production draft19 accepted; ASC build ce236488-f770-427e-8730-b444a62d7b04 VALID. Build 20 supersedes19 for public submission.
