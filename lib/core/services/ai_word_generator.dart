import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:spellbee/core/data/themed_word_packs.dart';
import 'package:spellbee/core/data/words_catalog.dart';
import 'package:spellbee/core/models/word.dart';

/// Generates word packs through the studio gateway when configured, otherwise
/// samples the baked-in catalog. Provider keys must stay server-side.
class AiWordGenerator {
  static const _gatewayUrl = String.fromEnvironment(
    'WORD_GENERATOR_GATEWAY_URL',
  );
  static const _gatewayToken = String.fromEnvironment(
    'WORD_GENERATOR_GATEWAY_TOKEN',
  );

  static bool get canCallRemote => _gatewayUrl.isNotEmpty;

  /// Produce [count] words at approximately [level] difficulty. If [theme]
  /// is non-empty and the gateway is present, asks the studio service for a
  /// thematic pack. Otherwise samples the local catalog.
  Future<List<Word>> generate({
    required int count,
    required int level,
    String theme = '',
  }) async {
    final cleanTheme = theme.trim();
    final pack = findThemedWordPack(cleanTheme);

    if (canCallRemote && cleanTheme.isNotEmpty) {
      try {
        final remote = await _callGateway(
          count: count,
          level: level,
          theme: cleanTheme,
        );
        final vetted = _sanitizeWords(remote, count: count, pack: pack);
        if (vetted.length >= count) return _remember(vetted.take(count));
        if (pack != null) {
          return _topUpThemed(
            picked: vetted,
            count: count,
            level: level,
            pack: pack,
          );
        }
        if (vetted.isNotEmpty) {
          return _topUpGeneric(picked: vetted, count: count, level: level);
        }
      } catch (_) {
        // Gracefully fall back to local words if the gateway is unavailable.
      }
    }

    if (pack != null) {
      return _sampleLocalTheme(count: count, level: level, pack: pack);
    }

    return _sampleLocal(count: count, level: level);
  }

  List<Word> _topUpGeneric({
    required List<Word> picked,
    required int count,
    required int level,
  }) {
    final seen = picked.map((w) => w.text).toSet();
    final result = [...picked];
    for (final word in _rankedLocalCandidates(level)) {
      if (result.length >= count) break;
      if (seen.add(word.text)) result.add(word);
    }
    return _remember(result.take(count));
  }

  static final Set<String> _recentlyShown = {};

  List<Word> _sampleLocalTheme({
    required int count,
    required int level,
    required ThemedWordPack pack,
  }) {
    return _topUpThemed(
      picked: const [],
      count: count,
      level: level,
      pack: pack,
    );
  }

  List<Word> _topUpThemed({
    required List<Word> picked,
    required int count,
    required int level,
    required ThemedWordPack pack,
  }) {
    final seen = picked.map((w) => w.text).toSet();
    final source = pack.words.where((w) => !seen.contains(w.text)).toList();
    final fresh = source
        .where((w) => !_recentlyShown.contains(w.text))
        .toList();
    final candidates = fresh.length >= count - picked.length ? fresh : source;
    candidates.shuffle();
    candidates.sort((a, b) {
      final aScore = _difficultyDistance(a, level);
      final bScore = _difficultyDistance(b, level);
      return aScore.compareTo(bScore);
    });
    final result = [...picked];
    for (final word in candidates) {
      if (result.length >= count) break;
      if (seen.add(word.text)) result.add(word);
    }
    return _remember(result.take(count));
  }

  List<Word> _sampleLocal({required int count, required int level}) {
    return _remember(_rankedLocalCandidates(level).take(count));
  }

  List<Word> _rankedLocalCandidates(int level) {
    final pool = <Word>[];
    for (final l in {level - 2, level - 1, level + 1}) {
      if (kWordsCatalog.containsKey(l)) {
        pool.addAll(kWordsCatalog[l]!);
      }
    }
    if (kWordsCatalog.containsKey(level)) {
      pool.addAll(kWordsCatalog[level]!);
      pool.addAll(kWordsCatalog[level]!);
      pool.addAll(kWordsCatalog[level]!);
    }
    if (pool.isEmpty) pool.addAll(kAllWords);

    final filtered = pool
        .where((w) => !_recentlyShown.contains(w.text))
        .toList();
    final source = filtered.isNotEmpty ? filtered : pool;
    source.shuffle();
    return source;
  }

  List<Word> _remember(Iterable<Word> words) {
    final picked = words.toList();
    for (final w in picked) {
      _recentlyShown.add(w.text);
    }
    if (_recentlyShown.length > 80) {
      final oldest = _recentlyShown.take(40).toList();
      for (final t in oldest) {
        _recentlyShown.remove(t);
      }
    }
    return picked;
  }

  Future<List<Word>> _callGateway({
    required int count,
    required int level,
    required String theme,
  }) async {
    final resp = await http
        .post(
          Uri.parse(_gatewayUrl),
          headers: {
            'Content-Type': 'application/json',
            if (_gatewayToken.isNotEmpty)
              'Authorization': 'Bearer $_gatewayToken',
          },
          body: jsonEncode({
            'count': count.clamp(1, 12),
            'level': level.clamp(1, 8),
            'level_hint': _levelHint(level),
            'theme': theme,
            'purpose': 'spellbee-word-pack',
            'constraints': const {
              'single_words_only': true,
              'kid_safe': true,
              'must_match_theme': true,
              'include_definition_and_example': true,
            },
            'avoid_words': _recentlyShown.take(40).toList(),
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (resp.statusCode != 200) {
      throw Exception('Word gateway HTTP ${resp.statusCode}');
    }

    final decoded = jsonDecode(resp.body);
    final rawList = decoded is Map<String, dynamic>
        ? decoded['words'] as List? ?? const []
        : const [];

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(
          (m) => Word(
            (m['text'] as String? ?? '').toLowerCase().trim(),
            m['definition'] as String? ?? '',
            m['example'] as String? ?? '',
          ),
        )
        .where((w) => w.text.isNotEmpty)
        .take(count)
        .toList();
  }

  List<Word> _sanitizeWords(
    Iterable<Word> raw, {
    required int count,
    required ThemedWordPack? pack,
  }) {
    final seen = <String>{};
    final clean = <Word>[];
    for (final word in raw) {
      final text = word.text.toLowerCase().trim();
      if (!RegExp(r'^[a-z]{2,24}$').hasMatch(text)) continue;
      if (!seen.add(text)) continue;
      final normalized = Word(
        text,
        word.definition.trim(),
        word.example.trim(),
      );
      if (pack != null && !pack.matchesWord(normalized)) continue;
      clean.add(normalized);
      if (clean.length >= count) break;
    }
    return clean;
  }

  int _difficultyDistance(Word word, int level) {
    final target = switch (level.clamp(1, 8)) {
      1 => 3,
      2 => 5,
      3 => 6,
      4 => 8,
      5 => 9,
      6 => 11,
      7 => 12,
      _ => 14,
    };
    final lengthDistance = (word.text.length - target).abs();
    final complexityBonus = math.max(0, word.text.length - 12);
    return lengthDistance + complexityBonus;
  }

  String _levelHint(int l) {
    switch (l) {
      case 1:
        return 'K to grade 1, 3-4 letter words';
      case 2:
        return '2nd grade';
      case 3:
        return '3rd grade';
      case 4:
        return '4th grade';
      case 5:
        return '5th grade';
      case 6:
        return 'middle school';
      case 7:
        return 'regional spelling bee';
      case 8:
        return 'Scripps national spelling bee';
    }
    return 'elementary school';
  }
}
