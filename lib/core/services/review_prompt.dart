import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Things that happened in this app session that rule out asking for a
/// rating: a purchase / microphone / store error, or a visit to the paywall.
class SessionSignals {
  bool paywallSeen = false;
  bool errorSeen = false;
}

/// When SpellBee may offer a grown-up the store rating sheet.
///
/// - Only right after a success moment: the 3rd (or later) perfect round,
///   or the very first badge.
/// - At most once per [cooldown].
/// - Never in a session that showed an error or the paywall.
/// - The offer is a small "for grown-ups" card; the store sheet opens only
///   after the multiplication parent gate, so the child never sees it.
class ReviewPromptPolicy {
  ReviewPromptPolicy._();

  static const cooldown = Duration(days: 120);
  static const perfectRoundsNeeded = 3;

  static bool isSuccessMoment({
    required bool roundPerfect,
    required int perfectRounds,
    required int newBadges,
    required int totalBadges,
  }) =>
      (roundPerfect && perfectRounds >= perfectRoundsNeeded) ||
      (newBadges > 0 && totalBadges == newBadges);

  static bool shouldOffer({
    required bool successMoment,
    required DateTime now,
    DateTime? lastAsked,
    bool errorSeen = false,
    bool paywallSeen = false,
  }) {
    if (!successMoment || errorSeen || paywallSeen) return false;
    return lastAsked == null || now.difference(lastAsked) >= cooldown;
  }
}

/// Counts perfect rounds, decides on the offer and persists when it was last
/// made, then opens the platform review sheet on the grown-up's request.
class ReviewPromptService {
  ReviewPromptService(
    this._prefs, {
    SessionSignals? signals,
    DateTime Function()? clock,
    Future<bool> Function()? isAvailable,
    Future<void> Function()? requestReview,
  }) : signals = signals ?? SessionSignals(),
       _clock = clock ?? DateTime.now,
       _isAvailable = isAvailable ?? InAppReview.instance.isAvailable,
       _requestReview = requestReview ?? InAppReview.instance.requestReview;

  static const _kLastAsked = 'sb.review.lastAsked';
  static const _kPerfectRounds = 'sb.review.perfectRounds';

  final SharedPreferences _prefs;
  final SessionSignals signals;
  final DateTime Function() _clock;
  final Future<bool> Function() _isAvailable;
  final Future<void> Function() _requestReview;

  int get perfectRounds => _prefs.getInt(_kPerfectRounds) ?? 0;

  DateTime? get lastAsked =>
      DateTime.tryParse(_prefs.getString(_kLastAsked) ?? '');

  /// Records a finished round and returns whether to offer the rating card
  /// on its results screen. Persists the offer date when it says yes.
  bool recordRound({
    required bool perfect,
    required int newBadges,
    required int totalBadges,
  }) {
    final count = perfectRounds + (perfect ? 1 : 0);
    if (perfect) _prefs.setInt(_kPerfectRounds, count);
    final now = _clock();
    final offer = ReviewPromptPolicy.shouldOffer(
      successMoment: ReviewPromptPolicy.isSuccessMoment(
        roundPerfect: perfect,
        perfectRounds: count,
        newBadges: newBadges,
        totalBadges: totalBadges,
      ),
      now: now,
      lastAsked: lastAsked,
      errorSeen: signals.errorSeen,
      paywallSeen: signals.paywallSeen,
    );
    if (offer) _prefs.setString(_kLastAsked, now.toUtc().toIso8601String());
    return offer;
  }

  /// Opens the store's own rating sheet. Call only after the parent gate.
  /// Returns false when the platform cannot show it.
  Future<bool> requestReview() async {
    try {
      if (!await _isAvailable()) return false;
      await _requestReview();
      return true;
    } catch (_) {
      return false;
    }
  }
}
