# SpellBee — Beta App Review Information
# For: App Store Connect > Apps > SpellBee > TestFlight > Beta App Review Information
# Filled by: portfolio-manager 2026-05-11
# This screen is one-time per app. Fill it before the first TestFlight push.
# Missing Beta App Review Information blocks auto-publish from Codemagic on every build.
# Codemagic auto-publish is OFF for v1.0.0 (first IPA uploaded manually via Transporter).
# Auto-publish enables at v1.0.5+ — this screen must be complete before that tag fires.

---

## BETA APP REVIEWER CONTACT

| Field | Value |
|---|---|
| First Name | Nadir |
| Last Name | Al-Hamzi |
| Phone | [CEO TO FILL — required by Apple] |
| Email | nalhamzy@gmail.com |

**Note for CEO:** Apple requires a valid phone number on this screen. Enter your mobile number. This is for TestFlight Beta App Review contact only — Apple's review team may contact this number if they have questions about the beta build. It is not displayed to external testers. Enter the number before the first TestFlight push to avoid a "Beta App Review Information missing" rejection that blocks the build from appearing in TestFlight.

---

## DEMO ACCOUNT CREDENTIALS

SpellBee does not require sign-in for the demo experience. All app functionality is accessible without an account. Reviewer can launch the app and reach every feature including the paywall directly from the home screen.

If Apple insists on credentials, use:

| Field | Value |
|---|---|
| Email | review@idealintelligence.com |
| Password | [ci-cd-engineer to fill before first TestFlight push] |

---

## TEST INSTRUCTIONS

SpellBee is a spelling-bee practice app for kids and parents. On launch, the home screen lists eight difficulty levels (K-1 through Championship). Tap any level to start a session — the AI pronouncer reads each word aloud, offers a definition, and uses the word in a sentence on request, just like a real bee. Two practice modes: TYPE (typed input with instant correctness feedback and a spell-out on misses) and SPELL ALOUD (microphone input that recognises letter names like "see a tee" → CAT). Both modes work on sandbox. The AI word packs are accessible from the home screen's "Word Packs" button — tap, enter any theme (dinosaurs, baking, mythology), and SpellBee generates a fresh 10-word pack at your selected level using Gemini when connected and on-device fallback when offline. To test the paywall: tap "SpellBee Premium" in the settings menu or hit the lock icon on the AI packs feature — the paywall sheet opens with three options: Monthly ($4.99), Yearly ($24.99 with 7-day trial), and Lifetime ($29.99 one-time). On sandbox, tap any option to trigger the native StoreKit payment sheet. The app uses native `in_app_purchase` (StoreKit 2 on iOS 15+) — there is no RevenueCat SDK in v1.0. Restore Purchases is accessible from the Settings screen.

---

## HOW TO USE THIS DOCUMENT

1. Log in to App Store Connect at appstoreconnect.apple.com.
2. Navigate to Apps > SpellBee > TestFlight tab.
3. In the left sidebar, click "Beta App Review Information."
4. Fill in First Name: Nadir, Last Name: Al-Hamzi, Email: nalhamzy@gmail.com.
5. Enter the phone number (CEO fills this field).
6. SpellBee does not require sign-in — leave the credential fields blank or fill with the placeholder above if Apple insists.
7. Paste the test instructions paragraph above verbatim into the "Notes" text area.
8. Click Save.
