# Android native smoke — 13 September 2026

Tested installed SpellBee **1.2.0 (19)**, debug APK, on the dedicated
`spellbee_release_20260913` Pixel 5 Android 12/API 31 emulator (`emulator-5556`).
This evidence predates the final build 20 contrast and defensive daily-round
changes; it does not establish native verification of those later changes.

Follow-up: Flutter attach and a hot restart loaded the final build 20 Dart source
into the installed build 19 debug shell. `home-build20.png` shows the corrected
dark-ink school-list link, visually checked on the Android emulator. This is
native rendering evidence for the updated Home theme, **not** an installation
or complete smoke test of the build 20 binary.

## Completed flows

- Home renders the initial level choice, **Start today's practice**, five-word
  introduction, and **Practice a school list**. See `home.png`.
- Created **SchoolSmoke**, pasted `bee,cat,dog,BEE`, reviewed the editable
  three-word preview and one skipped duplicate, confirmed, and saved. See
  `import.png`.
- Practiced that saved list in typing mode: submitted `wrong` for `bee`, tapped
  **Try again**, answered `bee` correctly, then answered `cat` and `dog` correctly
  on their first attempts.
- Results display **67%, 2 of 3 on first try**, **3/3 correct after practice**,
  **2/3 recalled without help**, and **Correct after retry** on `bee`. See
  `results.png`.
- Stats renders **3 words practiced**, **0 ready for review today**, **0 recalled
  without help on separate days**, **2/3 correct on the first try**, and **100%
  practice completion**. See `stats.png`.
- Force-stopped and relaunched SpellBee. The saved list retained its three words,
  one completed round, and score; Stats retained the same learning figures.
  Home retained six honey and transitioned from the first-use five-word routine
  to the regular eight-word routine. See `persist.png` for saved-list read-back.

Screenshots of Home, import, results, and Stats were visually inspected without
observed overflow. The build 19 honey-colored secondary labels are superseded
by build 20's contrast correction.

## Environment notes and limits

The existing shared QA emulator lacked installation space. A separate AVD was
created without clearing existing application data. Fresh boot required Vulkan
to be disabled with the old local emulator runtime. Android System UI briefly
displayed an ANR dialog; closing System UI and disabling animations in this
task's AVD recovered normal interaction. ADB commands remained intermittently
slow under host load. No SpellBee crash was observed during the completed flows.

This was an emulator typing smoke, not physical-device testing, microphone/accent
testing, a purchase/restore sandbox test, or a verification of store-distributed
artifacts. No real purchase was attempted.
