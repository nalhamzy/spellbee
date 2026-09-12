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
Apple upload 657b2d46-a520-4a9a-a645-8ecd2d73848f confirms version 1.2.0 build 20 uploaded at 2026-09-12 21:50:45 UTC. The upload API reports `PROCESSING`, no errors. Codemagic's subsequent TestFlight distribution task 6aa5c9370b9141d3ac30f2c7 remains pending processing; do not describe build 20 as TestFlight-ready until it becomes valid and distribution completes. Public version remains `PREPARE_FOR_SUBMISSION`; final build selection must follow processing. Beta review instructions have been filled, with no login required inside SpellBee.
Google Play English description and short description updated; Data safety answers submitted for review. No advertising/tracking; processor transfers follow the service-provider exception.

Google Play accepted final build 20 on production. Edit 04038829210248633350 committed a 10% staged rollout (`inProgress`, `userFraction: 0.1`) while retaining completed build 17. Publishing overview visibly shows **Changes in review → Production → 1.2.0 (20) → Start staged rollout at 10%**, alongside listing and Data safety updates. At verification, automated quick checks were running; the release is submitted, not yet confirmed publicly available.

## Store privacy answers

Google Play: purchase history collected ephemerally for functionality/fraud prevention; optional speech audio and pronunciation text collected for functionality; operational interactions and diagnostics retained for service monitoring; hashed network identifiers retained for functionality/monitoring/abuse prevention. All optional features; no app account; encrypted transit; deletion-contact URL points to support; existing Families commitment retained. No advertising or cross-app tracking. The privacy policy explains operating-system speech processing and third-party voice services.

App Store privacy nutrition label still requires a signed-in App Store Connect browser. The public API handles metadata but not that full questionnaire. A sign-in request was sent to the user while build work continued. Do not submit iOS publicly with the old “Data Not Collected” label without reviewing it against the current service behavior.

## Known boundaries

No real-time store notification processing, cross-store purchase transfer, learner profiles, cloud backup, weekly reports, photo OCR, or acquisition attribution added. Legacy premium caches retain their original expiry while awaiting a successful restore. Refunded lifetime access is removed after successful online verification, not instantly while offline. Quota docs have expiry timestamps but Firestore TTL is not yet enabled; privacy copy makes no automatic-deletion time promise.

Apple accepted the final upload with no errors and one future compatibility warning: the current iOS 13 minimum must rise to at least iOS 15 for uploads/distribution starting in spring 2027. This did not block this upload. Plan that SDK/OS-floor migration separately with device-coverage validation.

## Growth baseline

Google Play Console viewed 13 September 2026: last 28 days: 171 device acquisitions (+375%), 113 first opens (+352%), 145 monthly active devices (+480%); installed audience 123. These are console snapshots, not a causal impact claim for this unreleased version.


Build 19 first upload: Codemagic finished; publishing succeeded; Play production draft 19 accepted; ASC build ce236488-f770-427e-8730-b444a62d7b04 VALID. Build 20 supersedes 19 for public submission.

## Rollout plan

Start Google Play at 10% after review because this release changes learning records and purchase verification. Expand after checking crashes/ANRs, support reports, and real-device purchase/restore behavior. No automatic expansion or recurring monitor was configured. Keep version 1.1.0 available to the remaining audience during the staged rollout.

The staged setting follows the [Google Play track release API](https://developers.google.com/android-publisher/api-ref/rest/v3/edits.tracks): `inProgress` with `userFraction` specifies the eligible fraction. Console review status, rather than the API setting alone, determines whether the pending release has actually reached users.

## Remaining release steps

1. After Apple finishes processing upload 657b2d46-a520-4a9a-a645-8ecd2d73848f, verify final build 20 is `VALID`, export compliance is false, and TestFlight distribution completes. Select build 20 on App Store version 8743ec5c-f77c-46b3-ba37-472c3f278b1c.
2. The user must sign into the retained App Store Connect Chrome page. Review and update the App Privacy nutrition label against the documented service behavior, then submit 1.2.0 for App Review. Deployment authorization is already provided; no new deployment approval is required.
3. Check Google Play's review outcome before calling the 10% rollout live. Validate real-device purchase/restore behavior and reliability before expansion. No scheduled follow-up is installed.
