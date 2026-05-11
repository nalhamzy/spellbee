import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:spellbee/core/data/words_catalog.dart';
import 'package:spellbee/core/models/word.dart';

/// Generates word packs either via Gemini (if GEMINI_API_KEY is passed via
/// --dart-define) or by sampling the baked-in catalog as a deterministic
/// fallback. Free tier users get local-only generation; premium users can
/// tap Gemini for thematic packs.
class AiWordGenerator {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static bool get canCallRemote => _apiKey.isNotEmpty;

  /// Produce [count] words at approximately [level] difficulty. If [theme]
  /// is non-empty and an API key is present, calls Gemini. Otherwise samples
  /// the catalog.
  Future<List<Word>> generate({
    required int count,
    required int level,
    String theme = '',
  }) async {
    if (canCallRemote && theme.trim().isNotEmpty) {
      try {
        final remote = await _callGemini(
          count: count,
          level: level,
          theme: theme.trim(),
        );
        if (remote.isNotEmpty) return remote;
      } catch (_) {
        // fall through to local
      }
    }
    return _sampleLocal(count: count, level: level);
  }

  // ── Local fallback ─────────────────────────────────────────────────

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

  // ── Gemini ──────────────────────────────────────────────────────────

  Future<List<Word>> _callGemini({
    required int count,
    required int level,
    required String theme,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-1.5-flash:generateContent?key=$_apiKey',
    );
    final prompt =
        'Generate exactly $count spelling-bee words for a level-$level '
        '(${_levelHint(level)}) student, themed around "$theme". '
        'Return STRICT JSON in this shape and nothing else: '
        '{"words":[{"text":"word","definition":"short definition",'
        '"example":"one-sentence example using the word"}]}. '
        'Use real words. Make sure the difficulty matches the level. '
        'No prefaces, no code fences, no explanations.';
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {'response_mime_type': 'application/json'},
    });
    final resp = await http
        .post(url,
            headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 25));
    if (resp.statusCode != 200) {
      throw Exception('Gemini HTTP ${resp.statusCode}');
    }
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    final text = (((j['candidates'] as List?)?.firstOrNull as Map?)
            ?['content']?['parts']?[0]?['text']) as String?;
    if (text == null) return const [];
    final inner = jsonDecode(text) as Map<String, dynamic>;
    final rawList = inner['words'] as List? ?? const [];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map((m) => Word(
              (m['text'] as String? ?? '').toLowerCase().trim(),
              m['definition'] as String? ?? '',
              m['example'] as String? ?? '',
            ))
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
