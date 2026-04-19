import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Speech-to-text wrapper for the "spell aloud" mode, where the student
/// says each letter into the mic ("C A T") and we reassemble the word.
class SttService {
  final _stt = stt.SpeechToText();
  bool _available = false;
  bool _listening = false;

  bool get listening => _listening;
  bool get available => _available;

  Future<bool> initialize() async {
    _available = await _stt.initialize(
      onStatus: (_) {},
      onError: (_) => _listening = false,
    );
    return _available;
  }

  /// Start listening. [onResult] receives the running transcript. The caller
  /// is responsible for debouncing and deciding when to stop.
  Future<void> start({
    required void Function(String transcript, bool isFinal) onResult,
  }) async {
    if (!_available) {
      final ok = await initialize();
      if (!ok) return;
    }
    _listening = true;
    await _stt.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  Future<void> stop() async {
    if (!_listening) return;
    _listening = false;
    await _stt.stop();
  }

  /// Convert an STT transcript like "C A T" or "see a tee" into a best-guess
  /// spelled word. Accepts space-separated letters, phonetic letter names,
  /// and direct spellings.
  static String normalize(String transcript) {
    final lower = transcript.trim().toLowerCase();
    if (lower.isEmpty) return '';

    // Letter-name fallbacks (covers "ay bee see" etc.)
    const names = {
      'ay': 'a', 'bee': 'b', 'see': 'c', 'dee': 'd', 'ee': 'e', 'ef': 'f',
      'gee': 'g', 'aitch': 'h', 'eye': 'i', 'jay': 'j', 'kay': 'k', 'el': 'l',
      'em': 'm', 'en': 'n', 'oh': 'o', 'pee': 'p', 'cue': 'q', 'ar': 'r',
      'es': 's', 'tee': 't', 'you': 'u', 'vee': 'v',
      'double you': 'w', 'ex': 'x', 'why': 'y', 'zee': 'z', 'zed': 'z',
    };

    final tokens = lower.split(RegExp(r'\s+'));
    final buf = StringBuffer();
    for (var t in tokens) {
      t = t.replaceAll(RegExp(r'[^a-z]'), '');
      if (t.length == 1) {
        buf.write(t);
      } else if (names.containsKey(t)) {
        buf.write(names[t]);
      } else {
        // If a whole word comes through, assume the student said the word
        // itself — just append.
        buf.write(t);
      }
    }
    return buf.toString();
  }
}
