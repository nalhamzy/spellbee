# SpellBee conversion and live-store audit — 2026-09-29

Initial read-only audit of `com.idealai.spellbee`, repository baseline `52d5fe1`, version `1.2.0+20`, followed by the narrow authorized store corrections recorded at the end. Live authenticated reads used App Store Connect, Android Publisher and Codemagic. Prices, releases and purchases were not changed. An empty Google Play edit was created solely to read the production track, then deleted (HTTP 204), never committed. No Flutter commands were run. Credentials remained private; this report contains no purchase tokens, private keys or signed artifact URLs.

## Decision

The evidence does **not** support blaming missing store SKUs or an unfinished rollout for low paid adoption. Both stores have the three expected products, and build 20 is released. Keep prices stable while improving the parent-facing reason to buy and verifying the real purchase path. Downloads without matched paywall exposure, checkout and completed-purchase denominators cannot establish which conversion step is weak.

One concrete store configuration problem was found and corrected: Apple monthly and yearly products provide the same Premium service but were ranked at different subscription levels. Both now have level 1. The misleading Play paid benefit “No ads in lessons” was also removed from both subscriptions. Execution and readback evidence appear at the end.

## Verified deployment state

| App | Version | Platform | Codemagic | Publishing | Store state | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| SpellBee | 1.2.0 (20) | iOS | Finished | Uploaded | `READY_FOR_SALE` / `READY_FOR_DISTRIBUTION` | Selected build is `VALID`; release type `AFTER_APPROVAL`; public US listing shows Sep 13 release |
| SpellBee | 1.2.0 (20) | Android | Finished | Accepted | Production release `completed`, versionCode `20` | The old 10% staged snapshot is obsolete; current track returns only completed build 20 |

App Store app ID: `6768096917`; version ID: `8743ec5c-f77c-46b3-ba37-472c3f278b1c`; build ID: `657b2d46-a520-4a9a-a645-8ecd2d73848f`. Build uploaded September 12, 2026 at 21:51:27 UTC. [Public US listing](https://apps.apple.com/us/app/spellbee-spelling-bee-tutor/id6768096917) independently shows version 1.2.0 and updated school-list/daily-practice copy. Its US ratings overview still says insufficient ratings; that is not a global rating count.

Codemagic app ID: `6a0149db40945cde4d9e7896`. Release build `6aa5c743c12cd81c2bdf6a78` used `release-both`, finished September 12 at 21:51:27 UTC. Repository YAML also supplies `ios-release` and `android-release`, Flutter 3.41.1. Live app variable groups are `google_play`, `spellbee_secrets`, `ios_signing`; secure variable names returned include `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS`, `CERTIFICATE_PRIVATE_KEY`, `TTS_GATEWAY_TOKEN`. The current app metadata's `fileWorkflowIds` list is empty even though the historical build confirms the YAML workflow; inspect selected branch/YAML before a new trigger rather than treating that field as a missing-workflow blocker.

## Live purchase truth

| Product ID | Apple record / state | Play plan or option / state | Verified US price |
| --- | --- | --- | --- |
| `spellbee_premium_monthly` | `6768097174`, `APPROVED`, one month | Base plan `monthly`, `ACTIVE`, P1M, auto-renewing, legacy-compatible | $4.99/month on both |
| `spellbee_premium_yearly` | `6768097411`, `APPROVED`, one year | Base plan `yearly`, `ACTIVE`, P1Y, auto-renewing, legacy-compatible | $29.99/year on both |
| `spellbee_premium_lifetime` | `6768097372`, `APPROVED`, non-consumable | Purchase option `lifetime`, `ACTIVE`, buy option, legacy-compatible | $49.99 once on both |

Apple prices were read from subscription price schedules including their price points and the lifetime manual-price schedule, not inferred from app constants. Apple subscriptions are available in 175 territories including USA and enable availability in new territories. Lifetime availability also enables new territories. Family Sharing is false for all three Apple products; do not claim household sharing across Apple IDs.

Play regional examples for monthly / yearly / lifetime respectively: UAE AED18.99 / AED114.99 / AED194.99; UK GBP4.49 / GBP26.99 / GBP44.99; Oman USD4.99 / USD29.99 / USD49.99. These regions permit new subscribers/purchases. Display the actual localized native store price in-app rather than hardcoding these examples.

Play monthly grace period is P7D; yearly P14D; both allow resubscription. No Apple introductory offers were returned for either subscription. Play offer-list reads for each corresponding base plan returned HTTP 204 with an empty body, so no configured offer was returned. Do not advertise a free trial on this evidence. A grace period is not a trial.

Apple subscription group `22079579` initially assigned monthly `groupLevel: 1`, yearly `groupLevel: 2`; the authorized correction now places both at level 1. Apple documents that equal content with different durations can share a level. See [Apple subscription levels](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/). Sandbox crossgrade behavior still needs validation.

The initial live Play subscription benefit text included “No ads in lessons.” SpellBee is ad-free for everyone, so presenting that as a paid differentiator was potentially confusing; this exact benefit has now been removed. All other copy remains unchanged. Product listing responses contained English localization only; do not claim localized Arabic store purchase metadata from this audit.

## Important operational boundaries

Active products prove configuration, not a successful purchase on a real device. The prior release report explicitly lacks genuine sandbox buy/renew/refund testing. Before treating billing as cleared, test native product retrieval, checkout, pending/Ask to Buy, cancellation, server verification, entitlement persistence, restore after reinstall, renewal/expiry and refund on both platforms. Existing fixture tests and invalid-token probes are valuable but do not replace that path.

The Codemagic app variables returned no word-generator URL/token. The generator's documented implementation uses local catalog fallback without a remote endpoint; TTS has a default Firebase endpoint. Therefore, do not pitch remote AI generation as a verified shipped capability without confirming actual build configuration and exercising it. Repository changes underway in the main task must be assessed separately from this baseline audit.

Apple's price-point response gives standard proceeds of $3.50 monthly, $21.00 yearly and $35.00 lifetime, with subscription year-two proceeds $4.24 / $25.49. These are catalog price-point values, not this account's financial settlement or proof of Small Business Program enrollment. Unit economics should not assume a 15% fee without settlement/program verification.

## Acquisition and revenue evidence — limits are explicit

- The historical September 13 Play Console snapshot recorded 171 device acquisitions, 113 first opens and 145 monthly active devices in its preceding 28-day window; installed audience 123. These are historical, different measures and not a present paid-conversion cohort.
- App Store Connect `apps/6768096917/analyticsReportRequests` returned an empty data list. No existing Analytics API feed was available to read; this audit did not create a report request.
- A current Sales and Trends vendor number/report configuration was not found in the inspected operational configuration. No current sales totals were retrieved through the API in the initial pass. A subsequent signed-in Play Console read provided the aggregate revenue and cart evidence below; Apple totals remain unavailable. This is an evidence gap, not zero revenue.
- A bounded Cloud Logging read for verification-request aggregates in September 22–28 UTC returned HTTP 403 `PERMISSION_DENIED`. No request counts or failure rate can be inferred from that denial, and no broader permission was requested.
- No matched acquisition-to-paywall-to-purchase event dataset was retrieved. The subsequent Play Console read below supplies a small store-cart sample; it does not establish install-to-paid conversion, retention or causal revenue impact.

Next evidence collection should use one explicit window and platform/country breakdown: store acquisitions/first downloads, app first opens, parent paywall views, returned/missing products, checkout attempts, cancellations/errors, verified successful purchases and restores. Distinguish purchase events from unique payers and new subscriptions from renewals. In this child-focused product, prefer aggregated parent/billing events without school words, audio or learner identifiers; coordinate any new collection with existing privacy disclosures.

## Bounded competitor check

- [Squeebles Spelling Connect](https://keystagefun.co.uk/spconnect/pricing/) advertises family access for up to four children at GBP2.99/month or GBP29.99/year with a seven-day trial. Its subscription rationale emphasizes connected homework/progress and custom recordings. SpellBee's current UK monthly price is higher, but annual price lower; differences in features, currencies and taxes prevent a simplistic “too expensive” conclusion. SpellBee should prove faster local school-list setup and clear recall feedback rather than imitate cloud-family promises it does not ship.
- [Scripps Word Club](https://spellingbee.com/word-club/) is free and offers official competition vocabulary, multiple practice modes and progress. “More words” alone is a weak paid distinction against a credible free alternative.
- [SpellCamp pricing](https://spellcamp.com/pricing) currently announces it is no longer accepting new subscriptions and existing accounts retain free access. Legacy $49/year and $4.99/month cards remain on the page; do not reuse the May report's older $39/year as an active competitor benchmark.

These are current positioning observations, not competitor revenue or efficacy evidence. Recommended first experiment: explain the parent benefit at a natural high-intent moment, show a clear annual offer plus a sensible lifetime alternative, retain a genuine free success, and measure the full purchase path before changing prices.

## API/tooling notes for the release owner

Existing credential locations can be reused privately: `C:/Users/PC/.idealai/shipper.env` for ASC key metadata, key path, Play service-account path and Codemagic token; existing secret vault `C:/Users/PC/Documents/studio-secrets/`. Do not print values or embed them in reports, scripts or commits.

Reusable status scripts: `C:/Users/PC/.codex/skills/studio-release-velocity/scripts/asc-beta-status.py` and `C:/Users/PC/.codex/skills/studio-release-velocity/scripts/codemagic-build-status.ps1`. They cover build/beta status, not the full conversion audit. This audit used in-memory Python requests with existing JWT/service-account libraries, rather than persisting a secret-bearing helper.

Useful read endpoints:

- ASC `/v1/apps?filter[bundleId]=com.idealai.spellbee`, `/v1/apps/{app}/appStoreVersions?include=build`, `/v1/apps/{app}/subscriptionGroups`, `/v1/subscriptionGroups/{group}/subscriptions`, subscription prices/introductoryOffers/subscriptionAvailability, and `/v2/inAppPurchases/{id}/iapPriceSchedule`.
- Play `/androidpublisher/v3/applications/com.idealai.spellbee/subscriptions` and `/oneTimeProducts`; inspect base-plan/purchase-option state and regional availability. The legacy `/inappproducts` endpoint returns 403 with migration-required guidance; this is not evidence that products are missing. [Subscription list reference](https://developers.google.com/android-publisher/api-ref/rest/v3/monetization.subscriptions/list), [one-time product resource](https://developers.google.com/android-publisher/api-ref/rest/v3/monetization.onetimeproducts), [offer list reference](https://developers.google.com/android-publisher/api-ref/rest/v3/monetization.subscriptions.basePlans.offers/list).
- Play production-track read requires an edit; create an empty edit, read `/edits/{edit}/tracks/production`, delete in `finally`, and never commit during an audit.
- Codemagic GET `/apps/6a0149db40945cde4d9e7896` and `/builds/6aa5c743c12cd81c2bdf6a78`; select safe field names before emitting output because responses may contain secrets or expiring artifact URLs.

Historical source documents: `docs/release-1.2.0.md`, `docs/purchase-verification.md`, `docs/purchase-release-checklist.md`, `docs/growth-review-2026-09-12.md`. Their dated in-review/10%-rollout states should not be mistaken for the current verified states above.


## Follow-up: live Play aggregate evidence

Read in a dedicated signed-in Play Console tab on September 29, 2026; no orders, customer identities, purchase tokens or individual records were opened. App console ID `4976434491565259586`. Apple browser reached its login page, so this audit did not obtain Apple Sales and Trends UI data or request new reporting permissions.

| Source and coverage | Observed aggregate | Meaning and limit |
| --- | --- | --- |
| Play app dashboard, “Last 28 days”, read Sep 29 | 241 device acquisitions (+73%); 164 device first opens (+46%); 252 monthly active devices (+112%) | Comparison is console's previous 28 days. These are different measures; no install-to-paid denominator is implied. |
| Play app list / statistics | Installed audience 230; statistics latest populated installed-audience row Sep 23 | A stock, not new acquisitions or all-time downloads. |
| Play Revenue, **Aug 28–Sep 26, 2026 UTC**, all products/countries | **1 order**, `spellbee_premium_yearly` / base plan `yearly`; **0 refunds**, 0 partial refunds; **USD29.99 gross revenue** | Console labels revenue estimated sales including tax. It is not developer net proceeds, necessarily a new subscriber, or a unique-payer cohort. No lifetime order appears in this period. |
| Play Buyer conversion, **Last 28 days**, all countries/all products; data through **Sep 23, 2026**, timezone **PST8PDT** | **4 purchase attempts, 100% cancelled purchase attempts, 0 successful purchases; cart conversion 0%; network health 100%** | This is a real but tiny store-cart sample. It points to checkout abandonment within that sample, not a proven price or billing-defect cause. The different dates/timezone/coverage explain why it cannot be directly reconciled with the separate revenue row. |
| Play Buyer conversion highlights | Top converting products/countries and buyer ARPPU unavailable | Do not replace unavailable values with zero or infer stable country effects from four attempts. |

The public-release panel also confirms **100% rollout**, released **Sep 17, 2026**, with no unpublished changes. The latest-release adoption panel reports 163 installs and 74.4% install base; this is release adoption, not total app acquisition.

An attempt to align Statistics with Aug 28–Sep 26 selected the exact date range and the **New user acquisitions** measure, but the populated daily table ran only through Sep 23 and omitted some days. Therefore no sum or purported matched conversion ratio was reported. For repeatable comparisons, export aggregate reports only once both datasets cover the intended complete dates, use their respective UTC/PST8PDT definitions explicitly, and distinguish new-user acquisition from transaction counts. Buyer-cohort data or app parent-paywall telemetry is needed to attribute purchases to newly acquired users.

Console links, requiring the existing account:

- [Revenue](https://play.google.com/console/u/0/developers/9081403040134739955/app/4976434491565259586/reporting/finance/revenue)
- [Buyer conversion](https://play.google.com/console/u/0/developers/9081403040134739955/app/4976434491565259586/reporting/finance/buyer-conversion?tab=0)
- [Dashboard](https://play.google.com/console/u/0/developers/9081403040134739955/app/4976434491565259586/app-dashboard)

No raw financial export was persisted. The facts above came from visible aggregate table rows and report labels, not browser hidden state or private network replay.

## Store correction request preparation

### Apple: equal service level for yearly and monthly

Precondition: GET both subscriptions and confirm product IDs, shared group `22079579`, and identical Premium entitlement. At initial inspection monthly was level 1 and yearly level 2. This exact request was subsequently executed and verified, as recorded below:

```http
PATCH https://api.appstoreconnect.apple.com/v1/subscriptions/6768097411
Content-Type: application/json
Authorization: Bearer <runtime ASC JWT>
```

```json
{
  "data": {
    "type": "subscriptions",
    "id": "6768097411",
    "attributes": { "groupLevel": 1 }
  }
}
```

Read back both subscriptions and verify both now have `groupLevel: 1`; verify their product IDs, periods, prices, availability and Family Sharing remain unchanged. Apple's public update-request schema includes an optional integer `groupLevel`; metadata changes can take up to an hour to appear in sandbox. This changes switch classification, so test monthly↔yearly crossgrades. It does not itself repair Android subscription replacement behavior.

References: [Modify a subscription](https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-subscriptions-_id_), [update attributes schema](https://developer.apple.com/documentation/appstoreconnectapi/subscriptionupdaterequest/data-data.dictionary/attributes-data.dictionary), [subscription levels](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/).

### Play: benefits that match the new release

The following **release-dependent** copy is prepared for the new Bee Adventures build. Do not publish it while customers can only obtain the older build. New “Bee Adventures” claims require a verified purchasable release. No trial or ad-removal claim is included, and local word packs are not represented as a paid-only feature.

For each product, first GET the live resource and retain every existing localization; change only the `en-US` listing. The current live resources have one `en-US` listing. Use `updateMask=listings` and `allowMissing=false`; never use a wildcard mask or include base plans/prices in this metadata-only update. `regionsVersion.version=2026/01` is the current region revision observed in this audit; reread the applicable current version before execution if the API requires a newer one.

```http
PATCH https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.idealai.spellbee/subscriptions/spellbee_premium_monthly?updateMask=listings&allowMissing=false&regionsVersion.version=2026%2F01
Authorization: Bearer <runtime Android Publisher access token>
Content-Type: application/json
```

```json
{
  "packageName": "com.idealai.spellbee",
  "productId": "spellbee_premium_monthly",
  "listings": [{
    "languageCode": "en-US",
    "title": "SpellBee Premium Monthly",
    "description": "Bee Adventures, unlimited custom lists, studio voice, and Math Bee.",
    "benefits": [
      "All three Bee Adventures",
      "Unlimited custom lists",
      "Studio voice",
      "Unlimited Math Bee"
    ]
  }]
}
```

For yearly, use the identical endpoint pattern with `spellbee_premium_yearly` and this body:

```json
{
  "packageName": "com.idealai.spellbee",
  "productId": "spellbee_premium_yearly",
  "listings": [{
    "languageCode": "en-US",
    "title": "SpellBee Premium Yearly",
    "description": "A year of Bee Adventures, unlimited custom lists, studio voice, and Math Bee.",
    "benefits": [
      "All three Bee Adventures",
      "Unlimited custom lists",
      "Studio voice",
      "Unlimited Math Bee"
    ]
  }]
}
```

The immediate truthful cleanup was authorized and executed before release readiness: remove the exact existing `No ads in lessons` benefit and preserve all other listing fields. The new Adventure benefit remains unexecuted. After each patch, the entire GET product resource was compared with the expected result; only the intended benefit removal differed. These monetization-resource patches apply directly and do not use a Play edit/commit.

The exact route, query parameter names (`updateMask`, `regionsVersion.version`, `allowMissing`) and PATCH verb were confirmed against Google's live v3 Discovery document and [subscription patch reference](https://developers.google.com/android-publisher/api-ref/rest/v3/monetization.subscriptions/patch). The release-dependent Adventure request bodies above remain proposals, not executed or API-validated requests.

## Release trigger preparation

The latest three Codemagic builds were read; build 20 remains latest. Its source was `main`, tag `v1.2.0-build20`, commit `95b33dc2b75bc6f21abfba306ec4f7af62245b5b`; every action, including Publishing, succeeded. Repository is `https://github.com/nalhamzy/spellbee.git`.

Preferred path: finish local checks, choose a new version/build, commit the intended files, push that commit and one unique `v*` release tag. The YAML tag trigger starts `release-both`. Check the build list before manually triggering so the same tag is not built twice. If no automatic build appears, an explicit API trigger is:

```http
POST https://api.codemagic.io/builds
Content-Type: application/json
x-auth-token: <runtime Codemagic token>
```

```json
{
  "appId": "6a0149db40945cde4d9e7896",
  "workflowId": "release-both",
  "tag": "<new immutable release tag after version bump>"
}
```

The placeholder is intentionally not a stale executable build-20 tag. Pass either `tag` or `branch`, with tag preferred for reproducibility. Do not override environment groups or token values in the request: the existing YAML imports verified app groups. The [Codemagic Builds API documentation](https://docs.codemagic.io/rest-api/builds/) explicitly explains that API app metadata may omit YAML workflow IDs until clone time; the empty `fileWorkflowIds` list is therefore not itself a blocker. A build API call does not obey YAML trigger filters; verify the exact requested tag.

Use the existing status helper, then inspect any failed action's log with secret-safe filtering. Success means artifact upload only: YAML sets `submit_to_app_store: false` and Play `submit_as_draft: true`. Apple public-version selection/review submission and Google review/production release remain separate steps, followed by store readback. Root owns those authorized deployment actions. No builds were started by this audit; only the corrections below were applied.

## Authorized correction execution — September 29, 2026

The authorized scope was limited to equal Apple subscription levels and removal of the misleading existing Play ad-removal benefit. No SKU, pricing, availability, release, trial, entitlement code or Adventure claims were changed by these requests. No purchases or CI triggers were performed.

Apple preflight confirmed that subscription group `22079579` contains the expected monthly/yearly products, both approved. `lib/core/constants/iap_ids.dart` and `lib/core/models/premium_state.dart` confirm that both recognized subscriptions grant the same `isPremium` entitlement; duration differs, service level does not. PATCH of yearly `6768097411` returned HTTP 200. Readback completed at **10:39:51 UTC**: yearly `groupLevel` changed **2 → 1**, monthly remained **1**. Comparing the complete before/after subscription resources found precisely the authorized yearly attribute change and no monthly change. Separate US price schedules/price points, availability resources, and complete territory lists were equal before and after. Family Sharing, product IDs, periods and approved states remained unchanged. This verifies metadata, not a real sandbox monthly↔yearly crossgrade.

Play monthly and yearly subscription PATCH requests each returned HTTP 200; readbacks completed at **10:40:13 UTC** and **10:40:15 UTC**, respectively. Each request used `updateMask=listings`, `allowMissing=false`, `regionsVersion.version=2026/01`, and a copy of the live listings with only the exact `No ads in lessons` value removed. Both products now expose these three existing English benefits:

- `Unlimited word packs`
- `Unlimited custom lists`
- `Studio voice`

For each subscription, the complete after-GET JSON equaled the complete before-GET JSON with that single benefit removed. All other listing fields/localizations, active base plans, region configuration, prices, periods, grace periods and resubscription settings were preserved. Neither the lifetime product nor other store resources were patched. The remaining benefit text has intentionally not been rewritten as part of this narrow correction. Adventure copy remains dependent on the new purchasable release.
