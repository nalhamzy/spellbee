import 'dart:math' as math;

class VoicePhraseBank {
  VoicePhraseBank._();

  static final _random = math.Random();

  static const correct = [
    'great',
    'nice_work',
    'perfect',
    'amazing',
    'you_got_it',
    'wonderful',
    'excellent',
    'awesome',
    'brilliant',
    'fantastic',
    'super_job',
    'way_to_go',
    'nailed_it',
    'great_spelling',
    'well_done',
    'keep_it_up',
    'sharp_work',
    'smart_spelling',
    'smooth_spelling',
    'strong_spelling',
    'spelling_star',
    'lovely_work',
    'bright_work',
    'that_was_clear',
    'beautifully_done',
    'you_spelled_that_well',
  ];

  static const streak = [
    'on_fire',
    'three_row',
    'unstoppable',
    'hot_streak',
    'five_row',
    'champion',
    'buzzing_along',
    'streak_star',
    'smooth_run',
    'great_rhythm',
    'keep_going',
    'streak_power',
  ];

  static const miss = [
    'not_quite',
    'almost',
    'close_one',
    'good_try',
    'so_close',
    'keep_trying',
    'good_effort',
    'almost_there',
    'close_try',
    'check_the_letters',
    'no_worries',
  ];

  static const retry = [
    'try_again',
    'give_it_another_go',
    'one_more_try',
    'reset_and_try',
    'lets_try_again',
  ];

  static const perfectFinish = [
    'new_best',
    'perfect',
    'amazing',
    'excellent',
    'champion',
    'beautifully_done',
    'spelling_star',
  ];

  static const finish = [
    'test_complete',
    'well_done',
    'great_spelling',
    'keep_it_up',
    'wonderful',
    'lesson_done',
    'nice_practice',
    'strong_spelling',
  ];

  static String pick(List<String> stubs, {String? avoid}) {
    if (stubs.length > 1 && avoid != null) {
      final options = stubs.where((stub) => stub != avoid).toList();
      if (options.isNotEmpty) return options[_random.nextInt(options.length)];
    }
    return stubs[_random.nextInt(stubs.length)];
  }
}
