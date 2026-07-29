"use strict";

const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {logger} = require("firebase-functions");
const {defineSecret} = require("firebase-functions/params");
const {onRequest} = require("firebase-functions/v2/https");

initializeApp();

const openAiApiKey = defineSecret("OPENAI_API_KEY");
const pollyAccessKeyId = defineSecret("POLLY_AWS_ACCESS_KEY_ID");
const pollySecretAccessKey = defineSecret("POLLY_AWS_SECRET_ACCESS_KEY");
const gatewayToken = defineSecret("TTS_GATEWAY_TOKEN");

// Abuse / spend caps. This endpoint spends real OpenAI and Polly credit, and
// its URL is baked into the shipped binary, so it must be bounded.
//
// Auth is deliberately SOFT: builds up to and including 1.0.13 were compiled
// without a gateway token (TTS_GATEWAY_TOKEN was never set in Codemagic), so
// hard-rejecting tokenless callers would silently downgrade premium studio
// voice to device TTS for every user already on the store — including the
// build currently in App Review. Tokenless callers therefore still work but
// get a much tighter per-IP quota. Once a token-bearing build is the floor,
// set REQUIRE_TOKEN=true to close the legacy lane entirely.
const REQUIRE_TOKEN = false;
const LIMIT_ANON_REQUESTS_PER_IP = 250;
const LIMIT_AUTH_REQUESTS_PER_IP = 1500;
// Cost-linked global backstop: characters map ~linearly to provider spend.
const LIMIT_GLOBAL_CHARS_PER_DAY = 750000;

// OpenAI voice → Polly neural voice, used when OpenAI is unavailable
// (quota/outage). Ivy and Joanna are kid-friendly US English neural voices.
const pollyVoiceFor = {
  alloy: "Matthew",
  ash: "Stephen",
  ballad: "Ruth",
  coral: "Danielle",
  echo: "Gregory",
  fable: "Amy",
  marin: "Joanna",
  nova: "Ivy",
  onyx: "Matthew",
  sage: "Kendra",
  shimmer: "Salli",
  verse: "Joey",
};

const allowedVoices = new Set([
  "alloy",
  "ash",
  "ballad",
  "coral",
  "echo",
  "fable",
  "marin",
  "nova",
  "onyx",
  "sage",
  "shimmer",
  "verse",
]);

const allowedModels = new Set(["gpt-4o-mini-tts", "tts-1", "tts-1-hd"]);

exports.spellbeeTts = onRequest(
  {
    region: "us-central1",
    timeoutSeconds: 30,
    memory: "256MiB",
    secrets: [
      openAiApiKey,
      pollyAccessKeyId,
      pollySecretAccessKey,
      gatewayToken,
    ],
    cors: true,
  },
  async (req, res) => {
    if (req.method === "OPTIONS") {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
      res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({error: "POST required"});
      return;
    }

    const body = normalizeBody(req.body);
    const input = `${body.input || ""}`.trim();
    const voice = `${body.voice || "marin"}`.trim().toLowerCase();
    const model = `${body.model || "gpt-4o-mini-tts"}`.trim();
    const speed = clampSpeed(body.speed);

    if (!input || input.length > 280) {
      res.status(400).json({error: "Invalid input length"});
      return;
    }

    if (!allowedVoices.has(voice)) {
      res.status(400).json({error: "Unsupported voice"});
      return;
    }

    const authorized = hasValidToken(req);
    if (REQUIRE_TOKEN && !authorized) {
      res.status(401).json({error: "Unauthorized"});
      return;
    }

    const ipHash = simpleHash(clientIp(req));
    const allowance = await checkQuota(ipHash, authorized, input.length);
    if (!allowance.allowed) {
      logger.warn("TTS quota exceeded", {scope: allowance.scope, ipHash});
      res.set("Retry-After", "3600");
      res.status(429).json({error: "Quota exceeded"});
      return;
    }

    if (!allowedModels.has(model)) {
      res.status(400).json({error: "Unsupported model"});
      return;
    }

    try {
      const response = await fetch("https://api.openai.com/v1/audio/speech", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${openAiApiKey.value()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          voice,
          input,
          response_format: "mp3",
          speed,
        }),
      });

      let audio;
      let provider = "openai";
      if (response.ok) {
        audio = Buffer.from(await response.arrayBuffer());
      } else {
        const text = await response.text();
        logger.warn("OpenAI TTS request failed, trying Polly", {
          status: response.status,
          body: text.slice(0, 240),
        });
        audio = await pollySynthesize(input, voice, speed);
        provider = "polly";
      }

      logUsage(req, {
        voice,
        model,
        provider,
        authorized,
        inputLength: input.length,
      }).catch((error) =>
        logger.warn("TTS usage log failed", {message: error.message}),
      );

      res.set("Access-Control-Allow-Origin", "*");
      res.set("Content-Type", "audio/mpeg");
      res.set("Cache-Control", "private, max-age=86400");
      res.status(200).send(audio);
    } catch (error) {
      logger.error("SpellBee TTS failed", {message: error.message});
      res.status(500).json({error: "TTS unavailable"});
    }
  },
);

async function pollySynthesize(input, voice, speed) {
  const {PollyClient, SynthesizeSpeechCommand} =
    require("@aws-sdk/client-polly");
  const client = new PollyClient({
    region: "us-east-1",
    credentials: {
      accessKeyId: pollyAccessKeyId.value(),
      secretAccessKey: pollySecretAccessKey.value(),
    },
  });
  // Polly neural has no speed param; use SSML prosody when speed != 1.
  const pct = Math.round(speed * 100);
  const escaped = input
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
  const useSsml = pct !== 100;
  const result = await client.send(new SynthesizeSpeechCommand({
    Engine: "neural",
    VoiceId: pollyVoiceFor[voice] || "Joanna",
    OutputFormat: "mp3",
    TextType: useSsml ? "ssml" : "text",
    Text: useSsml ?
      `<speak><prosody rate="${pct}%">${escaped}</prosody></speak>` :
      input,
  }));
  const chunks = [];
  for await (const chunk of result.AudioStream) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

/**
 * Spend dashboard for the operator. Token-gated, read-only. Returns the
 * per-day request/character counters the TTS gateway meters against, plus the
 * OpenAI-vs-Polly split, so credit burn can be checked without console access.
 */
exports.spellbeeTtsStats = onRequest(
  {
    region: "us-central1",
    timeoutSeconds: 30,
    memory: "256MiB",
    secrets: [gatewayToken],
    cors: false,
  },
  async (req, res) => {
    if (!hasValidToken(req)) {
      res.status(401).json({error: "Unauthorized"});
      return;
    }
    try {
      const db = getFirestore();
      const quota = await db.collection("spellbee_tts_quota").get();
      const days = {};
      quota.forEach((doc) => {
        // Global docs are keyed YYYY-MM-DD; per-IP docs add a _<hash> suffix.
        if (!/^\d{4}-\d{2}-\d{2}$/.test(doc.id)) return;
        days[doc.id] = doc.data();
      });
      const usage = await db
        .collection("spellbee_tts_usage")
        .orderBy("createdAt", "desc")
        .limit(300)
        .get();
      const providers = {};
      let authed = 0;
      usage.forEach((doc) => {
        const d = doc.data();
        const p = d.provider || "unlogged";
        providers[p] = (providers[p] || 0) + 1;
        if (d.authorized) authed += 1;
      });
      res.status(200).json({
        limits: {
          globalCharsPerDay: LIMIT_GLOBAL_CHARS_PER_DAY,
          anonRequestsPerIp: LIMIT_ANON_REQUESTS_PER_IP,
          authRequestsPerIp: LIMIT_AUTH_REQUESTS_PER_IP,
          requireToken: REQUIRE_TOKEN,
        },
        perDay: days,
        recentSample: {
          size: usage.size,
          byProvider: providers,
          withValidToken: authed,
        },
      });
    } catch (error) {
      logger.error("stats failed", {message: error.message});
      res.status(500).json({error: error.message});
    }
  },
);

function hasValidToken(req) {
  const expected = `${gatewayToken.value() || ""}`.trim();
  if (!expected) return false;
  const header = `${req.headers.authorization || ""}`.trim();
  const presented = header.replace(/^Bearer\s+/i, "");
  if (presented.length !== expected.length) return false;
  const crypto = require("crypto");
  return crypto.timingSafeEqual(
    Buffer.from(presented),
    Buffer.from(expected),
  );
}

function clientIp(req) {
  return `${
    req.headers["fastly-client-ip"] || req.headers["x-forwarded-for"] || ""
  }`
    .split(",")[0]
    .trim();
}

/**
 * Bounds spend on this endpoint. Two independent ceilings: a per-IP request
 * count that blunts single-source abuse, and a global daily character budget
 * that caps worst-case provider cost even under a distributed flood.
 *
 * Fails OPEN on Firestore errors — a metering outage should degrade the cap,
 * not the premium voice that paying users are entitled to.
 *
 * @param {string} ipHash hashed caller IP, used as the per-IP bucket key
 * @param {boolean} authorized whether the caller presented a valid token
 * @param {number} chars characters about to be synthesized
 * @return {Promise<{allowed: boolean, scope: (string|undefined)}>} verdict
 */
async function checkQuota(ipHash, authorized, chars) {
  const day = new Date().toISOString().slice(0, 10);
  const db = getFirestore();
  const perIpLimit = authorized ?
    LIMIT_AUTH_REQUESTS_PER_IP :
    LIMIT_ANON_REQUESTS_PER_IP;
  try {
    const globalRef = db.collection("spellbee_tts_quota").doc(day);
    const ipRef = db.collection("spellbee_tts_quota").doc(`${day}_${ipHash}`);
    const [globalSnap, ipSnap] = await Promise.all([
      globalRef.get(),
      ipRef.get(),
    ]);
    const globalChars = (globalSnap.data() || {}).chars || 0;
    const ipRequests = (ipSnap.data() || {}).requests || 0;

    if (globalChars + chars > LIMIT_GLOBAL_CHARS_PER_DAY) {
      return {allowed: false, scope: "global-chars"};
    }
    if (ipRequests + 1 > perIpLimit) {
      return {allowed: false, scope: authorized ? "ip-auth" : "ip-anon"};
    }

    await Promise.all([
      globalRef.set({
        chars: FieldValue.increment(chars),
        requests: FieldValue.increment(1),
      }, {merge: true}),
      ipRef.set({
        chars: FieldValue.increment(chars),
        requests: FieldValue.increment(1),
        authorized,
      }, {merge: true}),
    ]);
    return {allowed: true};
  } catch (error) {
    logger.warn("TTS quota check failed, allowing request", {
      message: error.message,
    });
    return {allowed: true};
  }
}

function normalizeBody(body) {
  if (!body) return {};
  if (typeof body === "string") {
    try {
      return JSON.parse(body);
    } catch (_) {
      return {};
    }
  }
  return body;
}

function clampSpeed(value) {
  const speed = Number(value);
  if (!Number.isFinite(speed)) return 1.0;
  return Math.min(1.5, Math.max(0.75, speed));
}

async function logUsage(req, data) {
  await getFirestore().collection("spellbee_tts_usage").add({
    ...data,
    ipHash: simpleHash(clientIp(req)),
    createdAt: FieldValue.serverTimestamp(),
  });
}

function simpleHash(value) {
  let hash = 0;
  for (let i = 0; i < value.length; i += 1) {
    hash = (hash * 31 + value.charCodeAt(i)) >>> 0;
  }
  return hash.toString(16).padStart(8, "0");
}
