# SpellBee 1.2.0 release

## Scope

- Paste school words from lines or comma-separated text, edit preview, deduplicate, and preserve existing definitions, sentences and list identity.
- Today’s practice: 5 words for a new learner, then 8, mixing due words with the selected level.
- Report first-try results separately from completion; independent recall excludes hints, tiles, retries and same-day repetitions. Existing history is preserved, not relabeled as mastery.
- Native-store purchase verification, actual expiry, save-before-acknowledgement, safe historical restores, launch/resume/Restore refresh, credential-redacted exports and available-product paywall handling.
- Public support/privacy site restored at https://nalhamzy.github.io/spellbee/.

## Validation

- Flutter pub get completed; analyze: no issues; 119 unit/widget tests pass with `flutter test --no-pub --concurrency=1`.
- 10 backend tests pass, including expiry, refund, grace, product/bundle mismatch, restore order, sandbox fallback and malformed Apple ID.
- Final build 20 local release AAB (45.1MB) built; build 19 debug APK and release APK (54.7MB) also built.
- iOS icon opaque; master is branded; privacy manifest registered correctly with four references and no project BOM.
- Live Google/Apple endpoint probes authenticated and rejected nonexistent purchases (422); malformed requests return 400. Purchase lifecycle fixtures are automated; no real sandbox buy/renew/refund was performed.
- Native build 19 walkthrough passed: bulk paste, duplicate removal, save, wrong→correct retry scoring, Stats, and persisted list/results after force-stop/relaunch. See release-evidence/2026-09-13/native-smoke-build19.md. Build 20 adds text/field-label contrast and hardens the already-assisted Daily Word entry route. A hot restart loaded final Dart source into the installed build 19 debug shell and verified the Home contrast; this is not a complete packaged build 20 smoke test.

## Deployment

Final source commit 95b33dc2b75bc6f21abfba306ec4f7af62245b5b; tag v1.2.0-build20.
Codemagic build 6aa5c743c12cd81c2bdf6a78 started 2026-09-12 21:42 UTC, both platforms. Final state: `finished`; every action succeeded, including Android AAB, iOS IPA, signing and Publishing.
Firebase spellbeeVerifyPurchase deployed to project rhyme-aa29b, us-central1. Secrets remain in Firebase Secret Manager. Narrow deploy did not alter other portfolio functions.
GitHub Pages source main/docs enabled; privacy page HTTP 200 verified.
App Store version 8743ec5c-f77c-46b3-ba37-472c3f278b1c created with metadata and review notes; inherited phone/tablet screenshots retained.
Apple build 657b2d46-a520-4a9a-a645-8ecd2d73848f, version 1.2.0 (20), is now `VALID`, with `usesNonExemptEncryption: false`, and is selected on the public version. Submitted for App Review at **2026-09-13 11:34:35 UTC / 15:34 Dubai**. Submission 452a9bc6-3797-407a-82bf-b14c2d019145 and version 8743ec5c-f77c-46b3-ba37-472c3f278b1c both read `WAITING_FOR_REVIEW`. The browser confirmed **1 Item Submitted**. Automatic public release after approval remains configured; existing ratings are preserved.

TestFlight build 20 is `IN_BETA_TESTING` internally. Codemagic's separate external-beta task 6aa5c9370b9141d3ac30f2c7 failed with Apple 422 because build 19 is already in beta review in the same train. Build 20's external beta state is `READY_FOR_BETA_SUBMISSION`. This did not block the successful public App Review submission. Beta review instructions are filled; SpellBee requires no app login.
Google Play English description and short description updated; Data safety answers submitted for review. No advertising/tracking; processor transfers follow the service-provider exception.

Google Play accepted final build 20 on production. Edit 04038829210248633350 committed a 10% staged rollout (`inProgress`, `userFraction: 0.1`) while retaining completed build 17. Publishing overview visibly shows **Changes in review → Production → 1.2.0 (20) → Start staged rollout at 10%**, alongside listing and Data safety updates. On 13 September at 15:35 Dubai, quick checks had finished and the Console confirmed **Your changes are now in review**. The release is submitted, not yet confirmed publicly available.

## Store privacy answers

Google Play: purchase history collected ephemerally for functionality/fraud prevention; optional speech audio and pronunciation text collected for functionality; operational interactions and diagnostics retained for service monitoring; hashed network identifiers retained for functionality/monitoring/abuse prevention. All optional features; no app account; encrypted transit; deletion-contact URL points to support; existing Families commitment retained. No advertising or cross-app tracking. The privacy policy explains operating-system speech processing and third-party voice services.

App Store privacy label updated and published through the signed-in browser before submission. Other User Content and Other Diagnostic Data: App Functionality. Device ID and Product Interaction: Analytics and App Functionality. All four are conservatively declared linked because requests, network identifiers and service data are not guaranteed to be anonymized before collection. No tracking or advertising purpose is selected. The preview shows User Content, Identifiers, Usage Data and Diagnostics; no setup items remain.

Apple and Google use different disclosure rules. Apple excludes temporary real-time verification proofs and data collected solely by Apple's own speech framework; the public privacy policy still explains both flows. The retained network hash is declared as an identifier, not location. Rationale follows [Apple's privacy disclosure guidance](https://developer.apple.com/app-store/app-privacy-details/), including its IP-address, Apple-framework and real-time-processing guidance. Local-only school lists and history are not declared as uploaded gameplay records.

## Known boundaries

No real-time store notification processing, cross-store purchase transfer, learner profiles, cloud backup, weekly reports, photo OCR, or acquisition attribution added. Legacy premium caches retain their original expiry while awaiting a successful restore. Refunded lifetime access is removed after successful online verification, not instantly while offline. Quota docs have expiry timestamps but Firestore TTL is not yet enabled; privacy copy makes no automatic-deletion time promise.

Apple accepted the final upload with no errors and one future compatibility warning: the current iOS 13 minimum must rise to at least iOS 15 for uploads/distribution starting in spring 2027. This did not block this upload. Plan that SDK/OS-floor migration separately with device-coverage validation.

## Growth baseline

Google Play Console viewed 13 September 2026: last 28 days: 171 device acquisitions (+375%), 113 first opens (+352%), 145 monthly active devices (+480%); installed audience 123. These are console snapshots, not a causal impact claim for this unreleased version.


Build 19 first upload: Codemagic finished; publishing succeeded; Play production draft 19 accepted; ASC build ce236488-f770-427e-8730-b444a62d7b04 VALID. Build 20 supersedes 19 for public submission.

## Rollout plan

Start Google Play at 10% after review because this release changes learning records and purchase verification. Expand after checking crashes/ANRs, support reports, and real-device purchase/restore behavior. No automatic expansion or recurring monitor was configured. Keep version 1.1.0 available to the remaining audience during the staged rollout.

The staged setting follows the [Google Play track release API](https://developers.google.com/android-publisher/api-ref/rest/v3/edits.tracks): `inProgress` with `userFraction` specifies the eligible fraction. Console review status, rather than the API setting alone, determines whether the pending release has actually reached users.

## Verified submission status

| App | Version | Platform | Codemagic | Publishing | Store State | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| SpellBee | 1.2.0 (20) | iOS | Finished | Upload succeeded | Waiting for Review | Privacy updated; automatic release after approval; external beta review separately deferred |
| SpellBee | 1.2.0 (20) | Android | Finished | Upload succeeded | In review | 10% staged production rollout after approval |

## Remaining release steps

1. Await Apple and Google review outcomes before calling the new versions publicly live. No further submission or sign-in action is currently needed from the user.
2. Validate real-device purchase/restore behavior and reliability before expanding Google Play beyond 10%. No scheduled follow-up is installed.
3. If external TestFlight distribution of build 20 is still needed, submit its beta review after build 19's beta review finishes. Internal TestFlight and public App Review are already available/submitted respectively.
