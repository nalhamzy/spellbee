import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/utils/day_key.dart';

/// When the results screen may show a grown-up the small Premium card.
///
/// - Never for a Premium household.
/// - Never in the first [graceRounds] rounds a player ever finishes.
/// - Only after a round the child did well on ([minAccuracy] correct or
///   better), so it never lands on a discouraging moment.
/// - Never together with the rating card (the rating card wins and does not
///   use up the day).
/// - At most once per local day.
class ResultsOfferPolicy {
  ResultsOfferPolicy._();

  static const graceRounds = 2;
  static const minAccuracy = 0.6;

  static bool shouldOffer({
    required bool premium,
    required int roundsFinished,
    required double accuracy,
    required bool reviewOffered,
    required int today,
    int? lastOfferDay,
  }) {
    if (premium || reviewOffered) return false;
    if (roundsFinished <= graceRounds) return false;
    if (accuracy < minAccuracy) return false;
    return lastOfferDay != today;
  }
}

/// Counts finished rounds and remembers the day the card was last shown.
class ResultsOfferService {
  ResultsOfferService(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _kRounds = 'sb.offer.rounds';
  static const _kLastDay = 'sb.offer.lastDay';

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  int get roundsFinished => _prefs.getInt(_kRounds) ?? 0;

  /// Records one finished round and returns whether to show the card on its
  /// results screen. Persists the day when it says yes.
  bool recordRound({
    required double accuracy,
    required bool premium,
    required bool reviewOffered,
  }) {
    final rounds = roundsFinished + 1;
    _prefs.setInt(_kRounds, rounds);
    final today = localDayKey(_clock());
    final offer = ResultsOfferPolicy.shouldOffer(
      premium: premium,
      roundsFinished: rounds,
      accuracy: accuracy,
      reviewOffered: reviewOffered,
      today: today,
      lastOfferDay: _prefs.getInt(_kLastDay),
    );
    if (offer) _prefs.setInt(_kLastDay, today);
    return offer;
  }
}
