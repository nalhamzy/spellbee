import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/models/player_stats.dart';
import 'package:spellbee/core/models/premium_state.dart';
import 'package:spellbee/core/models/word_list.dart';
import 'package:spellbee/core/services/tts_service.dart';

/// SharedPreferences-backed, on-device only. No cloud, no account.
class StorageService {
  final SharedPreferences _prefs;
  StorageService(this._prefs);

  // ── Custom word lists ──────────────────────────────────────────────

  static const _kLists = 'sb.lists.v1';

  List<WordList> loadLists() {
    final raw = _prefs.getStringList(_kLists) ?? const [];
    return raw
        .map((e) {
          try {
            return WordList.decode(e);
          } catch (_) {
            return null;
          }
        })
        .whereType<WordList>()
        .toList();
  }

  Future<void> saveLists(List<WordList> lists) async {
    await _prefs.setStringList(_kLists, lists.map((l) => l.encode()).toList());
  }

  // ── Player stats ───────────────────────────────────────────────────

  static const _kStats = 'sb.stats.v1';

  PlayerStats loadStats() {
    final raw = _prefs.getString(_kStats);
    if (raw == null) return const PlayerStats();
    try {
      return PlayerStats.decode(raw);
    } catch (_) {
      return const PlayerStats();
    }
  }

  Future<void> saveStats(PlayerStats s) =>
      _prefs.setString(_kStats, s.encode());

  // ── Premium ─────────────────────────────────────────────────────────

  static const _kPremium = 'sb.premium.v1';

  PremiumState loadPremium() {
    final raw = _prefs.getString(_kPremium);
    if (raw == null) return const PremiumState();
    try {
      return PremiumState.decode(raw);
    } catch (_) {
      return const PremiumState();
    }
  }

  Future<void> savePremium(PremiumState s) =>
      _prefs.setString(_kPremium, s.encode());

  // ── Settings ────────────────────────────────────────────────────────

  static const _kSelectedLevel = 'sb.settings.level';
  static const _kParentPin = 'sb.settings.pin';
  static const _kVoiceSpeed = 'sb.settings.voiceSpeed';
  static const _kVoiceQuality = 'sb.settings.voiceQuality';
  static const _kOpenAiVoice = 'sb.settings.openAiVoice';

  int getSelectedLevel() => _prefs.getInt(_kSelectedLevel) ?? 3;
  Future<void> setSelectedLevel(int v) => _prefs.setInt(_kSelectedLevel, v);

  /// Returns 0 (calm), 1 (normal) or 2 (fast). Defaults to calm for early
  /// readers who need extra spacing between sounds.
  int getVoiceSpeedIndex() => _prefs.getInt(_kVoiceSpeed) ?? 0;
  Future<void> setVoiceSpeedIndex(int v) => _prefs.setInt(_kVoiceSpeed, v);

  int getVoiceQualityIndex() => _prefs.getInt(_kVoiceQuality) ?? 0;
  Future<void> setVoiceQualityIndex(int v) => _prefs.setInt(_kVoiceQuality, v);

  String getOpenAiVoice() =>
      _prefs.getString(_kOpenAiVoice) ?? kOpenAiStudioVoices.first.id;
  Future<void> setOpenAiVoice(String voice) =>
      _prefs.setString(_kOpenAiVoice, voice);

  String? getParentPin() => _prefs.getString(_kParentPin);
  Future<void> setParentPin(String? pin) async {
    if (pin == null || pin.isEmpty) {
      await _prefs.remove(_kParentPin);
    } else {
      await _prefs.setString(_kParentPin, pin);
    }
  }

  // ── Daily AI credit tracking (free-tier AI limits) ────────────────

  static const _kAiCreditsPrefix = 'sb.ai.credits.';
  String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  int getAiCredits() => _prefs.getInt('$_kAiCreditsPrefix${_todayKey()}') ?? 1;
  Future<void> setAiCredits(int v) =>
      _prefs.setInt('$_kAiCreditsPrefix${_todayKey()}', v);

  // ── Utility ─────────────────────────────────────────────────────────

  /// Only used by tests / debug.
  String exportAll() => jsonEncode({
    'lists': _prefs.getStringList(_kLists),
    'stats': _prefs.getString(_kStats),
    'premium': _prefs.getString(_kPremium),
  });
}
