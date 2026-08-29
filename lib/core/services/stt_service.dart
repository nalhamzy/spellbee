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

  /// Convert an STT transcript like "C A T" or "see a tee" into a best-guess
  /// spelled word. Accepts space-separated letters, phonetic letter names,
  /// and direct spellings.
  ///
  /// [target] guards against homophone traps: when the word being tested IS
  /// a letter name ("sea", "bee", "tea", "you"...), a correct transcript
  /// must not be collapsed into its letter — spelling S-E-A in an app that
  /// hears "sea" and grades "c" would be unwinnable.
  static String normalize(String transcript, {String? target}) {
    var lower = transcript.trim().toLowerCase();
    if (lower.isEmpty) return '';

    lower = lower
        .replaceAll(RegExp(r'\bdouble\s+you\b'), 'w')
        .replaceAll(RegExp(r'\bdub(?:le)?\s+you\b'), 'w');

    // Letter-name fallbacks (covers "ay bee see" etc.)
    const names = {
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

    final cleanTarget = (target ?? '').trim().toLowerCase();
    final tokens = lower.split(RegExp(r'\s+'));
    final buf = StringBuffer();
    for (var t in tokens) {
      t = t.replaceAll(RegExp(r'[^a-z]'), '');
      if (t == cleanTarget && cleanTarget.length > 1) {
        // The recognizer heard the tested word itself — keep it whole even
        // if it doubles as a letter name.
        buf.write(t);
      } else if (t.length == 1) {
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
