# SpellBee Monetization Study

Date: 2026-05-21

## Current Model

SpellBee currently sells three in-app products:

- Monthly Premium: `spellbee_premium_monthly`, listed in-app as $4.99/month.
- Yearly Premium: `spellbee_premium_yearly`, listed in-app as $29.99/year.
- Lifetime Premium: `spellbee_premium_lifetime`, listed in-app as $49.99 one-time.

Premium unlocks:

- Unlimited AI-generated word packs.
- Unlimited parent-made word lists.
- No ads in the learning flow.
- Studio voice pronunciation.

The free tier currently allows:

- Up to 3 custom word lists.
- 1 AI pack credit per day.
- Practice/testing against built-in and saved lists.
- Score visibility on completed lists, including last score, best accuracy, and attempts.

## Margin Reality

Assuming the studio qualifies for reduced platform fees:

| Product | Gross | Net after 15% store fee | Net after 30% store fee |
| --- | ---: | ---: | ---: |
| Monthly | $4.99 | $4.24 | $3.49 |
| Yearly | $29.99 | $25.49 | $20.99 |
| Lifetime | $49.99 | $42.49 | $34.99 |

Apple's Small Business Program offers a 15% commission for qualifying developers under the $1M proceeds threshold. Google Play applies a 15% service fee to subscriptions and to the first $1M in annual developer revenue for enrolled developers.

Sources:

- Apple: https://developer.apple.com/app-store/small-business-program/
- Google Play: https://support.google.com/googleplay/android-developer/answer/112622

## Cost Drivers

Most of SpellBee has near-zero marginal cost:

- Built-in word catalog and themed packs are local.
- Built-in word and encouragement audio assets are local.
- Device TTS fallback is local to the device.
- Custom lists and scores are stored locally.

The live cost centers are:

- Firebase function calls for studio TTS.
- OpenAI TTS usage through the Firebase gateway.
- Optional word generator gateway usage, if configured.
- Store platform fees.

Firebase Cloud Functions have a meaningful no-cost tier: 2M invocations/month, 400K GB-seconds/month, 200K CPU-seconds/month, and 5GB outbound networking/month before usage charges.

Source: https://firebase.google.com/pricing

OpenAI `gpt-4o-mini-tts` is billed by text input and audio output tokens. Current published pricing is $0.60 per 1M text input tokens and $12.00 per 1M audio output tokens.

Source: https://developers.openai.com/api/docs/models/gpt-4o-mini-tts

## App-Specific Findings

1. The model is likely profitable if most practice stays on local/bundled/device voice and if remote studio voice remains premium-only.

2. The yearly plan at $29.99 is the healthiest default. At 15% platform fee, it leaves about $25.49 before cloud costs, support, and taxes. That gives enough room for a polished education app with light AI usage.

3. The monthly plan at $4.99 is a useful anchor and trial substitute. It is less attractive for retention but gives skeptical parents a low-risk path.

4. The lifetime plan is the main margin risk. At $49.99, it nets about $42.49 at 15% fees. That is fine for mostly offline premium, but risky if it promises unlimited OpenAI-backed pronunciation for years.

5. Ads are not a real revenue line. The unused ad service and ad SDK were removed during this pass, which keeps the product subscription-first and improves the privacy posture for a children's education app.

6. The app currently activates premium locally after a purchased/restored transaction. That is acceptable for a first launch, but a subscription business eventually needs receipt validation or a service like RevenueCat for cross-device restore, expiry handling, refund/revoke handling, and fraud resistance.

7. The TTS gateway logs usage metadata, but does not enforce user entitlement, device quotas, or server-side audio caching yet. Client-side temp caching helps repeat playback on one device, but does not reduce cost across devices or reinstalls.

8. The word generator gateway is referenced by mobile build defines, but the Firebase functions package in this repo only implements `spellbeeTts`. In practice, the current word-pack experience is mostly local unless a separate gateway exists outside this repo.

## Competitor Read

Squeebles Spelling Connect is free to download with subscriptions and emphasizes deep parent/teacher workflows: thousands of prerecorded words, custom lists, own-voice recording, child accounts, assignments, full stats, tricky words, and cloud progress.

Source: https://apps.apple.com/gb/app/squeebles-spelling-connect/id1661020981

Scripps Word Club is free to download and built around official Words of the Champions content and progress tracking.

Source: https://spellingbee.com/word-club/

SpellCamp publicly prices at $4.99/month and $39/year, with custom lists, AI word suggestions, detailed progress charts, and family/classroom positioning.

Source: https://spellcamp.com/pricing

Compared with these, SpellBee's $29.99/year is reasonable and possibly underpriced if the UI polish and parent list workflow are strong. The gap is not price; the gap is proof of value: parent dashboards, tricky-word loops, school-list import speed, and retention hooks.

## Profitability Verdict

Yes, the current model can be profitable.

The profitable version is:

- Make yearly Premium the primary offer.
- Keep monthly as an accessible entry point.
- Keep free generous enough to create trust.
- Treat cloud studio voice as a premium feature with fair-use controls.
- Do not rely on ads.

The not-profitable version is:

- Unlimited lifetime cloud TTS at $49.99.
- No gateway rate limits.
- No budget alerts.
- No server-side cache.
- No entitlement validation.

## Recommendation

Keep these prices for launch except lifetime:

- Monthly: keep $4.99.
- Yearly: keep $29.99 as the default selected plan.
- Lifetime: either raise to $79.99 or keep $49.99 only if cloud studio voice is fair-use limited.

Recommended premium positioning:

- "Unlimited school word lists"
- "Clear pronunciation"
- "Scores and tricky-word practice"
- "AI help when parents need a quick list"

Recommended free tier:

- Keep 3 custom lists.
- Keep 1 AI pack/day.
- Keep scores visible after tests.
- Keep ads out of the core child flow.

Recommended next monetization work:

1. Add server-side TTS cache keyed by normalized text, voice, and speed.
2. Add App Check or signed gateway tokens.
3. Add per-device and per-entitlement TTS quotas.
4. Add OpenAI/Firebase budget alerts before broad rollout.
5. Add receipt validation before scaling paid acquisition.
6. Add a "tricky words" premium loop from missed answers, because it improves learning and strengthens the subscription value.
