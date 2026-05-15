import 'dart:convert';

import 'package:http/http.dart' as http;
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
    if (canCallRemote && theme.trim().isNotEmpty) {
      try {
        final remote = await _callGateway(
          count: count,
          level: level,
          theme: theme.trim(),
        );
        if (remote.isNotEmpty) return remote;
      } catch (_) {
        // Gracefully fall back to local words if the gateway is unavailable.
      }
    }
    return _sampleLocal(count: count, level: level);
  }

  static final Set<String> _recentlyShown = {};

  List<Word> _sampleLocal({required int count, required int level}) {
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
    final picked = source.take(count).toList();

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
