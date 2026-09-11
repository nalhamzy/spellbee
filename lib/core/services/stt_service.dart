import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// What the microphone is doing right now, so the UI can tell the child the
/// truth instead of showing a hot mic that stopped listening seconds ago.
enum SttStatus { idle, listening, denied, error }

/// Speech-to-text wrapper for the "spell aloud" mode, where the student
/// says each letter into the mic ("C A T") and we reassemble the word.
///
/// A [ChangeNotifier] because the platform recognizer stops on its own
/// (silence timeout, errors, permission dialogs) and the test screen must
/// follow along — a plain field flip nobody observes leaves the big mic
/// button lying to the kid.
class SttService extends ChangeNotifier {
  final _stt = stt.SpeechToText();
  bool _available = false;
  SttStatus _status = SttStatus.idle;

  // speech_to_text's Android side keeps ONE pending platform Result for
  // initialize/permission. Re-entering initialize() while the permission
  // dialog is still up replaces that Result, and the dialog's callback then
  // answers the stale one — the IllegalStateException("Reply already
  // submitted") crash from production. Single-flight the call.
  Future<bool>? _initFuture;

  bool get listening => _status == SttStatus.listening;
  bool get available => _available;
  SttStatus get status => _status;

  Future<bool> initialize() {
    return _initFuture ??= _initOnce();
  }

  Future<bool> _initOnce() async {
    try {
      _available = await _stt.initialize(
        onStatus: (s) {
          // The recognizer times out on silence and reports 'notListening' /
          // 'done' without any call from us.
          if (_status == SttStatus.listening &&
              (s == 'notListening' || s == 'done')) {
            _setStatus(SttStatus.idle);
          }
        },
        onError: (e) {
          _setStatus(
            e.errorMsg == 'error_permission' || e.errorMsg == 'error_denied'
                ? SttStatus.denied
                : SttStatus.error,
          );
        },
      );
    } catch (_) {
      _available = false;
    }
    if (!_available) {
      _setStatus(SttStatus.denied);
      // Permission may be granted later from system settings; allow retry.
      _initFuture = null;
    }
    return _available;
  }

  /// Start listening. [onResult] receives the running transcript. The caller
  /// is responsible for debouncing and deciding when to stop.
  ///
  /// Returns true when the recognizer actually started.
  Future<bool> start({
    required void Function(String transcript, bool isFinal) onResult,
  }) async {
    if (!_available) {
      final ok = await initialize();
      if (!ok) return false;
    }
    try {
      await _stt.listen(
        onResult: (r) => onResult(r.recognizedWords, r.finalResult),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
      );
      _setStatus(SttStatus.listening);
      return true;
    } catch (_) {
      _setStatus(SttStatus.error);
      return false;
    }
  }

  Future<void> stop() async {
    if (_status != SttStatus.listening) return;
    _setStatus(SttStatus.idle);
    try {
      await _stt.stop();
    } catch (_) {
      // Recognizer already gone — nothing to stop.
    }
  }

  void _setStatus(SttStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  /// Letter names the recognizer returns instead of bare letters. Many are
  /// also ordinary words ("sea", "you", "why"), which is exactly why a
  /// transcript has to be classified rather than blindly rewritten.
  static const _letterNames = {
    'ay': 'a',
    'bee': 'b',
    'see': 'c',
    'dee': 'd',
    'ee': 'e',
    'ef': 'f',
    'gee': 'g',
    'aitch': 'h',
    'eye': 'i',
    'jay': 'j',
    'kay': 'k',
    'el': 'l',
    'em': 'm',
    'en': 'n',
    'oh': 'o',
    'pee': 'p',
    'cue': 'q',
    'ar': 'r',
    'es': 's',
    'tee': 't',
    'you': 'u',
    'vee': 'v',
    'be': 'b',
    'sea': 'c',
    'tea': 't',
    'queue': 'q',
    'ex': 'x',
    'why': 'y',
    'zee': 'z',
    'zed': 'z',
  };

  static List<String> _tokenize(String transcript) {
    final lower = transcript
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\bdouble\s+you\b'), 'w')
        .replaceAll(RegExp(r'\bdub(?:le)?\s+you\b'), 'w');
    if (lower.isEmpty) return const [];
    return lower
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static bool _isLetterToken(String t) =>
      (t.length == 1 && RegExp(r'[a-z]').hasMatch(t)) ||
      _letterNames.containsKey(t);

  static String _asLetter(String t) =>
      t.length == 1 ? t : (_letterNames[t] ?? '');

  /// Best-effort letters for DISPLAY only — what to echo back under the mic
  /// while a child is still speaking. Never grade with this: it cannot tell
  /// "C-A-T" from "cat". Use [classify] to score an answer.
  static String normalize(String transcript, {String? target}) {
    final tokens = _tokenize(transcript);
    final buf = StringBuffer();
    for (final t in tokens) {
      if (_isLetterToken(t)) {
        buf.write(_asLetter(t));
      } else {
        buf.write(t.replaceAll(RegExp(r'[^a-z]'), ''));
      }
    }
    return buf.toString();
  }

  /// Read a transcript as a spelling attempt.
  ///
  /// [target] is the plain-letters answer ("thirtyeight", "cat"). The whole
  /// point of the app is that a child SPELLS: saying "cat" for *cat*, or
  /// "thirty-eight" / "38" for *thirty-eight*, is not an answer and must
  /// never be scored as one — it comes back as [SpokenAnswerKind.wholeWord]
  /// so the caller can ask for the letters instead of awarding the point.
  /// [spokenNumber] turns a digit string into the letters of its number
  /// word ("38" -> "thirtyeight"), so reading a number aloud is recognised
  /// as saying it. Passed in by the Number Bee; omit it elsewhere.
  static SpokenAnswer classify(
    String transcript, {
    required String target,
    String? Function(String digits)? spokenNumber,
  }) {
    final tokens = _tokenize(transcript);
    if (tokens.isEmpty) return const SpokenAnswer(SpokenAnswerKind.empty);

    final goal = target.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final heard = tokens.join(' ');

    // A genuine spelling: every token is a letter or a letter name. Checked
    // first so "s e a" reads as S-E-A even though it also spells the target.
    final letterTokens = tokens.where(_isLetterToken).toList();
    final spelled = letterTokens.map(_asLetter).join();
    final spellingShape = letterTokens.length == tokens.length;
    if (spellingShape && (tokens.length >= 2 || goal.length <= 1)) {
      return SpokenAnswer(
        SpokenAnswerKind.letters,
        letters: spelled,
        heard: heard,
        isSpellingShape: true,
      );
    }

    // The word itself, spoken rather than spelled — including digits, since
    // the recognizer returns "38" when a child reads a number aloud.
    final saidWord = tokens.map((t) => t.replaceAll(RegExp(r'[^a-z]'), '')).join();
    final digits = tokens.join();
    final asNumber = RegExp(r'^\d{1,3}$').hasMatch(digits)
        ? spokenNumber?.call(digits)
        : null;
    if (saidWord == goal || (asNumber != null && asNumber == goal)) {
      return SpokenAnswer(
        SpokenAnswerKind.wholeWord,
        letters: spelled,
        heard: heard,
        isSpellingShape: spellingShape,
      );
    }

    return SpokenAnswer(
      SpokenAnswerKind.unclear,
      letters: spelled,
      heard: heard,
      isSpellingShape: spellingShape,
    );
  }

}

/// How a transcript reads once classified.
enum SpokenAnswerKind {
  /// Nothing usable was heard.
  empty,

  /// A real letter-by-letter attempt. [SpokenAnswer.letters] is the guess.
  letters,

  /// The child said the whole word (or read the number) instead of spelling
  /// it. Not a wrong answer — not an answer at all.
  wholeWord,

  /// Speech that is neither letters nor the target word.
  unclear,
}

class SpokenAnswer {
  final SpokenAnswerKind kind;

  /// Letters assembled from whatever letter tokens were heard. Safe to show
  /// while listening; only graded when [kind] is [SpokenAnswerKind.letters].
  final String letters;

  /// A readable echo of what the recognizer returned, for the nudge copy.
  final String heard;

  /// Every token read as a letter or a letter name — the child was spelling,
  /// even if only one letter has arrived so far. Lets the mic echo a
  /// half-finished spelling without implying it has been accepted.
  final bool isSpellingShape;

  const SpokenAnswer(
    this.kind, {
    this.letters = '',
    this.heard = '',
    this.isSpellingShape = false,
  });
}
