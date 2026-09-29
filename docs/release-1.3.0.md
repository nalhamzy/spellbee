# SpellBee 1.3.0 (22) — Bee Adventures and voice reliability

## Why this release

The audit found working, live purchase products but weak differentiation and real audio failures. The old asset-manifest lookup missed bundled recordings on current Flutter; an uncached online speech request could self-await indefinitely. Fixing those failures and demonstrating a useful free experience takes priority over discounting. See [the dated conversion audit](conversion-audit-2026-09-29.md) for verified store prices, aggregate evidence and its limits.

## Changes

- Three illustrated Bee Adventures, four short stops each. Sunny Meadow is entirely free; the two additional worlds use the existing Premium entitlement. Progress is local and independent recall remains honestly measured.
- Bee Buddy recordings cover every built-in word and its contextual prompts, story narration and feedback. Slow repeat actually slows the recording. Stop/cancellation invalidates late playback; online custom speech uses a fixed, prompted model with bounded fallback.
- Premium automatically enables online custom-word speech when no explicit voice preference exists. A parent's deliberate choice is preserved, including across restore, renewal and expiry. Included Bee Buddy recordings still take priority for core words.
- Parent-oriented paywall: annual primary, lifetime alternative, monthly available, native localized prices, no invented trial or Family Sharing claim. A parent challenge precedes checkout. Verified purchase/restore returns to the invoking screen and removes duplicate purchase prompts.
- Free offline packs remain accessible after an online credit is exhausted. Marketing distinguishes included voices and local practice from paid custom content.
- Apple equal-service monthly/yearly subscription levels aligned; misleading Play paid ad-removal benefit removed. Prices, product IDs and access periods unchanged.

## Review notes

Open Home → Bee Adventures. Sunny Meadow is available without purchase. Moonlight Garden and Rainbow Falls show a preview and a clearly labeled grown-up Premium route. Solve the displayed multiplication challenge to open native checkout; cancellation does not grant Premium. Restore is available on the paywall and in Settings. Existing receipts remain server-verified. No test entitlement or screenshot price override is enabled in release builds.

Settings → Voice explains AI-generated speech and the free included voice. Core words play offline. Studio selects an online voice for custom words with Premium. A network outage falls back to device speech. No child voice cloning or open-ended child AI chat is present.

## Validation and deployment

- Final build 22 Flutter analyzer: no issues. Complete final suite: all 146 tests passed.
- Build 22 voice-default validation: 28 voice, preference and paywall tests passed; analyzer remained clean. The new tests cover an immediate verified upgrade, expiry and preservation of a parent's explicit choice.
- Backend: all 10 purchase-verification tests and JavaScript syntax checks passed on Node 22.
- Release web build succeeded. Phone-size browser smoke completed a four-word Meadow stop using tiles, showed 4/4 correct with 0/4 independent recall, returned to the story map, saved 1/4 completion and unlocked stop 2. Narration, word and feedback MP3 requests returned 200.
- Android ARM64 release APK built successfully, approximately 95 MB. No Android phone was connected for native listening or purchase testing. CI produces the authoritative store AAB and IPA with production configuration.
- Updated SpellBee functions deployed successfully on Node 22: TTS, purchase verification and the existing TTS statistics endpoint. Node 20 was nearing its deployment cutoff. The initial local function-discovery timeout was resolved by increasing discovery time to 60 seconds. Function source and per-app scope are unchanged.
- Live backend probes after deployment: pinned-model speech returned 200 `audio/mpeg`; deliberately invalid Apple and Play purchase proofs each returned 422 `purchase_not_found`, confirming authenticated provider lookups without granting access.

Both stores accepted build 22 for review; the final verified states and IDs are recorded below. Build 22 is not yet publicly live. Genuine sandbox purchases, renewals, refunds and crossgrades were not performed and are not represented by fixture tests or invalid-token probes.

## Suggested store release notes

Meet Bee Buddy and explore Bee Adventures! Help flowers bloom, light a moonlit garden and discover Rainbow Falls in short spelling challenges. Sunny Meadow is free to play. Enjoy clearer offline voices for built-in words and clues, more reliable custom-word speech, and a simpler Premium experience for grown-ups.

## Apple release draft prepared — September 29, 2026, 10:51 UTC

App | Version | Platform | Codemagic | Publishing | Store state | Notes
--- | --- | --- | --- | --- | --- | ---
SpellBee | 1.3.0 (intended build 21) | iOS | Not triggered by this preparation | Not uploaded by this preparation | PREPARE_FOR_SUBMISSION | AFTER_APPROVAL; selected build is empty; not submitted

Created App Store version `3c465207-2215-4f32-9637-8eb57213e9f9` for app `6768096917` (HTTP 201). The en-US localization is `ca92892b-7ee4-416f-8488-42d7fe57d4f5`; App Review detail is `799e187c-ec4b-439a-9531-f73d86f6d9b2`.

Saved and read back the corrected description, release notes and review instructions (both PATCH requests HTTP 200). The copy explicitly separates free Sunny Meadow and included offline Bee Buddy recordings from the two Premium worlds, unlimited custom lists/Math Bee and online custom-word voices. It makes no trial, Family Sharing, efficacy or conversion claim. Exact saved text is in [listing-1.3.0.md](listing-1.3.0.md).

Preservation checks compared the draft against version 1.2.0: keywords, marketing/support URLs, app name, subtitle and privacy URL remain identical; existing review contact and account-requirement fields remain identical. Apple initially left promotional text empty when creating the version, so the existing text was restored unchanged. Copyright remains `2026 Ideal AI`. Screenshot filenames, sizes and source checksums match the prior version, with all assets COMPLETE: eight each for APP_IPHONE_67, APP_IPHONE_65 and APP_IPAD_PRO_3GEN_129. No screenshot was uploaded or replaced.

Editable fields changed are draft localization `description` and `whatsNew`, App Review `notes`, and restoration of unchanged `promotionalText`; the version was created with `releaseType: AFTER_APPROVAL`. The selected build relationship remains null. Attach only uploaded build 21 after its processing state is VALID and root confirms readiness; build 20 was never selected. No App Review submission, Google Play edit, purchase or CI trigger was performed in this preparation.

Schemas were inspected from Apple's current documentation before requests: [create version](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-appstoreversions), [update localization](https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-appstoreversionlocalizations-_id_), and [update review detail](https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-appstorereviewdetails-_id_).

## Build 21 superseded before publishing

Tag `v1.3.0-build21` auto-triggered Codemagic `release-both` build `6abb98c63f90aeed9672589c` from commit `7ce404c9587aef13f919c5c847f5a4fb391dd45f` at 2026-09-29 10:54:04 UTC. Setup and package resolution passed. During the Android bundle step, final review identified a Premium voice-default improvement for build 22. The build was intentionally canceled using the documented Codemagic cancel endpoint (HTTP 200); readback is `canceled`, Publishing was never started. No build 21 selection, store submission or artifact deletion occurred.

Preliminary Apple readiness checks passed: existing Education category and 4+ rating metadata populated; reviewer contact fields complete; no demo account required; marketing, support and privacy pages each HTTP 200. Source Info.plist declares `ITSAppUsesNonExemptEncryption=false`. These checks do not replace verification of the final uploaded build. The next intended release artifact is build 22; the earlier build-21 preparation instructions are superseded.

## Final build 22 and store submissions — September 29, 2026

| App | Version | Platform | Codemagic | Publishing | Store state | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| SpellBee | 1.3.0 (22) | iOS | Finished; all actions successful | Upload succeeded | WAITING_FOR_REVIEW | Build VALID and selected; automatic release AFTER_APPROVAL |
| SpellBee | 1.3.0 (22) | Android | Finished; all actions successful | Upload succeeded | RELEASE_LIFECYCLE_STATE_IN_REVIEW | Production configured for full rollout after approval; build 20 remains PUBLISHED |

**Build 22 is not yet publicly live.** Store review is pending. These are verified submission states, not an approval or availability claim.

Final source commit `141860192d665c28e451e595d818ba14266892fc`, immutable tag `v1.3.0-build22`. The tag automatically started Codemagic `release-both` build `6abb99bf3f90aeed96725ca1`; no manual duplicate was triggered. It ran from 10:59:28 to 11:12:54 UTC. Every action succeeded, including Android AAB, iOS IPA, signing, publishing and cleanup. App Store Connect distribution task `6abb9cec3a52b5364a334ec6` subsequently finished.

Final local validation, reported by the release owner: 146 Flutter tests passed; analyzer clean; 10 backend tests passed; release web and ARM64 APK builds succeeded. The APK signature verified with v2, package `com.idealai.spellbee`, version 1.3.0, code 22, target SDK 36. Local APK SHA-256: `6AE7CD14D9F31DA4C1931E82762C88CAA844740458A7DBF9575821D055726423`. This checksum identifies the local APK, not the CI AAB or IPA. The final browser reload retained Meadow 1/4 completion and unlocked stop 2. No Android phone was connected for native listening or purchase testing.

### Apple

App Store build `3af739f4-bca9-46e0-8bf9-b740c2b76dd6`, train 1.3.0/build 22, uploaded at 11:12:48 UTC, is VALID and APP_STORE_ELIGIBLE. `usesNonExemptEncryption` was already false, consistent with Info.plist, so no export-compliance mutation was needed. Build selection PATCH returned HTTP 200, and the selected-build relationship read back the exact build 22 ID.

Before submission, the saved description, release notes and review instructions matched [listing-1.3.0.md](listing-1.3.0.md) exactly; review contacts were complete, no demo account was required, and all 24 inherited screenshots were COMPLETE. Existing category, age rating, support/privacy URLs and metadata preservation checks passed. This checks submission readiness; it does not constitute a native purchase test.

Created review submission `0a1bebdd-62b1-44eb-b68f-5c49e6d7fe27` (HTTP 201), attached version `3c465207-2215-4f32-9637-8eb57213e9f9` through item `MGExYmViZGQtNjJiMS00NGViLWI2OGYtNWM0OWU2ZDdmZTI3fDZ8ODkyMjAyNzI1` (HTTP 201), and submitted it (HTTP 200) at **11:15:50 UTC / 15:15:50 Dubai**. Both submission and version read back WAITING_FOR_REVIEW, with AFTER_APPROVAL retained. Build 20 and canceled build 21 were never selected for this version.

TestFlight is separate: build 22 is IN_BETA_TESTING internally and WAITING_FOR_BETA_REVIEW externally. Public App Review submission succeeded independently of that beta review.

### Google Play

After CI publishing, the direct release-lifecycle API confirmed production artifact 22 was DRAFT and old artifact 20 PUBLISHED. A temporary read-only edit `06208943402035947858` confirmed uploaded bundle 22 and saved the pre-update English listing; it was deleted with HTTP 204 and never committed before the release owner began the publishing edit.

The release owner then updated only the English full description to [play-listing-1.3.0.md](play-listing-1.3.0.md), preserving title, short description and video, and supplied the corrected release notes. Production build 22 was configured as completed/full rollout after approval. Validation and commit returned HTTP 200; commit edit `05106256535054388936` used `changesInReviewBehavior=ERROR_IF_IN_REVIEW` to protect unrelated review work. The direct lifecycle readback around 11:16 UTC confirmed artifact 22 RELEASE_LIFECYCLE_STATE_IN_REVIEW and artifact 20 RELEASE_LIFECYCLE_STATE_PUBLISHED. A fresh post-commit read-only edit then read the committed English listing and production track; both deeply equaled the intended saved responses, and that edit was deleted without commit. Artifact 22 remained IN_REVIEW. The track's completed configuration does not mean public availability while review remains pending.

### Remaining evidence boundary

Genuine native sandbox purchase, restore, renewal, refund and monthly/yearly crossgrade exercises remain unperformed. Automated billing tests, authenticated invalid-proof probes and store metadata checks do not replace those scenarios. Review approval, public rollout, native listening quality and resulting conversion gains are not established by this release record. No new recurring monitor was configured.
