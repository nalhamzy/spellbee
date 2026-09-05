import 'dart:math' as math;

import 'package:spellbee/core/models/word.dart';

const _ones = [
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'eleven',
  'twelve',
  'thirteen',
  'fourteen',
  'fifteen',
  'sixteen',
  'seventeen',
  'eighteen',
  'nineteen',
];

const _tens = [
  '',
  '',
  'twenty',
  'thirty',
  'forty',
  'fifty',
  'sixty',
  'seventy',
  'eighty',
  'ninety',
];

/// English words for 0..999, hyphenated the way schools teach them
/// ("forty-two", "three hundred seven").
String numberToWords(int n) {
  assert(n >= 0 && n <= 999, 'numberToWords supports 0..999');
  if (n < 20) return _ones[n];
  if (n < 100) {
    final t = _tens[n ~/ 10];
    final o = n % 10;
    return o == 0 ? t : '$t-${_ones[o]}';
  }
  final h = '${_ones[n ~/ 100]} hundred';
  final rest = n % 100;
  return rest == 0 ? h : '$h ${numberToWords(rest)}';
}

/// The three Number Bee sizes. Ranges track the level bands the app already
/// uses: K-2 counts to twenty, grades 3-4 to a hundred, older kids to 999.
enum NumberRange {
  little(0, 20, 'Little', '0 to 20'),
  big(0, 100, 'Big', '0 to 100'),
  giant(0, 999, 'Giant', '0 to 999');

  final int min;
  final int max;
  final String label;
  final String description;
  const NumberRange(this.min, this.max, this.label, this.description);

  static NumberRange forLevel(int level) {
    if (level <= 2) return NumberRange.little;
    if (level <= 4) return NumberRange.big;
    return NumberRange.giant;
  }
}

class NumberBee {
  NumberBee._();

  /// "Say the number": the pronouncer says "thirty-eight", the screen shows
  /// the digits, the child spells the word.
  static List<Word> numberRound(
    NumberRange range, {
    int count = 8,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final picked = <int>{};
    final span = range.max - range.min + 1;
    final target = math.min(count, span);
    while (picked.length < target) {
      picked.add(range.min + rng.nextInt(span));
    }
    return [
      for (final n in picked)
        Word(
          numberToWords(n),
          'The number $n.',
          'I counted $n ${n == 1 ? 'star' : 'stars'} in the sky.',
          display: '$n',
        ),
    ];
  }

  /// "Math Bee": the pronouncer asks the sum or difference, the screen shows
  /// the equation, the child works it out AND spells the answer. Nothing the
  /// hint buttons say gives the answer away.
  static List<Word> mathRound(
    NumberRange range, {
    int count = 8,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final words = <Word>[];
    final seen = <String>{};
    final cap = range == NumberRange.little
        ? 20
        : range == NumberRange.big
        ? 100
        : 999;
    var guard = 0;
    while (words.length < count && guard++ < 500) {
      final add = rng.nextBool();
      int a, b, answer;
      if (add) {
        a = rng.nextInt(cap ~/ 2 + 1);
        b = rng.nextInt(cap - a + 1);
        answer = a + b;
      } else {
        a = rng.nextInt(cap + 1);
        b = rng.nextInt(a + 1);
        answer = a - b;
      }
      if (answer > 999) continue;
      final key = '$a${add ? '+' : '-'}$b';
      if (!seen.add(key)) continue;
      final op = add ? 'plus' : 'minus';
      words.add(
        Word(
          numberToWords(answer),
          add
              ? 'Add the two numbers, then spell the answer as a word.'
              : 'Take the second number away from the first, then spell the answer as a word.',
          'Count it out on your fingers if you like — then spell what you get.',
          prompt: 'What is $a $op $b? Spell the answer.',
          display: '$a ${add ? '+' : '−'} $b = ?',
        ),
      );
    }
    return words;
  }

  /// Best-effort digits → words for spoken answers ("38" → "thirty-eight"),
  /// so a child who SAYS the number in mic mode is understood.
  static String? digitsToWords(String transcript) {
    final m = RegExp(r'^\s*(\d{1,3})\s*$').firstMatch(transcript);
    if (m == null) return null;
    final n = int.tryParse(m.group(1)!);
    if (n == null || n > 999) return null;
    return numberToWords(n);
  }
}
