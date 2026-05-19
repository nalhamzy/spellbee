# SpellBee — ship v1.0.0 checklist

Code is 100% complete and the signed release AAB builds locally (45.2 MB).
What's left is console work only you can do. Full pipeline reference at
`C:\Users\PC\Documents\GitHub\Ideas\_pipeline\index.html`.

---

## Already done — don't redo

- [x] Flutter project scaffolded with bundle `com.idealai.spellbee`
- [x] Two monetization formats wired: banner (home + practice + test/
      settings) and rewarded video (gates bonus AI word packs)
- [x] Three IAP tiers namespaced: `spellbee_premium_{monthly,yearly,lifetime}`
- [x] TTS pronunciation (flutter_tts) with word / definition / sentence helpers
- [x] Mic input (speech_to_text) with letter-name normalisation
      ("see a tee" → CAT)
- [x] AI word generator (Gemini HTTP, falls back to local 200-word catalog
      across 8 grade levels)
- [x] Parent-made custom lists (3-list cap on free tier, unlimited on premium)
- [x] Stats: tests taken, accuracy, best in-test streak, perfect-test streak
- [x] Paywall with Apple-style tier picker (monthly / yearly-popular / lifetime)
- [x] Android signing: `upload-keystore.jks` + `key.properties` committed,
      build.gradle.kts wired, `.gitignore` un-ignored
- [x] iOS Info.plist: `GADApplicationIdentifier`, `SKAdNetworkItems`,
      `ITSAppUsesNonExemptEncryption=false`, `NSMicrophoneUsageDescription`,
      `NSSpeechRecognitionUsageDescription`, all 4 iPad orientations
- [x] Android manifest: `APPLICATION_ID` meta-data, `RECORD_AUDIO`,
      `INTERNET`, `BILLING`, speech recognizer queries
- [x] Icon: bee-themed opaque 1024×1024 at `assets/icon/icon_source.png`,
      launcher icons regenerated for iOS + Android
- [x] 22 store assets (android 1080×2400, iOS 6.9" 1290×2796, iOS 6.5"
      1284×2778, iPad 13" 2064×2752, feature_graphic 1024×500, icon-512)
- [x] SEO listing copy in `store_assets/LISTING_COPY.md`
- [x] `codemagic.yaml` ready with `release-both`, `ios-release`,
      `android-release` workflows

---

## 1. GitHub — create the repo

Private repo fine. Suggested name: `spellbee`.

```bash
cd C:/Users/PC/Documents/GitHub/spellbee
gh repo create nalhamzy/spellbee --public --source . --push
```

---

## 2. AdMob — create apps + 4 ad units

<https://apps.admob.com>

1. **Apps → Add app → Apple** → `SpellBee iOS` → copy App ID, paste into
   `ios/Runner/Info.plist` under `GADApplicationIdentifier`.
2. **Apps → Add app → Android** → `SpellBee Android` → copy App ID into
   `android/app/src/main/AndroidManifest.xml` (`APPLICATION_ID` meta-data).
3. Per app create 2 ad units: `SpellBee Banner` (Banner) and
   `SpellBee Rewarded` (Rewarded).
4. Paste the 4 unit IDs into `lib/core/constants/ad_ids.dart` in the
   `_prodBanner*` / `_prodRewarded*` slots. The code keeps using test IDs
   automatically in debug builds.

**Gemini for AI word packs (optional but recommended):**
Add `GEMINI_API_KEY` as an env var in the Codemagic `spellbee_secrets`
group, then change the build script to pass
`--dart-define=GEMINI_API_KEY=$GEMINI_API_KEY`. Without a key, the app
samples the bundled 200-word catalog — still useful but no themed packs.

---

## 3. Apple Developer — register bundle + profile

<https://developer.apple.com/account/resources/identifiers/list>

1. **+ App IDs → App** → Description `SpellBee iOS`, Bundle ID explicit
   `com.idealai.spellbee`, enable **In-App Purchase**, register.
2. <https://developer.apple.com/account/resources/profiles/list> → **+**
   → Distribution → App Store → existing `Apple Distribution` cert →
   Profile Name `SpellBee App Store` → Generate → download.
3. Upload the `.mobileprovision` to Codemagic → Personal Account Settings
   → Code signing identities → iOS provisioning profiles.

---

## 4. App Store Connect — create app record

<https://appstoreconnect.apple.com/apps>

1. **+ New App** → iOS, Name `SpellBee: Spelling Bee Tutor`, bundle
   `com.idealai.spellbee`, SKU `spellbee-ios-001`.
2. App Information → Category primary **Education**, secondary **Games →
   Word**. Age rating **4+**. **Made for Kids = NO**.
3. Paid Apps Agreement = Active.
4. Fill Name / Subtitle / Keywords / Description / Promo Text from
   `store_assets/LISTING_COPY.md`. Save as draft.
5. **Features → In-App Purchases and Subscriptions** → create the 3 IAPs
   (two subscriptions in the `spellbee_premium` group, one non-consumable
   lifetime) from the listing copy.
6. Upload screenshots from `store_assets/ios/` (6.9") +
   `store_assets/ios_65/` (6.5" if ASC asks) + `store_assets/ipad/`.

---

## 5. Google Play Console — create app + first AAB

<https://play.google.com/console>

1. **Create app** → `SpellBee: Spelling Bee for Kids`, en-US, app (not
   game), free. **Designed for Families: NO**.
2. Fill the Main store listing using `store_assets/LISTING_COPY.md` and
   `store_assets/android/` assets.
3. **App content** declarations: privacy policy URL, ads = Yes, data
   safety form, target audience (6–12 primary, 13+ secondary).
4. **Monetize → Subscriptions** → create monthly + yearly.
   **Monetize → In-app products** → create lifetime.
5. **Internal testing → Create new release** → drag
   `build/app/outputs/bundle/release/app-release.aab` → enroll in Play
   App Signing → rollout.
6. **Users and permissions → Invite** →
   `codemagic@rhyme-aa29b.iam.gserviceaccount.com` → Release manager role
   for SpellBee.

---

## 6. Codemagic — add the app

<https://codemagic.io/apps>

1. **Add application** → GitHub → `nalhamzy/spellbee`.
2. Settings → switch build config source from Workflow Editor to
   **codemagic.yaml**.
3. Confirm 3 workflows detected. Team-level `admin` integration and
   `google_play` group are inherited — no per-app config needed.

---

## 7. Tag and ship

```bash
cd C:/Users/PC/Documents/GitHub/spellbee
git tag v1.0.0
git push origin main --tags
```

`release-both` runs, ~20 min. IPA lands in TestFlight, AAB lands in Play
Production as draft.

---

## 8. After the green build

- **iOS:** ASC → TestFlight → once the build lands, attach to Version
  1.0.0 → attach all 3 IAPs in "In-App Purchases and Subscriptions" →
  Submit for Review.
- **Android:** Play Console → Production → Promote from Internal testing
  → Start rollout to production.

Review: Apple 1–3 days, Google 2–7 days for first submission.
