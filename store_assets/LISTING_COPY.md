# SpellBee — Store listing copy

SEO-tuned for the spelling-bee / student-education niche. Every field under its
platform limit.

---

## Apple App Store Connect

### App Name (30 char — primary SEO)
```
SpellBee: Spelling Bee Tutor
```
**28 chars.** Removes "Kids" for App Review 2.3.8 while keeping spelling-bee SEO. Use this in ASC.

### Subtitle (30 char)
```
Practice with voice & word packs
```
**30 chars exactly.** Hits "practice", "voice", "AI".

### Keywords (100 char — comma-separated, no spaces, singular)
```
spelling,word,dictation,phonics,vocabulary,bee,test,practice,tutor,homework,student,school,parent
```
**97 chars.** Avoids title/subtitle words ("spellbee", "voice", "AI") —
Apple auto-indexes those.

### Promotional Text (170 chars)
```
Bee-ready spelling practice. Clear voice prompts read every word, with type-or-speak practice, parent-curated lists, and themed packs by grade level.
```
**163 chars.**

### Description (4000 chars)
```
SpellBee is the fastest way to get spelling-bee ready. Pick a grade level, hit start, and the pronouncer does the rest — reading each word aloud, offering the definition, and using it in a sentence on request, just like a real bee.

Built by a spelling-bee parent who was tired of drill apps that feel like worksheets.

TWO WAYS TO PRACTICE

• TYPE — See the prompt, type the word, check instantly. Misses trigger a clear spell-out so you hear every letter.
• SPELL ALOUD — Tap the mic and say each letter. SpellBee understands letter names ("see a tee" → CAT) and whole words, so there's no typing between attempts.

EIGHT DIFFICULTY LEVELS
From K-1 starter words to championship-tier stumpers like "pneumonoultramicroscopicsilicovolcanoconiosis". Every word ships with a definition and an example sentence so the context lands.

THEMED WORD PACKS
Give SpellBee a theme — dinosaurs, space, baking, cooking, mythology — and it builds a fresh 10-word pack at your level. Built-in themed packs work offline, with a studio gateway available for expanded packs when configured.

PARENT-MADE LISTS
Copy this week's school words into a saved list. Tap "practice" and the same words read aloud with optional definitions you wrote yourself. Great for weekly spelling tests, pre-bee warm-ups, and ESL families who want their own word set.

INSTANT FEEDBACK + STREAKS
Every test tracks correct words, longest streak, and accuracy. Perfect tests extend your perfect-test streak.

WHO IT'S FOR
• Elementary students prepping for weekly spelling tests
• Learners training for school or regional spelling bees
• Homeschool families
• ESL learners building vocabulary
• Anyone rebuilding a reading habit

PRIVACY
All lists, stats, and purchases live on your device. No account. No cloud sync. Nothing sold. Mic audio is processed by your device's built-in speech recognizer — never uploaded.

PREMIUM
Unlock everything for less than one coffee a month:
• Unlimited themed word packs — no daily cap
• Unlimited parent-made word lists (free tier: 3)
• Enhanced voice pronunciation

Monthly, yearly (save 44%), or a one-time lifetime. Cancel any time.

Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://nalhamzy.github.io/spellbee/privacy.html

Free to start. Premium when your practice routine is ready.
```

### What's New in This Version (v1.0.13)
```
SpellBee is now 100% ad-free — no banners, no videos, just spelling.

• Removed all ads from the app, for everyone
• Simpler voice settings with a single high-quality studio voice
• Leaner app: fewer permissions and a smaller download
• Polish and fixes across practice, settings, and the premium screen
```

### What's New archive (v1.0.0)
```
Initial release.

• 8 difficulty levels, K-1 to championship-tier
• Voice pronunciation + sentence + definition
• Type or spell-aloud modes (speech-to-text)
• Themed word packs by grade level
• Parent-curated custom lists
• Premium: unlimited themed word packs and parent-made lists
```

### Support URL
```
https://github.com/nalhamzy/spellbee
```

### Privacy Policy URL
```
https://nalhamzy.github.io/spellbee/privacy.html
```

### Copyright
```
2026 Ideal AI
```

### Category
- Primary: **Education**
- Secondary: **Games → Word**

### Age Rating
- **4+** (Made for Kids: **NO** — SpellBee is student-facing but parent-managed, age rated general; do not enable Kids Category contextual-ad requirement)

### App Review — Review Notes
```
SpellBee is a local-first spelling-bee practice app for students and families. All data (custom lists, stats, premium status) is stored on-device in SharedPreferences. IAPs: spellbee_premium_monthly, spellbee_premium_yearly (auto-renewing subscriptions in a shared group), spellbee_premium_lifetime (non-consumable). The paywall includes functional Privacy Policy and Terms of Use (EULA) links. The app contains no ads. No account, no login. Mic is used for optional speech-to-text input; audio is processed by the device and never uploaded.
```

---

## Apple In-App Purchases

### Product 1 — Premium Monthly
| Field | Value |
|---|---|
| Product ID | `spellbee_premium_monthly` |
| Reference Name | `SpellBee Premium (Monthly)` |
| Type | Auto-Renewable Subscription |
| Subscription Group | `spellbee_premium` |
| Duration | 1 Month |
| Price | $4.99 |
| Display Name | `Premium Monthly` |
| Description | `Unlimited themed word packs, unlimited custom lists, and studio voice. Renews monthly.` |

### Product 2 — Premium Yearly
| Field | Value |
|---|---|
| Product ID | `spellbee_premium_yearly` |
| Reference Name | `SpellBee Premium (Yearly)` |
| Type | Auto-Renewable Subscription |
| Subscription Group | `spellbee_premium` (same group as monthly) |
| Duration | 1 Year |
| Price | $29.99 (save 50% vs monthly) |
| Display Name | `Premium Yearly` |
| Description | `Save 50% vs monthly. Everything in Premium, billed yearly.` |

### Product 3 — Premium Lifetime
| Field | Value |
|---|---|
| Product ID | `spellbee_premium_lifetime` |
| Reference Name | `SpellBee Premium (Lifetime)` |
| Type | Non-Consumable |
| Price | $49.99 one-time |
| Display Name | `Premium Lifetime` |
| Description | `Pay once. Keep forever. Everything in Premium with no subscription.` |

**IAP review notes (same for all three):**
```
Premium upgrade for SpellBee. To reproduce: launch app → tap "Go Premium" from Home or Settings → select this tier → confirm. Validate in sandbox with any tester account. No login or external API required.
```

Review screenshot: `store_assets/ios/05_premium.png` (1290×2796).

---

## Google Play Console

### App Name (30 char)
```
SpellBee: Spelling Bee for Kids
```

### Short Description (80 char)
```
Spelling bee practice with voice, themed word packs, and parent-made lists.
```
**72 chars.**

### Full Description (4000 char)
*Reuse the Apple description above.*

### Tags (pick up to 5)
```
Education, Word, Kids, Learning, Parenting
```

### App Category
**Education** (primary)

### Content Rating
**Everyone**

### Contact Email
```
nalhamzy@gmail.com
```

### Website
```
https://github.com/nalhamzy/spellbee
```

### Privacy Policy
```
https://nalhamzy.github.io/spellbee/privacy.html
```

### Target Audience
**Ages 6–12 AND 13+** (primary kid-age range + parent decision-makers).
Do NOT mark "Designed for Families" unless you want the contextual-ads
treatment; leaving it off gives you full ad inventory.

---

## Google Play In-App Products

### Subscription 1 — Premium Monthly
| Product ID | `spellbee_premium_monthly` |
|---|---|
| Name | `Premium Monthly` |
| Description | `Unlimited themed word packs, unlimited custom lists, and studio voice.` |
| Base plan | 1 month auto-renewing, $4.99 USD |
| Free trial | Not configured |

### Subscription 2 — Premium Yearly
| Product ID | `spellbee_premium_yearly` |
|---|---|
| Name | `Premium Yearly` |
| Description | `Save 50%. Everything in Premium, billed yearly.` |
| Base plan | 1 year auto-renewing, $29.99 USD |

### In-App Product — Lifetime
| Product ID | `spellbee_premium_lifetime` |
|---|---|
| Name | `Premium Lifetime` |
| Description | `Pay once. Keep forever.` |
| Price | $49.99 USD |
| State | Active |

---

## Screenshot captions (for overlay text, if used)

| # | Caption |
|---|---|
| 01_home | `Pick your level — K-1 to championship-tier.` |
| 02_listen | `Hear every word in a clear voice.` |
| 03_typing | `Type the word or spell it aloud.` |
| 04_correct | `Build streaks. Master the tricky ones.` |
| 05_premium | `Unlimited word packs. Studio voice. Go Premium.` |

---

## Content-rating questionnaire answers

| Question | Answer |
|---|---|
| Violence | None |
| Sexual content | None |
| Profanity | None |
| Horror | None |
| Alcohol / tobacco / drugs | None |
| Gambling | None |
| Loot boxes | No |
| User-generated content | No (custom lists are local-only) |
| Unrestricted web access | No |
| Shares user location | No |
| Targets children under 13 | **Yes** (primary audience), but NOT Kids Category on App Store (see above) |
| Digital purchases (IAPs) | Yes |
| Includes ads | No |

Expected rating: **4+ / Everyone / PEGI 3**.
