import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/data/voice_phrase_bank.dart';
import 'package:spellbee/core/data/word_facts.dart';
import 'package:spellbee/core/models/progression.dart';
import 'package:spellbee/core/models/test_result.dart';
import 'package:spellbee/core/models/word.dart';
import 'package:spellbee/core/services/stt_service.dart';
import 'package:spellbee/core/services/tts_service.dart' show TtsService;
import 'package:spellbee/core/utils/number_words.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/results_screen.dart';
import 'package:spellbee/widgets/letter_tiles.dart';

enum InputMode { keyboard, mic, tiles }

/// Per-item run-state. We keep one of these for each word in [TestScreen.words]
/// so the player can navigate back and forth without losing progress.
class _ItemState {
  String typed = '';
  String sttTranscript = '';
  bool revealed = false;
  bool? correct;
  bool submitted = false;
  bool attempted = false;

  /// True once ANY submission of this word was wrong — survives "Try again",
  /// so the coach's missed-word counts see the words a kid struggled with
  /// even when they eventually got them right.
  bool missedOnce = false;

  /// Which input answered this word correctly (mode quests + badges).
  InputMode? answeredWith;
  bool factOpened = false;
  TileBoard? tiles;
  Timer? autoAdvance;
}

class TestScreen extends ConsumerStatefulWidget {
  final List<Word> words;
  final String title;
  final bool savesStats;
  final String? sourceListId;
  final RoundKind kind;
  final int? level;
  final InputMode initialMode;

  /// Optional callback invoked after stats are saved and the test completes
  /// successfully (all words answered). Used by the daily-word flow to
  /// trigger streak tracking.
  final FutureOr<void> Function()? onComplete;

  const TestScreen({
    super.key,
    required this.words,
    required this.title,
    this.savesStats = true,
    this.sourceListId,
    this.onComplete,
    this.kind = RoundKind.practice,
    this.level,
    this.initialMode = InputMode.keyboard,
  });

  @override
  ConsumerState<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends ConsumerState<TestScreen>
    with WidgetsBindingObserver {
  late final List<_ItemState> _items;
  int _idx = 0;
  late InputMode _mode = widget.initialMode;

  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  int _longestStreak = 0;
  DateTime? _startedAt;
  String? _lastFeedbackStub;

  /// Serializes navigation. _next/_previous await async stops before
  /// mutating _idx; a kid's double-tap (or the auto-advance timer racing a
  /// tap) used to run the body twice — skipping a word mid-list and
  /// double-counting the whole test in stats on the last one.
  bool _navigating = false;

  /// Bumped on every navigation so a hands-free listen scheduled for word N
  /// cannot open the mic after the kid already moved to word N+1.
  int _speakEpoch = 0;

  // Resolved once in initState. Riverpod 3 throws a StateError from `ref`
  // once the element is unmounted — and State.dispose() runs exactly then —
  // so a `ref.read` in dispose aborted the whole teardown: the text
  // controller, the focus node, the auto-advance timer, and the
  // microphone were all left running when a kid quit a round.
  late final TtsService _tts;
  late final SttService _stt;

  Word get _w => widget.words[_idx];
  _ItemState get _s => _items[_idx];
  bool get _isLast => _idx >= widget.words.length - 1;
  bool get _isFirst => _idx <= 0;
  bool get _premium => ref.read(isPremiumProvider);
  bool get _isNumberRound =>
      widget.kind == RoundKind.numbers || widget.kind == RoundKind.math;
  int get _runStreak {
    var s = 0;
    for (final it in _items.take(_idx + 1)) {
      if (it.revealed && (it.correct ?? false)) {
        s++;
      } else if (it.revealed) {
        s = 0;
      }
    }
    return s;
  }

  @override
  void initState() {
    super.initState();
    _items = List.generate(widget.words.length, (_) => _ItemState());
    _startedAt = DateTime.now();
    _tts = ref.read(ttsServiceProvider);
    _stt = ref.read(sttServiceProvider);
    WidgetsBinding.instance.addObserver(this);
    // The mic state machine lives in SttService (silence timeouts and
    // errors flip it without any call from us); mirror every change.
    _stt.addListener(_onSttChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  void _onSttChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Backgrounding mid-test must release the microphone (a hot mic in a
      // kids app is not acceptable) and freeze auto-advance.
      _s.autoAdvance?.cancel();
      _speakEpoch++;
      _tts.stop();
      _stt.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stt.removeListener(_onSttChanged);
    _ctrl.dispose();
    _focus.dispose();
    for (final it in _items) {
      it.autoAdvance?.cancel();
    }
    _tts.stop();
    _stt.stop();
    super.dispose();
  }

  // ── TTS ────────────────────────────────────────────────────────────

  /// Say the current item, then (hands-free mode) open the mic once the
  /// pronouncer is done so the child never has to reach for the button.
  Future<void> _speak() async {
    final epoch = ++_speakEpoch;
    final tts = _tts;
    final prompt = _w.prompt;
    if (prompt != null) {
      await tts.speakText(prompt, premium: _premium);
    } else {
      await tts.speakWord(_w.text, premium: _premium);
    }
    if (!mounted || epoch != _speakEpoch) return;
    if (_mode == InputMode.mic &&
        !_s.revealed &&
        ref.read(autoListenProvider) &&
        !_stt.listening) {
      // A short gap so the recognizer does not catch the tail of the voice.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted || epoch != _speakEpoch || _s.revealed) return;
      await _toggleMic();
    }
  }

  Future<void> _speakDefinition() async {
    final tts = _tts;
    if (_w.prompt != null) {
      // Math items: the definition is a strategy hint, not "{word} means…"
      // — the template would read the answer aloud.
      await tts.speakText(_w.definition, premium: _premium);
      return;
    }
    await tts.speakDefinition(_w.text, _w.definition, premium: _premium);
  }

  Future<void> _speakExample() async {
    final tts = _tts;
    if (_w.prompt != null) {
      await tts.speakText(_w.example, premium: _premium);
      return;
    }
    await tts.speakExample(_w.text, _w.example, premium: _premium);
  }

  Future<void> _speakSpellOut() async {
    await _tts.spellOut(_w.text, premium: _premium);
  }

  // ── Input handling ─────────────────────────────────────────────────

  bool _micBusy = false;

  static final _repeatCommand = RegExp(
    r'\b(repeat|again|say it again|one more time|pardon)\b',
  );

  Future<void> _toggleMic() async {
    if (_micBusy) return; // ignore taps while init/permission is pending
    final stt = _stt;
    if (stt.listening) {
      await stt.stop();
      if (mounted) setState(() {});
      return;
    }
    setState(() => _micBusy = true);
    final started = await stt.start(
      onResult: (transcript, isFinal) {
        if (!mounted) return;
        // Voice command: "repeat" / "again" re-reads the word instead of
        // being graded as an attempt. Only honoured while nothing else has
        // been said, so a kid mid-spelling is never interrupted.
        final lower = transcript.toLowerCase().trim();
        if (isFinal &&
            _s.sttTranscript.isEmpty &&
            lower.split(' ').length <= 4 &&
            _repeatCommand.hasMatch(lower)) {
          stt.stop().then((_) {
            if (mounted) setState(() {});
            _speak();
          });
          return;
        }
        setState(() => _s.sttTranscript = transcript);
        if (isFinal) {
          stt.stop().then((_) {
            if (!mounted) return;
            setState(() {});
            // Hands-free: the recognizer's final result IS the answer —
            // grade it so the loop is hear → say → next with no taps.
            if (ref.read(autoListenProvider) &&
                !_s.revealed &&
                _s.sttTranscript.trim().isNotEmpty) {
              _submit();
            }
          });
        }
      },
    );
    if (!mounted) return;
    setState(() => _micBusy = false);
    if (!started && stt.status == SttStatus.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "We can't hear you yet — ask a grown-up to allow the "
            'microphone in Settings, or switch to typing.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  /// Clear the current word's input and go back to "not attempted" state.
  /// Works for every input, before or after reveal.
  Future<void> _clearAndRetry() async {
    _s.autoAdvance?.cancel();
    await _tts.stop();
    await _stt.stop();
    setState(() {
      _s.typed = '';
      _s.sttTranscript = '';
      _s.revealed = false;
      _s.correct = null;
      _s.submitted = false;
      _s.tiles?.clear();
      _ctrl.clear();
    });
    if (_mode == InputMode.keyboard) {
      _focus.requestFocus();
    }
    await _playFeedback(VoicePhraseBank.retry);
    // Re-speak the word so they hear it fresh.
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _speak();
    });
  }

  void _onTyped(String v) {
    // setState so text-dependent chrome (the "Clear & redo" row, the enabled
    // look of the check button) tracks every keystroke.
    setState(() => _s.typed = v);
  }

  TileBoard _tilesFor(_ItemState s, Word w) => s.tiles ??= TileBoard.forWord(
    w.letters,
  );

  void _setMode(InputMode m) {
    if (_mode == m) return;
    _speakEpoch++;
    _stt.stop();
    setState(() => _mode = m);
    if (m == InputMode.keyboard && !_s.revealed) _focus.requestFocus();
  }

  String _currentAnswer() {
    switch (_mode) {
      case InputMode.keyboard:
        return _normalizeTyped(_ctrl.text);
      case InputMode.tiles:
        return _tilesFor(_s, _w).built;
      case InputMode.mic:
        final raw = _s.sttTranscript;
        if (_isNumberRound) {
          // "38" said aloud in a number round is the right answer to
          // "thirty-eight"; the recognizer likes returning digits.
          final asWords = NumberBee.digitsToWords(raw);
          if (asWords != null) return _normalizeTyped(asWords);
        }
        return _normalizeTyped(
          SttService.normalize(raw, target: _w.text),
        );
    }
  }

  void _submit() {
    if (_s.revealed) return;
    final typed = _currentAnswer();

    if (typed.isEmpty) {
      // An empty submit must not read as "the app is broken" to a child:
      // nudge with words, not silence.
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (_mode) {
            InputMode.keyboard => 'Type the word first, then check it!',
            InputMode.mic => 'Tap the mic and spell the word out loud first!',
            InputMode.tiles => 'Tap the letter tiles to build the word first!',
          }),
          duration: const Duration(seconds: 2),
        ),
      );
      if (_mode == InputMode.keyboard) _focus.requestFocus();
      return;
    }

    final correct = typed == _w.letters;
    setState(() {
      _s.revealed = true;
      _s.correct = correct;
      _s.submitted = true;
      _s.attempted = true;
      if (_mode == InputMode.tiles) _s.typed = typed;
      if (!correct) _s.missedOnce = true;
      _s.answeredWith = correct ? _mode : null;
    });

    // Update longest streak tracker.
    final s = _runStreak;
    if (s > _longestStreak) _longestStreak = s;

    // Haptic where supported (mobile only — no-op on web/desktop).
    try {
      if (correct) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (_) {}

    // Voice feedback + auto-advance.
    if (correct) {
      _playFeedback(
        _runStreak >= 3 ? VoicePhraseBank.streak : VoicePhraseBank.correct,
      );
      // Words with a fact get a longer pause — the card is worth reading.
      final hasFact = factFor(_w.text) != null;
      _s.autoAdvance = Timer(
        Duration(milliseconds: hasFact ? 3200 : 1800),
        () {
          if (mounted && _s.revealed && !_s.factOpened) _next();
        },
      );
    } else {
      _playFeedback(VoicePhraseBank.miss);
      // Spell it out 0.9s in.
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted && _s.revealed) _speakSpellOut();
      });
      // On a miss, do NOT auto-advance — let the kid read the reveal
      // and optionally tap "Try again" to redo, or "Next" to move on.
    }
  }

  Future<void> _playFeedback(List<String> stubs) async {
    final stub = VoicePhraseBank.pick(stubs, avoid: _lastFeedbackStub);
    _lastFeedbackStub = stub;
    await _tts.playPhrase(stub, premium: _premium);
  }

  Future<void> _openFact(String fact) async {
    _s.autoAdvance?.cancel();
    if (!_s.factOpened) {
      setState(() => _s.factOpened = true);
      if (widget.savesStats) {
        // Facts count toward the "curious bee" quest; the tiny reward is
        // acknowledged on the results card, not with a popup mid-round.
        unawaited(ref.read(progressionProvider.notifier).recordFactRead());
      }
    }
    final tts = _tts;
    await tts.stop();
    await tts.speakText(fact, premium: _premium);
  }

  // ── Navigation ─────────────────────────────────────────────────────

  void _previous() {
    if (_isFirst || _navigating) return;
    _navigating = true;
    _s.autoAdvance?.cancel();
    _speakEpoch++;
    _tts.stop();
    _stt.stop();
    setState(() {
      _idx -= 1;
      _ctrl.text = _s.typed;
      _ctrl.selection = TextSelection.collapsed(offset: _s.typed.length);
    });
    _navigating = false;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _speak();
    });
  }

  Future<void> _next() async {
    if (_navigating) return;
    _navigating = true;
    try {
      _s.autoAdvance?.cancel();
      _speakEpoch++;
      await _tts.stop();
      await _stt.stop();
      if (!mounted) return;
      if (_isLast) {
        await _finish();
        return;
      }
      setState(() {
        _idx += 1;
        _ctrl.text = _s.typed;
        _ctrl.selection = TextSelection.collapsed(offset: _s.typed.length);
      });
      // Bring the keyboard straight back for the new word — a 10-word test
      // should not cost nine extra taps on the text field.
      if (_mode == InputMode.keyboard && !_s.revealed) {
        _focus.requestFocus();
      }
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _speak();
      });
    } finally {
      _navigating = false;
    }
  }

  void _skip() {
    if (_navigating) return;
    if (_s.revealed) {
      _next();
      return;
    }
    setState(() {
      _s.revealed = true;
      _s.correct = false;
      _s.submitted = true;
      _s.attempted = true;
      _s.missedOnce = true;
      _s.typed = '';
      _s.sttTranscript = '';
      _s.answeredWith = null;
    });
    _next();
  }

  Future<void> _finish() async {
    final items = <AskedItem>[];
    var micCorrect = 0;
    var tilesCorrect = 0;
    for (var i = 0; i < widget.words.length; i++) {
      final it = _items[i];
      final target = widget.words[i].text;
      final submitted = it.typed.isNotEmpty
          ? _normalizeTyped(it.typed)
          : _normalizeTyped(
              SttService.normalize(it.sttTranscript, target: target),
            );
      items.add(
        AskedItem(
          target: target,
          definition: widget.words[i].definition,
          example: widget.words[i].example,
          submitted: submitted,
          isCorrect: it.correct ?? false,
        ),
      );
      if (it.answeredWith == InputMode.mic) micCorrect++;
      if (it.answeredWith == InputMode.tiles) tilesCorrect++;
    }
    final result = TestResult(
      items: items,
      elapsed: DateTime.now().difference(_startedAt!),
      endedAt: DateTime.now(),
      kind: widget.kind,
      longestStreak: _longestStreak,
      micCorrect: micCorrect,
      tilesCorrect: tilesCorrect,
      level: widget.level,
    );
    ProgressionOutcome? outcome;
    if (widget.savesStats) {
      // A word counts as missed if ANY attempt on it was wrong, even when
      // "Try again" ended in success — those are exactly the words the
      // coach's focus round exists for. Mastery only decrements the counter
      // for words that were clean on the first try.
      final struggled = <String>[];
      final clean = <String>[];
      for (var i = 0; i < widget.words.length; i++) {
        final it = _items[i];
        final target = widget.words[i].text;
        if (it.missedOnce || !(it.correct ?? false)) {
          struggled.add(target);
        } else {
          clean.add(target);
        }
      }
      await ref
          .read(playerStatsProvider.notifier)
          .recordTestComplete(
            asked: result.total,
            correct: result.correct,
            longestStreak: _longestStreak,
            missedWords: struggled,
            masteredWords: clean,
            listId: widget.sourceListId,
          );
    }
    // The daily-word streak is for SPELLING the word, not for opening the
    // test — a skip or a miss keeps the card active so the kid can retry.
    if (result.correct == result.total) {
      await widget.onComplete?.call();
    }
    if (widget.savesStats) {
      // After stats and the daily streak so badge thresholds see today.
      outcome = await ref
          .read(progressionProvider.notifier)
          .recordRound(result);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          result: result,
          title: widget.title,
          outcome: outcome,
        ),
      ),
    );
  }

  String _normalizeTyped(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  // ── Hints ──────────────────────────────────────────────────────────

  Future<void> _showHintMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HintSheet(
        word: _w,
        onSlowRepeat: () {
          Navigator.pop(ctx);
          _slowRepeat();
        },
        onSpellOut: () {
          Navigator.pop(ctx);
          _speakSpellOut();
        },
        onFirstLetter: () {
          Navigator.pop(ctx);
          _revealFirstLetter();
        },
      ),
    );
  }

  Future<void> _slowRepeat() async {
    // Temporarily force Calm speed for this single read. Skip the bundled
    // MP3s — they are recorded at one fixed speed, so routing through them
    // made "say it slower" audibly identical for the ~60 most common words.
    final tts = _tts;
    final previous = ref.read(voiceSpeedProvider);
    _speakEpoch++;
    await tts.setSpeed(VoiceSpeed.calm);
    final prompt = _w.prompt;
    if (prompt != null) {
      await tts.speakText(prompt, premium: _premium);
    } else {
      await tts.speakWord(_w.text, premium: _premium, skipBundled: true);
    }
    // Restore user's chosen speed afterward.
    await tts.setSpeed(previous);
  }

  void _revealFirstLetter() {
    final first = _w.letters.substring(0, 1);
    if (_mode == InputMode.keyboard) {
      if (!_s.typed.toLowerCase().startsWith(first)) {
        _ctrl.text = first;
        _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
        _s.typed = _ctrl.text;
        _focus.requestFocus();
      }
    } else if (_mode == InputMode.tiles) {
      final board = _tilesFor(_s, _w);
      if (board.isEmpty) {
        final i = board.tray.indexOf(first);
        if (i >= 0) {
          board.place(i);
          setState(() => _s.typed = board.built);
        }
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starts with "${first.toUpperCase()}"'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final progress = (_idx + 1) / widget.words.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Quit test',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Hint',
            icon: const Icon(Icons.lightbulb_outline_rounded),
            onPressed: _showHintMenu,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
        child: SafeArea(
          child: ResponsiveContentBox(
            child: Padding(
              padding: EdgeInsets.all(context.s(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _topBar(progress),
                          SizedBox(height: context.s(14)),
                          _HearCard(
                            display: _w.display,
                            isMath: widget.kind == RoundKind.math,
                            onHearWord: _speak,
                            onHearDefinition: _speakDefinition,
                            onHearExample: _speakExample,
                          ),
                          SizedBox(height: context.s(16)),
                          _modeToggle(),
                          SizedBox(height: context.s(16)),
                          switch (_mode) {
                            InputMode.keyboard => _keyboardInput(),
                            InputMode.mic => _micInput(),
                            InputMode.tiles => _tilesInput(),
                          },
                          SizedBox(height: context.s(10)),
                          _inputRetryRow(),
                          SizedBox(height: context.s(14)),
                          if (_s.revealed) _revealCard(),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: context.s(12)),
                  _bottomActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(double progress) {
    return Container(
      padding: EdgeInsets.all(context.s(12)),
      decoration: AppTheme.card(
        gradient: AppTheme.surfaceLiftGradient,
        radius: context.s(20),
        shadow: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _isFirst ? null : _previous,
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous word',
                style: IconButton.styleFrom(
                  backgroundColor: _isFirst ? AppTheme.surface2 : AppTheme.mint,
                  foregroundColor: _isFirst ? AppTheme.mute : AppTheme.ink,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(context.s(8)),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: context.s(10),
                        backgroundColor: AppTheme.surface2,
                        color: AppTheme.sage,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Word ${_idx + 1} of ${widget.words.length} - Streak $_runStreak',
                      style: const TextStyle(
                        color: AppTheme.mute,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _skip,
                icon: const Icon(Icons.skip_next_rounded, size: 18),
                label: const Text('Skip'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.mute),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeToggle() {
    return Container(
      padding: EdgeInsets.all(context.s(4)),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        gradient: AppTheme.surfaceLiftGradient,
        border: Border.all(color: AppTheme.outline),
        borderRadius: BorderRadius.circular(context.s(18)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeChip(
              label: 'Type',
              icon: Icons.keyboard_alt_rounded,
              selected: _mode == InputMode.keyboard,
              onTap: () => _setMode(InputMode.keyboard),
            ),
          ),
          Expanded(
            child: _ModeChip(
              label: 'Tiles',
              icon: Icons.grid_view_rounded,
              selected: _mode == InputMode.tiles,
              onTap: () => _setMode(InputMode.tiles),
            ),
          ),
          Expanded(
            child: _ModeChip(
              label: 'Aloud',
              icon: Icons.mic_rounded,
              selected: _mode == InputMode.mic,
              onTap: () => _setMode(InputMode.mic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _keyboardInput() {
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      autofocus: true,
      textInputAction: TextInputAction.done,
      onChanged: _onTyped,
      onSubmitted: (_) => _submit(),
      enabled: !_s.revealed,
      textCapitalization: TextCapitalization.none,
      style: TextStyle(
        fontSize: context.s(30),
        fontWeight: FontWeight.w700,
        color: AppTheme.ink,
        letterSpacing: 1.5,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppTheme.surface,
        hintText: _isNumberRound ? 'spell the number word' : 'spell the word',
        hintStyle: TextStyle(
          fontSize: context.s(18),
          color: AppTheme.mute,
          letterSpacing: 0.5,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.s(16),
          vertical: context.s(16),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.s(14)),
          borderSide: const BorderSide(color: AppTheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.s(14)),
          borderSide: const BorderSide(color: AppTheme.honey, width: 2),
        ),
      ),
    );
  }

  Widget _tilesInput() {
    final board = _tilesFor(_s, _w);
    return LetterTilesInput(
      board: board,
      enabled: !_s.revealed,
      correct: _s.revealed ? _s.correct : null,
      onChanged: () => setState(() => _s.typed = board.built),
    );
  }

  Widget _micInput() {
    final stt = ref.watch(sttServiceProvider);
    final autoListen = ref.watch(autoListenProvider);
    final normalized = SttService.normalize(_s.sttTranscript, target: _w.text);
    final shown = _isNumberRound
        ? (NumberBee.digitsToWords(_s.sttTranscript) ?? normalized)
        : normalized;
    return Column(
      children: [
        GestureDetector(
          onTap: _s.revealed ? null : _toggleMic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: context.s(110),
            height: context.s(110),
            decoration: BoxDecoration(
              color: stt.listening ? AppTheme.coral : AppTheme.honey,
              gradient: stt.listening
                  ? AppTheme.errorGradient
                  : AppTheme.ctaGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (stt.listening ? AppTheme.coral : AppTheme.honey)
                      .withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: stt.listening ? 6 : 0,
                ),
              ],
            ),
            child: Icon(
              stt.listening ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: context.s(56),
            ),
          ),
        ),
        SizedBox(height: context.s(12)),
        Text(
          shown.isEmpty
              ? (stt.listening
                    ? 'Listening… say each letter'
                    : autoListen
                    ? 'Say each letter slowly'
                    : 'Tap and say each letter slowly')
              : shown.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: context.s(22),
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
            letterSpacing: 3,
          ),
        ),
        if (shown.isEmpty) ...[
          SizedBox(height: context.s(6)),
          Text(
            autoListen
                ? 'Hands-free: the mic opens after each word and checks when you stop. Say "repeat" to hear it again.'
                : 'Say "repeat" to hear the word again.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.mute, fontSize: 12),
          ),
        ],
      ],
    );
  }

  /// Small "Clear & redo" link under the input — exactly what kids need
  /// when background noise messes up the mic, or when they typo early.
  Widget _inputRetryRow() {
    final hasInput = switch (_mode) {
      InputMode.keyboard => _ctrl.text.isNotEmpty,
      InputMode.mic => _s.sttTranscript.isNotEmpty,
      InputMode.tiles => !(_s.tiles?.isEmpty ?? true),
    };
    if (!hasInput && !_s.revealed) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: _clearAndRetry,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: Text(_s.revealed ? 'Try this word again' : 'Clear & redo'),
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.honeyDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _revealCard() {
    final ok = _s.correct ?? false;
    final fact = factFor(_w.text);
    return Container(
      padding: EdgeInsets.all(context.s(16)),
      decoration: BoxDecoration(
        color: ok ? AppTheme.mint : AppTheme.rose,
        gradient: ok ? AppTheme.successGradient : AppTheme.errorGradient,
        border: Border.all(
          color: ok ? AppTheme.sage : AppTheme.coral,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(context.s(20)),
        boxShadow: AppTheme.tintedShadow(ok ? AppTheme.sage : AppTheme.coral),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: ok ? AppTheme.sage : AppTheme.coral,
              ),
              SizedBox(width: context.s(8)),
              Text(
                ok ? 'Correct!' : 'Not quite',
                style: TextStyle(
                  color: ok ? AppTheme.sage : AppTheme.coral,
                  fontSize: context.s(18),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: context.s(8)),
          Text(
            widget.kind == RoundKind.math
                ? 'The answer is "${_w.text}"'
                : 'The word is "${_w.text}"',
            style: TextStyle(
              fontSize: context.s(16),
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          if (_w.definition.isNotEmpty && _w.prompt == null) ...[
            SizedBox(height: context.s(4)),
            Text(
              _w.definition,
              style: const TextStyle(color: AppTheme.mute, fontSize: 13),
            ),
          ],
          if (fact != null) ...[
            SizedBox(height: context.s(12)),
            _FactChip(
              fact: fact,
              opened: _s.factOpened,
              onTap: () => _openFact(fact),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomActions() {
    // Three states:
    //   1. not revealed → "Check my spelling" (primary)
    //   2. revealed + correct → "Next word" (primary)
    //   3. revealed + miss → row of [Try again] [Next]
    if (!_s.revealed) {
      final ready = switch (_mode) {
        InputMode.tiles => _s.tiles?.isFull ?? false,
        InputMode.keyboard => _ctrl.text.isNotEmpty,
        InputMode.mic => _s.sttTranscript.isNotEmpty,
      };
      return SizedBox(
        width: double.infinity,
        height: context.s(56),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ready ? AppTheme.honey : AppTheme.surface2,
            foregroundColor: AppTheme.ink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.s(16)),
            ),
          ),
          onPressed: _submit,
          child: Text(
            widget.kind == RoundKind.math
                ? 'Check my answer'
                : 'Check my spelling',
            style: TextStyle(
              fontSize: context.s(16),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    final correct = _s.correct ?? false;
    if (correct) {
      return SizedBox(
        width: double.infinity,
        height: context.s(56),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.sage,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.s(16)),
            ),
          ),
          onPressed: _next,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(
            _isLast ? 'Finish' : 'Next word',
            style: TextStyle(
              fontSize: context.s(16),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    // Miss: Try again + Next
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: context.s(56),
            child: OutlinedButton.icon(
              onPressed: _clearAndRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.honeyDark,
                side: const BorderSide(color: AppTheme.honey, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.s(16)),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: context.s(10)),
        Expanded(
          child: SizedBox(
            height: context.s(56),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.s(16)),
                ),
              ),
              onPressed: _next,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                _isLast ? 'Finish' : 'Next',
                style: TextStyle(
                  fontSize: context.s(15),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Did you know?" — tap to hear the pronouncer read it. Facts are the
/// reward for getting a word right, not a distraction before it.
class _FactChip extends StatelessWidget {
  final String fact;
  final bool opened;
  final VoidCallback onTap;
  const _FactChip({
    required this.fact,
    required this.opened,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.s(14)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(context.s(12)),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: opened ? 0.95 : 0.7),
          borderRadius: BorderRadius.circular(context.s(14)),
          border: Border.all(
            color: AppTheme.honeyDark.withValues(alpha: opened ? 0.5 : 0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: AppTheme.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                opened ? Icons.volume_up_rounded : Icons.lightbulb_rounded,
                color: AppTheme.honeyDark,
                size: 18,
              ),
            ),
            SizedBox(width: context.s(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opened ? 'Did you know?' : 'Did you know? Tap to hear',
                    style: const TextStyle(
                      color: AppTheme.honeyDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    fact,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HearCard extends StatelessWidget {
  final String? display;
  final bool isMath;
  final VoidCallback onHearWord;
  final VoidCallback onHearDefinition;
  final VoidCallback onHearExample;

  const _HearCard({
    required this.display,
    required this.isMath,
    required this.onHearWord,
    required this.onHearDefinition,
    required this.onHearExample,
  });

  @override
  Widget build(BuildContext context) {
    final shown = display;
    return Container(
      padding: EdgeInsets.all(context.s(18)),
      decoration: AppTheme.card(
        color: AppTheme.aqua,
        gradient: AppTheme.voiceGradient,
        radius: context.s(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (shown != null) ...[
            // Number Bee: the digits (or the equation) are the visual prompt
            // — the child still spells the WORD.
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.s(22),
                  vertical: context.s(10),
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(context.s(18)),
                  border: Border.all(color: AppTheme.sky.withValues(alpha: 0.4)),
                  boxShadow: AppTheme.tintedShadow(AppTheme.sky),
                ),
                child: Text(
                  shown,
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: context.s(shown.length > 8 ? 30 : 40),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            SizedBox(height: context.s(12)),
          ],
          Center(
            child: Container(
              width: context.s(shown == null ? 96 : 72),
              height: context.s(shown == null ? 96 : 72),
              decoration: BoxDecoration(
                gradient: AppTheme.ctaGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.tintedShadow(AppTheme.honeyDark),
              ),
              child: IconButton(
                tooltip: 'Hear the word',
                onPressed: onHearWord,
                icon: Icon(
                  Icons.volume_up_rounded,
                  color: AppTheme.ink,
                  size: context.s(shown == null ? 42 : 32),
                ),
              ),
            ),
          ),
          SizedBox(height: context.s(12)),
          Center(
            child: Text(
              isMath
                  ? 'Work it out, then spell the answer.'
                  : shown != null
                  ? 'Listen, then spell the number as a word.'
                  : 'Listen first, then spell.',
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(height: context.s(12)),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onHearDefinition,
                  icon: Icon(
                    isMath ? Icons.tips_and_updates_rounded : Icons.menu_book_rounded,
                    size: 18,
                  ),
                  label: Text(isMath ? 'How to' : 'Definition'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    foregroundColor: AppTheme.ink,
                    side: const BorderSide(color: AppTheme.outline),
                  ),
                ),
              ),
              SizedBox(width: context.s(8)),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onHearExample,
                  icon: Icon(
                    isMath ? Icons.back_hand_rounded : Icons.chat_rounded,
                    size: 18,
                  ),
                  label: Text(isMath ? 'A tip' : 'In a sentence'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    foregroundColor: AppTheme.ink,
                    side: const BorderSide(color: AppTheme.outline),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.honey : Colors.transparent,
          gradient: selected ? AppTheme.selectedNavGradient : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? AppTheme.tintedShadow(AppTheme.honeyDark)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppTheme.ink : AppTheme.mute,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppTheme.ink : AppTheme.mute,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet with three quick hint actions. Intentionally friction-free:
/// no ad gate, no premium lock — hints make the app more useful, not more
/// exploitable.
class _HintSheet extends StatelessWidget {
  final Word word;
  final VoidCallback onSlowRepeat;
  final VoidCallback onSpellOut;
  final VoidCallback onFirstLetter;

  const _HintSheet({
    required this.word,
    required this.onSlowRepeat,
    required this.onSpellOut,
    required this.onFirstLetter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.pageGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Need a hint?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 16),
          _HintTile(
            icon: Icons.slow_motion_video_rounded,
            color: AppTheme.sky,
            title: 'Say it slower',
            subtitle: 'Hear it at calm speed one more time.',
            onTap: onSlowRepeat,
          ),
          const SizedBox(height: 10),
          _HintTile(
            icon: Icons.text_fields_rounded,
            color: AppTheme.honeyDark,
            title: 'First letter',
            subtitle: 'Reveal what the word starts with.',
            onTap: onFirstLetter,
          ),
          const SizedBox(height: 10),
          _HintTile(
            icon: Icons.abc_rounded,
            color: AppTheme.violet,
            title: 'Spell it out',
            subtitle: 'Hear every letter. (You still have to enter it.)',
            onTap: onSpellOut,
          ),
        ],
      ),
    );
  }
}

class _HintTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _HintTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.card(
          gradient: AppTheme.surfaceLiftGradient,
          radius: 14,
          shadow: false,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.mute, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
