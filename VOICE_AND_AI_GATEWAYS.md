# SpellBee Voice And AI Gateways

SpellBee must not ship provider API keys in the mobile binary. High-quality
voice and thematic word generation are routed through studio-controlled gateway
endpoints.

## Build-Time Defines

- `TTS_GATEWAY_URL`: HTTPS endpoint that returns `audio/mpeg`.
- `TTS_GATEWAY_TOKEN`: optional short-lived client token for the TTS gateway.
- `WORD_GENERATOR_GATEWAY_URL`: HTTPS endpoint that returns JSON word packs.
- `WORD_GENERATOR_GATEWAY_TOKEN`: optional short-lived client token for the
  word generator gateway.
- `EVENTS_URL`: shared studio events endpoint (`ops/events-ingest` in the
  IdealIntelligenceMobileApps monorepo). Optional; unset or empty turns funnel
  events off (every call is a no-op). Must be `https://`.

If a gateway URL is missing or unavailable, the app falls back safely:

- voice falls back to bundled MP3s or on-device `flutter_tts`.
- word packs fall back to the local catalog.

## TTS Gateway Contract

Request:

```json
{
  "model": "gpt-4o-mini-tts",
  "voice": "marin",
  "input": "The word is, garden.",
  "response_format": "mp3",
  "speed": 1.0,
  "purpose": "spellbee-pronunciation"
}
```

Response:

- Status `200`
- Body: MP3 bytes
- Header: `Content-Type: audio/mpeg`

## Word Gateway Contract

Request:

```json
{
  "count": 10,
  "level": 3,
  "level_hint": "3rd grade",
  "theme": "space",
  "purpose": "spellbee-word-pack"
}
```

Response:

```json
{
  "words": [
    {
      "text": "orbit",
      "definition": "The path one object follows around another.",
      "example": "The moon stays in orbit around Earth."
    }
  ]
}
```

## Funnel Events (EVENTS_URL)

`lib/core/services/event_logger.dart` sends privacy-safe purchase-funnel
counters to the **shared studio events endpoint (`ops/events-ingest` in the
monorepo)**. There is no SpellBee-specific function: one portfolio-wide ingest
serves every app and aggregates daily counters. Off by default.

Request (one anonymous POST per event, fire-and-forget, 5 s timeout, no retry
queue, nothing stored on the device):

```json
{
  "app": "spellbee",
  "event": "paywall_view",
  "props": {"source": "adventures"},
  "app_version": "1.4.0",
  "platform": "android",
  "locale": "id-ID"
}
```

- No user, device, install, purchase or advertising identifiers; no free text.
- `props` keys are limited to `source`, `product`, `outcome`; values must match
  `[a-z0-9_.]{1,48}`, anything else is dropped client-side.
- Events: `paywall_view{source}`, `parent_gate_pass{source}`,
  `checkout_start{product}`, `purchase_verified{product}`,
  `purchase_verify_failed{product}`, `restore_result{outcome}`,
  `review_prompt_shown`, `reminder_enabled`.

Build: `--dart-define=EVENTS_URL=$EVENTS_URL`. `codemagic.yaml` passes
`${EVENTS_URL:-}` in every build, so a missing variable builds a no-op logger.

To turn it on:

1. Deploy the shared ingest from the monorepo (`ops/events-ingest`, owned by
   the studio, not this repo) and note its HTTPS URL.
2. Add `EVENTS_URL` to the `spellbee_secrets` Codemagic environment group.
3. Tag a release; check the ingest's daily counters for `app = spellbee`.
4. Play Data safety / App Privacy: the payload carries no identifiers; declare
   it as anonymous app-interaction analytics if the ingest stores it.

## Abuse Controls

- Require App Check or a signed client token.
- Verify premium entitlement for studio voice requests.
- Keep input short: max 240 characters for TTS, max 40 characters for themes.
- Cache repeated TTS text by normalized input, voice, and speed.
- Rate-limit per user, device, IP, and entitlement tier.
- Allow only known request purposes: `spellbee-pronunciation` and
  `spellbee-word-pack`.
- Filter generated words server-side for age suitability and real-word checks.
- Log only metadata needed for fraud and performance; avoid storing child text.

## Release Checklist

1. Confirm no provider keys are passed with `--dart-define` to the mobile app.
2. Configure the gateway URLs in Codemagic environment groups.
3. Smoke-test with no gateway configured to verify local fallbacks.
4. Smoke-test with gateway configured and premium enabled.
5. Verify `flutter analyze` and `flutter test` pass before tagging.
