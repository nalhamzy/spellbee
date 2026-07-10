# SpellBee Store Screenshot Manifest

Generated from the real running SpellBee Flutter Web app, not mocked UI.

Capture source: `http://127.0.0.1:65381` with `?screenshot=1&shot=<scene>&vw=<logical-width>`.

The local capture server is started by ``tools/build_store_assets.ps1`` on an available loopback port and verified with a unique probe file before Chrome captures begin. If a requested port is already occupied, the script fails instead of capturing from a stale server.

The capture canvas is intentionally a little wider than the app logical width for phone/tablet screenshots. The real app UI is rendered centered inside that canvas so App Store and Play assets do not clip right-edge controls after Chrome rasterization/resizing.

## Upload Sets

| File | Dimensions | Platform target | Scene | Upload readiness |
|---|---:|---|---|---|
| ``android_phone/01_home.png`` | 1080x1920 | Google Play phone portrait | 01_home | Ready after visual review |
| ``android_phone/02_practice.png`` | 1080x1920 | Google Play phone portrait | 02_practice | Ready after visual review |
| ``android_phone/03_test.png`` | 1080x1920 | Google Play phone portrait | 03_test | Ready after visual review |
| ``android_phone/04_lists.png`` | 1080x1920 | Google Play phone portrait | 04_lists | Ready after visual review |
| ``android_phone/05_paywall.png`` | 1080x1920 | Google Play phone portrait | 05_paywall | Ready after visual review |
| ``android_tablet/01_home.png`` | 1600x2560 | Google Play tablet portrait | 01_home | Ready after visual review |
| ``android_tablet/02_practice.png`` | 1600x2560 | Google Play tablet portrait | 02_practice | Ready after visual review |
| ``android_tablet/03_test.png`` | 1600x2560 | Google Play tablet portrait | 03_test | Ready after visual review |
| ``android_tablet/04_lists.png`` | 1600x2560 | Google Play tablet portrait | 04_lists | Ready after visual review |
| ``android_tablet/05_paywall.png`` | 1600x2560 | Google Play tablet portrait | 05_paywall | Ready after visual review |
| ``google_play/feature_graphic_1024x500.png`` | 1024x500 | Google Play feature graphic | feature_graphic_1024x500 | Ready after visual review |
| ``ios_65/01_home.png`` | 1284x2778 | App Store iPhone 6.5 inch portrait | 01_home | Ready after visual review |
| ``ios_65/02_practice.png`` | 1284x2778 | App Store iPhone 6.5 inch portrait | 02_practice | Ready after visual review |
| ``ios_65/03_test.png`` | 1284x2778 | App Store iPhone 6.5 inch portrait | 03_test | Ready after visual review |
| ``ios_65/04_lists.png`` | 1284x2778 | App Store iPhone 6.5 inch portrait | 04_lists | Ready after visual review |
| ``ios_65/05_paywall.png`` | 1284x2778 | App Store iPhone 6.5 inch portrait | 05_paywall | Ready after visual review |
| ``ios_67/01_home.png`` | 1290x2796 | App Store iPhone 6.7/6.9 inch portrait | 01_home | Ready after visual review |
| ``ios_67/02_practice.png`` | 1290x2796 | App Store iPhone 6.7/6.9 inch portrait | 02_practice | Ready after visual review |
| ``ios_67/03_test.png`` | 1290x2796 | App Store iPhone 6.7/6.9 inch portrait | 03_test | Ready after visual review |
| ``ios_67/04_lists.png`` | 1290x2796 | App Store iPhone 6.7/6.9 inch portrait | 04_lists | Ready after visual review |
| ``ios_67/05_paywall.png`` | 1290x2796 | App Store iPhone 6.7/6.9 inch portrait | 05_paywall | Ready after visual review |
| ``ipad_129/01_home.png`` | 2048x2732 | App Store iPad 12.9/13 inch portrait | 01_home | Ready after visual review |
| ``ipad_129/02_practice.png`` | 2048x2732 | App Store iPad 12.9/13 inch portrait | 02_practice | Ready after visual review |
| ``ipad_129/03_test.png`` | 2048x2732 | App Store iPad 12.9/13 inch portrait | 03_test | Ready after visual review |
| ``ipad_129/04_lists.png`` | 2048x2732 | App Store iPad 12.9/13 inch portrait | 04_lists | Ready after visual review |
| ``ipad_129/05_paywall.png`` | 2048x2732 | App Store iPad 12.9/13 inch portrait | 05_paywall | Ready after visual review |

## Validation Notes

- Inner UI is captured from the current Flutter app widgets via Flutter Web.
- iPhone screenshots are captured with extra horizontal safety gutter and validated for exact dimensions and meaningful image content.
- No fake app screens, drawn-over controls, browser chrome, debug banner, or placeholder Flutter launcher icon should be present.
- App Store iPhone outputs use accepted portrait dimensions for 6.5 inch and 6.7/6.9 inch displays.
- App Store iPad output uses 2048x2732, accepted for iPad Pro 12.9 inch portrait.
- Google Play screenshots are 9:16 portrait and stay within the 320-3840 px bounds and 2:1 maximum side-ratio rule.
- Google Play feature graphic is 1024x500 and uses real app captures as source material.
- Images are PNG24 with no alpha channel.
