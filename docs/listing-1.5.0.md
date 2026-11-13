# SpellBee 1.5.0 store text

Only What's New changes. Name, subtitle, keywords, promo text and screenshots stay as in
[listing-1.4.0.md](listing-1.4.0.md). Build number is 26 on both stores (25 was used on iOS only).

### What's New in 1.5.0 (iOS What's New and Play release notes, en-US)
Max 500 characters per store. No price and no "free" wording (Apple 2.3.7). Written for parents.
```
• The Premium screen is easier to read: plans come first, and the store's terms plus the Privacy and Terms links stay in view
• After a good round, a small "For grown-ups" note shows what Premium adds. It opens only after the parent check
• Small fixes and polish
```
About 300 characters, within the 500 limit for both stores.

### Whykeeper card (grown-ups only): OFF until `promo.json` is published
1.5.0 contains a "Homework help for grown-ups" card (Settings and the bottom of Stats) that recommends
Whykeeper. It is hidden for everyone until the file below is published, so it is deliberately NOT
mentioned in What's New.

- The app asks once per local day for `https://nalhamzy.github.io/spellbee/promo.json`.
- A 404, an empty URL, any error, or a URL whose host is not exactly `apps.apple.com` (iOS) or
  `play.google.com` (Android) leaves the card hidden.
- [promo.json](promo.json) in this folder is the ready-to-publish "off" file (both URLs empty). To turn
  the card on, put the real store URLs in it and publish the docs site; no app release is needed.
  Turning it on changes nothing in the listing; to switch it off again, empty the URLs.
- Tapping the card passes the parent gate, then opens the store link outside the app.
- Privacy note: the daily request is an anonymous GET to GitHub Pages, no identifiers or query. GitHub
  sees the device's IP address like any web request. docs/privacy.html does not mention it yet; add one
  sentence before turning the card on if you want the policy to say so.
