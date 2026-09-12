# SpellBee product and growth review

Reviewed 12 September 2026. Repository: `b1cdd5e`, version `1.1.1+18`.

Release follow-up, 13 September 2026: school-list paste, today's practice, per-word review scheduling, independent-recall reporting, and server-verified purchases are now implemented in 1.2.0 (20). Both signed store builds succeeded. See [the release report](release-1.2.0.md) for current store submission states, native smoke evidence, and remaining validation. The review below records the original findings and longer-term roadmap; it is not a claim that all 90-day work has shipped.

## Implementation follow-up — 12 September 2026

The first purchase-reliability slice is implemented locally after this review:

- Purchase completion follows successful entitlement persistence, including checking a failed storage return value. Failed writes remain pending for redelivery/Restore.
- Transaction batches are processed sequentially; transaction IDs suppress repeated delivery/completion during the current service session. This is not server-side receipt verification or a durable transaction ledger.
- Store connection setup is shared across concurrent callers. Unrecognized products do not grant access. UI callback failures cannot break purchase processing, and the success notification no longer writes the entitlement a second time.
- The paywall displays only returned supported products, chooses an available fallback when necessary, and keeps price/disclosure/checkout selection aligned. Purchase launch and restore calls have busy/error handling. Screenshot prices cannot initiate a purchase.
- Android subscription instructions now name Google Play. Plan labels and long prices wrap on narrow screens and with enlarged text.

Validation: all 83 tests pass, including 24 new purchase/paywall regression tests. See `docs/purchase-release-checklist.md` for release verification and remaining limitations. The following review remains the historical baseline; its purchase-completion and unavailable-plan observations are addressed by this local slice, not by a deployed release.

Still pending: verified store expiry/refund/revocation, real-store sandbox checks, native pending-approval UX, privacy/data-flow corrections, grading/mastery changes, backend quotas, and the daily learning roadmap. Pricing and live store configuration were not changed.

## Recommendation

Make SpellBee the easiest way for a family to turn this week's school spelling list into a short daily routine, then see what the learner remembers independently.

The proposed promise is **“This week's spelling, one confident day at a time.”** The product loop is: add school words → complete today's short practice → revisit difficult words → demonstrate independent recall → show the parent progress → add next week's list.

This is a strategic hypothesis, not a claim about the current audience. The owner reports strong portfolio performance; private downloads, revenue, retention, geography, acquisition sources, and customer feedback were not available in this review. If competition preparation drives the strongest retained or paying cohort, give that cohort its own path and prioritize its needs accordingly. Preserve current successful entry points while testing the new routine.

## Evidence and scope

Inspected Flutter screens, state and storage, grading, voice services, purchase flow, Firebase TTS functions, tests, existing monetization notes, listing copy, and local home/paywall screenshots. Ran static analysis and the existing test suite: **no analysis issues; all 59 tests passed**. Native plugins are mocked in widget tests; these results do not establish real-device voice quality, live billing correctness, or production backend state. No physical-device usability session or private store-console audit was performed.

The retrieved [US App Store listing](https://apps.apple.com/us/app/spellbee-spelling-bee-tutor/id6768096917) showed version 1.0.13, two practice modes, insufficient ratings for an overview, and purchases at $4.99, $29.99, and $49.99. The retrieved [Google Play listing](https://play.google.com/store/apps/details?id=com.idealai.spellbee) showed older two-mode copy and a 10+ download band. These public snapshots may be stale or territory-specific; neither disproves the owner's portfolio assessment. Confirm the live release and territory in the consoles before changing store claims or interpreting these numbers.

## What is already working in the product

- Ad-free learning, no mandatory account, local lists and progress: a simple starting experience worth preserving.
- Typing, letter tiles, and spelling aloud; definitions, examples, feedback, and voice fallback.
- Eight levels, a built-in catalog with 360 `Word(...)` entries, themed packs, and parent-created lists.
- Daily word, quests, honey, ranks, badges, and celebrations already exist. “Add streaks and rewards” is not a useful next recommendation.
- Immediate missed-word retries, persistent miss counts, a focus round, and per-list last/best scores already exist. Expand them into a learning history rather than build a second system.
- A warm visual identity, a visible primary practice button, annual selected by default, localized store prices, and restore/legal links.

## Competitive implications

| Evidence | Implication for SpellBee |
| --- | --- |
| [Scripps Word Club](https://apps.apple.com/us/app/word-club-spelling-vocabulary/id1479862742) is free, supplies 4,000 official study words, and offers study/quiz modes. | A broad “bee preparation” claim faces an authoritative free alternative. Win on family workflow and personalization; retain competition practice as a distinct path. Do not imply official affiliation. |
| [Squeebles Spelling Connect](https://apps.apple.com/us/app/squeebles-spelling-connect/id1661020981) advertises 8,500+ prerecorded words, custom recordings, and cloud progress. Its US listing includes a $29.99 family purchase. | SpellBee cannot justify superiority through catalog size or low price alone. Faster list setup, clear daily guidance, and trustworthy progress are better advantages. |
| One visible Squeebles review dated February 2025 requests more variety for the learner's own weekly lists; the developer notes several modes already exist. | This is one qualitative signal, not representative research. Make the existing modes easy to discover and usable with the same school list. More modes alone may not solve perceived repetition. |
| [Doodle's January 2026 product explanation](https://help.doodlelearning.com/en/articles/2953427-teachers-how-does-doodle-work) describes a personalized daily programme and short exercises. | A guided next step is an established competitor promise. SpellBee needs a clear answer to “what should I practice today?” |
| [SpellCamp's pricing page](https://spellcamp.com/pricing) now says it is no longer accepting subscriptions and existing accounts retain free access, despite showing legacy price cards. | The May monetization study's SpellCamp price is stale as an active acquisition benchmark. Do not use it to justify a price increase. |

These are product-positioning signals, not proof of competitor profitability or evidence that a particular feature will increase SpellBee retention.

## Priority 0: protect learning trust and paid customers

Address these before materially increasing acquisition spending. They are code observations or gaps requiring verification, not measured production incident rates.

| Finding and source | Recommended action | Verification |
| --- | --- | --- |
| `iap_service.dart:120`: `_grant` completes the transaction in `finally`, including when entitlement persistence throws. | Persist a verified, recoverable entitlement before successful completion; handle failed persistence explicitly and serialize/idempotently process transaction updates. | Simulate persistence failure, redelivery, duplicate updates, and interrupted purchases. The customer must recover access without paying again. |
| `premium_state.dart:17` and `main.dart:55`: subscription validity is a 35/370-day local window reset from the time a purchase/restore event is handled. | Use verified store expiry, renewal, refund/revocation and grace-period state, with a documented offline cache. A restored event is not a substitute for the actual expiry date. | Sandbox renewal, cancellation without immediate expiry, refund/revoke, reinstall/restore, pending approval, and offline behavior on both stores. |
| `paywall_screen.dart:78,295`: any returned product enables the CTA, while all three plans remain selectable, including a missing default yearly plan shown as a dash. | Only allow returned products to be selected; choose an available default; model pending, success, cancellation and restore completion clearly. | Return monthly only, lifetime only, no products, then recover; never start a purchase for an undisplayed price. |
| `test_screen.dart:639,666`: final correctness feeds score/perfect results, while `missedOnce` separately records struggle. | Distinguish first-attempt unassisted accuracy from eventual practice completion. Keep encouraging retry success, but do not represent it as independent mastery. | A wrong answer followed by a correct retry must remain distinguishable in results and parent reports. |
| `stt_service.dart:82`: recognition does not select an English locale or request on-device-only recognition. Public copy says microphone audio is never uploaded. | Select the supported practice locale; offer visible/editable recognition results and easy typing fallback. Verify data flow and correct absolute privacy claims. | Test English spelling on phones whose system language is Arabic, multiple accents, denied mic permission, silence, background/resume, offline, and noisy rooms. |
| `functions/index.js:26,332`: quotas exist, but legacy tokenless access is enabled, quota reads/increments are separate operations, and metering failures allow requests. | Add verified entitlement/app attestation, transactional quotas and shared caching for approved stock content. Separate operator authorization from a token distributed in clients. Preserve an upgrade path for existing paying builds. | Concurrent and unauthorized requests cannot evade budget policy; metering outage behavior is explicit; paying users receive a clear fallback. Avoid globally caching private custom-list text. |

The [speech_to_text documentation](https://pub.dev/packages/speech_to_text) explicitly notes that recognition may use remote services. “System recognizer” is not equivalent to “never uploaded.” Review speech recognition, premium text synthesis, usage logs, and store privacy declarations together.

The local listing guide also contains obsolete advice about leaving family settings off for ad inventory. Remove that guidance in the next metadata pass: [Google's Families policy](https://support.google.com/googleplay/android-developer/answer/9893335) applies when children are a target audience. The existing parent PIN storage has no corresponding gate wired into screens. Design a real adult area for purchases, external links, and family controls; assess any Kids Category changes against [Apple's requirements](https://developer.apple.com/app-store/review/guidelines/). Do not treat a parental gate as consent to collect children's data.

## Priority 1: build the daily mastery routine

### 1. Make a new learner's first success easy

Today the app opens directly to Home and defaults to level 3 (`storage_service.dart:96`). A new early reader can start at the wrong level before discovering the level picker further down the page.

Offer a brief, skippable choice: school list, general spelling, or bee preparation; then grade/comfort level and preferred input. Start with five suitable words and allow immediate adjustment. Existing users keep their saved level and lists. Replace “Start level 3 trial” with “Start practice” or “Today's practice”; “trial” can be mistaken for a subscription offer.

Acceptance: a new parent reaches an appropriate first round in under a minute in observed usability sessions; no account, paywall, or mic permission is required for typing practice.

### 2. Add school words quickly

The editor currently adds one word at a time (`word_list_editor_screen.dart:45`). Ship bulk paste first: accept line/comma-separated words, deduplicate, preview, edit, then save and start. Preserve deliberate spaces/hyphens and spelling variants. Add a test date and a “current school list” designation.

Follow with photo import only after validating demand. Prefer on-device recognition, require parent review of extracted words, and do not silently retain/upload worksheets containing pupil information. Retain manual entry as fallback. A checked ten-word list should be ready for practice in roughly a minute; this is a usability target, not a current capability.

### 3. Turn miss counts into a review schedule

The current focus system increments/decrements miss counts and ranks the top eight; it does not schedule future reviews (`providers.dart:433`, `stats_screen.dart:134`). Add per-learner/per-word records: original word context, first-attempt accuracy, hints/retries, input mode, last independent success, next review date, and source list.

Start with a transparent rule: review a difficult word later, then on another day, extending the interval after independent success. The exact intervals are an experiment. Do not backfill historical mastery from aggregate scores. Preserve custom definitions/examples: the current Stats lookup checks the built-in catalog, so custom contexts can be replaced with generic text.

Use today's list plus due reviews for a short session, preserving open practice. Report “remembered on separate days” as an observable event; do not imply that one successful retry establishes durable learning. Add small, educator-reviewed pattern explanations for common mistakes rather than relying on unconstrained generated explanations.

### 4. Show parents what changed

Create a parent summary with “practiced,” “needs another review,” and “recalled independently on separate days,” plus first-attempt performance for this week's list. Keep basic progress free. A weekly report should show a transparent denominator and assessment conditions, not a predictive claim about a future school grade.

Add separate local learner profiles before claiming individualized family progress. Migrate the existing single-user history into one default profile. Offer local backup/export early; evaluate optional parent-controlled sync after that. Today's single-device storage makes a reinstall/device change a potential loss of learning history.

## Priority 2: make the experience memorable and accessible

Keep the honey palette and bee identity. In the inspected screenshots, large daily-word and quest cards dominate Home, while school-list selection and parent information appear lower. Put today's routine and current list first, followed by a compact reward summary; group exploration below. Give parents a clearly labeled destination instead of an ambiguous “You” tab.

Make the bee a recurring coach with brief, helpful reactions. Let already-earned honey unlock a small set of garden/hive decorations. Reward returning and attempting difficult words, with flexible weekly practice goals and a welcoming return after missed days. Ship a small collection before expanding content production.

Prioritize large text, strong contrast on secondary/legal links, accessible tile labels, reduced motion, adjustable auto-advance, and replay controls. The current answer advance is timed at about 1.8 or 3.2 seconds (`test_screen.dart:512`); some learners need longer. Measure actual voice response time and success across target devices before claiming superior pronunciation.

Keep Number Bee and Math Bee available as supporting activities, but give spelling mastery the main roadmap allocation. Defer public leaderboards, chat, a broad subjects platform, and a large AI tutor until the core routine retains families.

## Monetization

Keep the present US monthly/yearly prices as the initial control. Price alone is not an established problem. Annual is already selected by default; the improvement is communicating recurring parent value and ensuring access is reliable.

Suggested future premium message, only once those features ship: **“Make school spelling easier for the whole family.”** Lead with quick weekly-list setup, individual learner progress, and convenient family tools. Studio voice supports the promise; implementation terms such as “gateway” or “simple store checkout” are not buyer benefits.

Keep basic practice, pronunciation, missed-word review, saved-list access and basic results useful for free. Present upgrades in the adult workflow at a genuine limit or a clearly explained advanced family feature. Do not re-lock existing paid benefits.

The $49.99 lifetime price is approximately 1.67 times the $29.99 annual price before fees. That is a reason to inspect renewal expectations and service cost, not proof lifetime is unprofitable. Measure margin and plan mix first; consider a higher price or explicitly scoped offer for new buyers later. Preserve promises made to existing buyers. Do not advertise a free trial unless it exists in the relevant store and the customer is eligible.

## Acquisition and store conversion

1. Verify which builds and assets are actually public in the main markets. Reconcile the two-mode descriptions with the newer three-mode build; correct whole-word grading claims, inconsistent savings, premium-only ad-free wording, and engineering copy. At the listed US prices, yearly is about 50% less than twelve monthly payments, not 44%; use storefront-aware comparisons.
2. Test a parent-outcome message against the existing bee-preparation message. A candidate subtitle is “School lists. Daily practice.” Preserve the SpellBee brand and successful keywords until the acquisition data supports a change.
3. Lead screenshots with the real learning workflow: school list → hear and spell → practice difficult words → parent-visible progress → enjoyable routine. Only show functionality available in that released build. Rework the sequence after the daily routine ships.
4. Add a parent-facing product/support page with real demonstrations, store links, purchase/restore help, and an accurate privacy explanation. The repository README is still the Flutter starter text.
5. Use a neutral, occasional native review request after meaningful use in the parent area. Do not reward reviews, demand five stars, or screen unhappy users out of the review path. Keep support accessible independently.
6. Pilot with 10–15 consenting families and a small tutor group. Observe list entry, the learner's first round, an error, and next-day return. Ask what the app replaced and why they would stop using it. These are proposed studies; no customers were contacted.
7. Test short adult-targeted demonstrations around school-list setup and independent practice. Start with existing audiences and relevant portfolio parent surfaces. Track install-to-activation and retained use, not video views alone. Add parent-controlled list sharing only once import/export works reliably.
8. Expand paid acquisition after verified paid access and retention evidence. Set spend limits from realized net revenue minus service/support costs; do not assume annual renewals in early lifetime-value calculations.

English remains the learning content language initially. If Gulf families are a meaningful cohort, test Arabic parent onboarding, support, and store copy, with proper RTL layouts while retaining English spelling exercises. Also verify US/UK vocabulary and pronunciation preferences. A full Arabic spelling curriculum is a separate content product and should follow demand evidence.

## Measurement and decision rules

There is no product analytics instrumentation visible in the current client dependencies/source. Local cumulative stats and TTS usage logs cannot explain install-to-paid conversion or retention. Begin with existing store acquisition, sales, renewal/refund and crash reports; then implement minimal, age-appropriate measurement with accurate disclosures and any required consent. Do not export microphone recordings, worksheet images, learner names, custom word contents, or advertising identifiers as analytics.

Use these definitions before setting targets:

| Metric | Definition / purpose |
| --- | --- |
| Activation | New eligible install completes its first appropriate practice round within 24 hours. Track list import as a separate milestone, not a requirement for general-practice users. |
| Week-two learning retention | Activated learners completing a practice round on at least two distinct days in days 8–14. This is a proposed internal definition, not an industry benchmark. |
| Weekly learning value | Active learners who complete at least three practice days and recall at least one previously difficult word independently on a later day. Track its rate and count. |
| Learning evidence | First-attempt unassisted recall, separated from corrected retries, tiles, hints and immediate repetitions. |
| Parent effort | Observed time from school words available to a checked list ready for practice. |
| Conversion | Verified purchasers / eligible installs and verified purchasers / unique paywall viewers, separated by platform, source, territory, and plan. |
| Revenue quality | Net revenue per install, renewal, refunds, lost-access contacts, and variable voice/backend cost. |
| Reliability | Crash-free sessions, voice start/failure/fallback rate, round abandonment, and purchase/restore outcome. |

Candidate events: first_round_started/completed, list_import_started/completed, review_due/completed, parent_summary_viewed, paywall_viewed with trigger, purchase_started/verified/failed, restore_completed, voice_failed. Keep denominators, offline delivery, deduplication and reinstall behavior explicit. If child-level longitudinal measurement cannot be collected appropriately, use store aggregates and an opt-in parent research cohort; do not claim unavailable precision.

Establish a baseline before adopting numeric growth goals. For each experiment choose one primary metric, a minimum effect worth shipping, guardrails, and a sample-size plan based on actual traffic. Run through a full school-week cycle and enough observation for the retention window; elapsed time alone does not make results conclusive. Use usability studies when traffic is too small. Change the main message, onboarding, and pricing in separate tests.

## Proposed 90-day sequence

Timing assumes one focused product/engineering stream with design and QA support. It is sequencing guidance, not a delivery commitment.

| Window | Deliverable | Release / decision condition |
| --- | --- | --- |
| Days 1–14 | Establish private performance baseline; verify live versions; correct billing edge cases and metadata/privacy inconsistencies; observe first-use sessions. | Paid-access recovery tested; clear data-flow inventory; top user cohort and key funnel definitions documented. |
| Days 15–30 | Skippable level/goal setup, bulk school-list paste, current-list selection, distinguish first attempt from completion, new primary Home action. | Existing-user progress preserved; five-word first session usable; parent setup effort improves in observed sessions. |
| Days 31–60 | Per-word history and scheduled reviews, short daily routine, parent weekly summary, local profiles and backup. | Migration tests pass; custom word context survives; repeat-day use and independent recall can be assessed honestly. |
| Days 61–90 | Refine rewards and accessibility, validate photo import demand, test store message/creative, run small tutor/family pilot and controlled acquisition. | Retention evidence and contribution economics justify further spend; do not scale just because installs rise. |

Suggested effort split: 50% daily learning and parent workflow, 25% reliability and measurement, 15% store/distribution experiments, 10% new playful content. Rebalance using actual cohort results.

The first major product release should deliver **school-list setup + today's practice + honest mastery feedback**. That connects assets already in the app into a reason to return, a reason for a parent to pay, and a benefit they can explain to another family.
