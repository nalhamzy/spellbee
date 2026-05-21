"use strict";

const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {logger} = require("firebase-functions");
const {defineSecret} = require("firebase-functions/params");
const {onRequest} = require("firebase-functions/v2/https");

initializeApp();

const openAiApiKey = defineSecret("OPENAI_API_KEY");

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
    secrets: [openAiApiKey],
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

      if (!response.ok) {
        const text = await response.text();
        logger.warn("OpenAI TTS request failed", {
          status: response.status,
          body: text.slice(0, 240),
        });
        res.status(502).json({error: "TTS provider failed"});
        return;
      }

      const audio = Buffer.from(await response.arrayBuffer());
      logUsage(req, {voice, model, inputLength: input.length}).catch((error) =>
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
  const ip =
    `${req.headers["fastly-client-ip"] || req.headers["x-forwarded-for"] || ""}`
      .split(",")[0]
      .trim();
  await getFirestore().collection("spellbee_tts_usage").add({
    ...data,
    ipHash: simpleHash(ip),
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
