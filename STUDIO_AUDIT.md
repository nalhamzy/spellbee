# SpellBee — Studio Readiness Audit

**Date:** 2026-05-10
**Auditor:** studio-standards pass (no code changes)
**Build state per SHIP_V1.md:** code complete, signed AAB builds at 45.2 MB

---

## 1. Verdict

**SHIP-WITH-FIXES** — three blocking items, all fixable in well under a day. Once cleared, app is publishable; but in current state it would either (a) ship with test AdMob IDs serving zero revenue, (b) fail Apple privacy-manifest validation in 2024+, or (c) get pulled for vapor features in the listing.

---

## 2. Apple Pre-Flight Scorecard (9 items)

| # | Check | Result |
|---|---|---|
| 1 | Restore Purchases button | **PASS** — `paywall_screen.dart:42` AppBar action + `settings_screen.dart:92-94` list tile, both call `iapServiceProvider.restore()` → `_iap.restorePurchases()` |
| 2 | No "preview"/"stub"/"no payment" disclaimers | **PASS** — only "stub" hits are TTS-phrase-asset filenames (unrelated). No fake-purchase copy. |
| 3 | Trial CTA copy compliance | **N/A** — paywall offers no free trial in-app. LISTING_COPY mentions an optional 7-day Play trial; if enabled in Console, the Play sub config will surface auto-compliant CTA. |
| 4 | `ITSAppUsesNonExemptEncryption=false` | **PASS** — Info.plist line 80-81 |
| 5 | App icon opaque (no alpha) | **PASS** (per pubspec `remove_alpha_ios: true` + SHIP_V1 affidavit; visual spot-check optional) |
| 6 | Account-deletion path | **N/A** — fully local-first; no Firebase Auth, no account, all data in SharedPreferences. Listing copy correctly states "No account. No cloud sync." |
| 7 | IAP product IDs single source of truth | **PASS** — only [iap_ids.dart](C:\Users\PC\Documents\GitHub\spellbee\lib\core\constants\iap_ids.dart) holds the strings; no hardcoded duplicates anywhere in lib/ |
| 8 | `PrivacyInfo.xcprivacy` present | **FAIL** — file does NOT exist at [ios/Runner/PrivacyInfo.xcprivacy](C:\Users\PC\Documents\GitHub\spellbee\ios\Runner\PrivacyInfo.xcprivacy). Apple has required this for new submissions since May 2024. **BLOCKER.** |
| 9 | AdMob test IDs not in release path | **PARTIAL FAIL** — [ad_ids.dart:22-25](C:\Users\PC\Documents\GitHub\spellbee\lib\core\constants\ad_ids.dart) prod slots still hold `XXXXXXXXXX` placeholders, so `_useTest` evaluates true even in release. Also Info.plist `GADApplicationIdentifier` and AndroidManifest `APPLICATION_ID` both still hold Google's *sample* App IDs (`3940256099942544~...`). Won't reject the binary, but ships with **$0 revenue path**. |

---

## 3. Listing-Copy Issues

Reviewed [store_assets/LISTING_COPY.md](C:\Users\PC\Documents\GitHub\spellbee\store_assets\LISTING_COPY.md):

1. **Vapor feature: "PDF progress reports / PDF export"** — listed as a Premium perk in description, paywall, settings, and dashboard, but no `pdf` package in pubspec.yaml and no export code anywhere in lib/. **Apple will reject under 2.3.1 Performance: Accurate Metadata** if a reviewer tries to use it. Either implement (1–2 hr with the `pdf` + `printing` packages) or strip the bullet from all 4 surfaces and the listing.
2. **Vapor feature: "Premium voice packs"** — paywall claims this. There's an `openai_tts_service.dart` so the plumbing is partially there, but if no `OPENAI_API_KEY` ships with the build it'll silently fall back. Either ship the key (Codemagic env), strip the perk, or rename it to "premium voice cues" referencing the bundled `assets/audio/phrases/` mp3s (which IS implemented).
3. **"Scripps-tier" used twice** — once in Description ("K-1 starter words to Scripps-tier stumpers") and once in screenshot caption ("K-1 to Scripps-tier"). **Scripps is a trademark** of E.W. Scripps Company, publisher of the Scripps National Spelling Bee. Apple/Google won't catch this in review, but Scripps' counsel might. Rewrite to `"K-1 starter words to championship-tier stumpers"` or `"...to advanced bee-level stumpers"`. Pre-emptive.
4. **App-name length** — "SpellBee: Spelling Bee for Kids" is 31 chars; Apple cap is 30. SHIP_V1 already flags this. Fall-back is "SpellBee: Spelling Bee Kids" (27 chars) — keep ready.
5. **COPPA / under-13** — copy correctly avoids "Made for Kids" / "Designed for Families." Local-only data + no account is ideal for COPPA compliance. The age-rating-questionnaire answer "Targets children under 13: Yes" combined with NOT enabling Kids Category is the right needle to thread.
6. **No "Scripps National Spelling Bee" usage** — confirmed not present beyond the "Scripps-tier" descriptor above.

---

## 4. Top 3 Enhancement Opportunities (impact-per-effort)

### #1 — Daily Word + 7-Day Streak (HIGH impact, LOW effort, 4–6 hr)
SpellBee has stat tracking but no **return-tomorrow hook**. Add a single "Word of the Day" card on the dashboard that pulls one word from the catalog (deterministic by `DateTime.now().day`), shows pronunciation + definition + a one-tap "spell it" mini-test. Track `currentDailyStreak` in stats. Push a single local notification ("Today's word is ready 🐝") at a parent-set time. This is the proven retention loop from Wordle, Duolingo, NYT Spelling Bee — kids open the app every morning. Implementation: extend `stats_screen` data model with a `lastDailyDate` + `dailyStreak`, plus `flutter_local_notifications`.

### #2 — Shareable Test Result Card (HIGH impact, LOW effort, 3–4 hr)
Currently the results screen shows accuracy + streak but has **no share moment**. Generate a square 1080×1080 image card on perfect-test or new-best-streak: "🐝 [Kid's nickname] just nailed 10/10 Grade-3 words! Streak: 12. — sent from SpellBee." Hook to `Share.shareXFiles`. Parents will share to family group chats and school WhatsApp groups. Free distribution mechanic; this is what Drift/ChromaPulse don't have. Use `screenshot` package + `share_plus`.

### #3 — Parent Dashboard Mode (MEDIUM impact, MEDIUM effort, 1 day)
The wedge vs. SpellingCity/Spelling Bee Ninja is **parent-as-coach**. Today's app has parent-made lists but no parent visibility. Add a long-press-to-unlock parent area showing: words this kid has missed 2+ times, recommended re-test pack, weekly accuracy trend. Pair with the (currently vapor) PDF export so parents can email a Friday progress report to the teacher. Becomes the **upgrade trigger** — free tier shows the mistakes, premium unlocks the PDF + history. This unifies the IAP funnel: kid uses app → parent sees mistakes → parent upgrades for PDF.

---

## 5. Hard Blockers for Publication

1. **Missing `ios/Runner/PrivacyInfo.xcprivacy`** — Apple required since May 1 2024. Must declare data types collected + reasons for using `UserDefaults`, `FileTimestamp`, `SystemBootTime` APIs. Template lives in `ops/ci-cd/templates/` (per studio convention) — copy + customize for "no tracking, on-device only."
2. **AdMob real IDs not pasted** — both [ad_ids.dart:22-25](C:\Users\PC\Documents\GitHub\spellbee\lib\core\constants\ad_ids.dart) prod slots and the App IDs in [Info.plist:71-72](C:\Users\PC\Documents\GitHub\spellbee\ios\Runner\Info.plist) + [AndroidManifest.xml:30-32](C:\Users\PC\Documents\GitHub\spellbee\android\app\src\main\AndroidManifest.xml). Will technically ship and be approved, but earns $0 — equivalent to a soft blocker for revenue.
3. **Vapor "PDF export" claim** — strip from listing + paywall + settings + dashboard, OR implement (preferred — see Enhancement #3 funnel). Currently a 2.3.1 metadata-rejection risk.

---

## 6. Recommended Next Steps

**ci-cd-engineer** (today):
- Create `ios/Runner/PrivacyInfo.xcprivacy` from the studio template (no tracking, UserDefaults reason `CA92.1`, FileTimestamp reason `C617.1` if used by `path_provider`).
- Confirm Codemagic `spellbee_secrets` env group has `GEMINI_API_KEY` (and decide on `OPENAI_API_KEY` for premium voice).

**console-operator** (today):
- Create the 4 AdMob ad units + 2 App IDs at apps.admob.com.
- Paste 4 unit IDs into [ad_ids.dart](C:\Users\PC\Documents\GitHub\spellbee\lib\core\constants\ad_ids.dart) and 2 App IDs into Info.plist + AndroidManifest.

**mobile-developer** (this week):
- **Decision call with portfolio-manager**: implement PDF export (1 day, unifies funnel) OR strip the perk (15 min). Recommend implement.
- Strip "Scripps-tier" → "championship-tier" in LISTING_COPY (2 surfaces).
- Implement Enhancement #1 (Daily Word + streak) **before** v1.0.0 tag — this is the retention difference between a $50/mo and $500/mo app.
- Implement Enhancement #2 (Shareable card) as v1.0.1 hot-follow within 7 days of launch.

**portfolio-manager:**
- Hold the `git tag v1.0.0` until #1–#3 blockers cleared. With Enhancement #1 added, ship v1.0.0; defer #2 and #3 to v1.0.1 / v1.1.0 to keep momentum.

---

*Audit complete. No source files modified.*
