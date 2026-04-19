import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/models/test_result.dart';
import 'package:spellbee/core/models/word.dart';
import 'package:spellbee/core/services/stt_service.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/results_screen.dart';

enum InputMode { keyboard, mic }

/// The core bee loop: for each [words] entry, speak it, let the student type
/// or dictate a spelling, reveal, and keep score.
class TestScreen extends ConsumerStatefulWidget {
  final List<Word> words;
  final String title;
  final bool savesStats;

  const TestScreen({
    super.key,
    required this.words,
    required this.title,
    this.savesStats = true,
  });

  @override
  ConsumerState<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends ConsumerState<TestScreen> {
  int _idx = 0;
  InputMode _mode = InputMode.keyboard;
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final List<AskedItem> _results = [];
  int _runStreak = 0;
  int _longestStreak = 0;
  bool _revealed = false;
  bool? _lastCorrect;
  String _sttTranscript = '';
  DateTime? _startedAt;

  Word get _w => widget.words[_idx];
  bool get _last => _idx >= widget.words.length - 1;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  Future<void> _speak() async {
    await ref.read(ttsServiceProvider).speakWord(_w.text);
  }

  Future<void> _speakDefinition() async {
    await ref.read(ttsServiceProvider).speakDefinition(_w.text, _w.definition);
  }

  Future<void> _speakExample() async {
    await ref.read(ttsServiceProvider).speakExample(_w.text, _w.example);
  }

  void _submit() {
    if (_revealed) return;
    final typed = _mode == InputMode.keyboard
        ? _ctrl.text.trim().toLowerCase()
        : SttService.normalize(_sttTranscript).toLowerCase();
    final correct = typed == _w.text.toLowerCase();
    setState(() {
      _revealed = true;
      _lastCorrect = correct;
      _results.add(
        AskedItem(target: _w.text, submitted: typed, isCorrect: correct),
      );
      if (correct) {
        _runStreak++;
        if (_runStreak > _longestStreak) _longestStreak = _runStreak;
      } else {
        _runStreak = 0;
      }
    });
    if (!correct) {
      // Spell it out for the student to hear.
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) ref.read(ttsServiceProvider).spellOut(_w.text);
      });
    }
  }

  void _next() async {
    if (_last) {
      final result = TestResult(
        items: List.unmodifiable(_results),
        elapsed: DateTime.now().difference(_startedAt!),
        endedAt: DateTime.now(),
      );
      if (widget.savesStats) {
        await ref.read(playerStatsProvider.notifier).recordTestComplete(
              asked: result.total,
              correct: result.correct,
              longestStreak: _longestStreak,
            );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ResultsScreen(result: result, title: widget.title),
      ));
      return;
    }
    setState(() {
      _idx++;
      _ctrl.clear();
      _sttTranscript = '';
      _revealed = false;
      _lastCorrect = null;
    });
    Future.delayed(const Duration(milliseconds: 300), _speak);
  }

  Future<void> _toggleMic() async {
    final stt = ref.read(sttServiceProvider);
    if (stt.listening) {
      await stt.stop();
      setState(() {});
      return;
    }
    await stt.start(
      onResult: (transcript, isFinal) {
        setState(() => _sttTranscript = transcript);
        if (isFinal) {
          stt.stop().then((_) => setState(() {}));
        }
      },
    );
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    ref.read(ttsServiceProvider).stop();
    ref.read(sttServiceProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_idx + 1) / widget.words.length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        foregroundColor: AppTheme.ink,
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: ResponsiveContentBox(
          child: Padding(
            padding: EdgeInsets.all(context.s(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(context.s(8)),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: context.s(8),
                    backgroundColor: AppTheme.surface2,
                    color: AppTheme.honey,
                  ),
                ),
                SizedBox(height: context.s(8)),
                Text(
                  'Word ${_idx + 1} of ${widget.words.length}  •  Streak $_runStreak',
                  style: const TextStyle(color: AppTheme.mute, fontSize: 13),
                ),
                SizedBox(height: context.s(18)),
                _HearCard(
                  onHearWord: _speak,
                  onHearDefinition: _speakDefinition,
                  onHearExample: _speakExample,
                ),
                SizedBox(height: context.s(18)),
                _modeToggle(),
                SizedBox(height: context.s(18)),
                _mode == InputMode.keyboard
                    ? _keyboardInput()
                    : _micInput(),
                SizedBox(height: context.s(20)),
                if (_revealed) _revealCard(),
                const Spacer(),
                _primaryButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeToggle() {
    return Container(
      padding: EdgeInsets.all(context.s(4)),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(context.s(14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeChip(
              label: 'Type',
              icon: Icons.keyboard_alt_rounded,
              selected: _mode == InputMode.keyboard,
              onTap: () => setState(() => _mode = InputMode.keyboard),
            ),
          ),
          Expanded(
            child: _ModeChip(
              label: 'Spell aloud',
              icon: Icons.mic_rounded,
              selected: _mode == InputMode.mic,
              onTap: () => setState(() => _mode = InputMode.mic),
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
      onSubmitted: (_) => _submit(),
      enabled: !_revealed,
      textCapitalization: TextCapitalization.none,
      style: TextStyle(
        fontSize: context.s(28),
        fontWeight: FontWeight.w700,
        color: AppTheme.ink,
        letterSpacing: 1.5,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppTheme.surface,
        hintText: 'spell the word',
        hintStyle: TextStyle(
          fontSize: context.s(18),
          color: AppTheme.mute,
          letterSpacing: 0.5,
        ),
        contentPadding: EdgeInsets.symmetric(
            horizontal: context.s(16), vertical: context.s(14)),
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

  Widget _micInput() {
    final stt = ref.watch(sttServiceProvider);
    final normalized = SttService.normalize(_sttTranscript);
    return Column(
      children: [
        GestureDetector(
          onTap: _revealed ? null : _toggleMic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: context.s(110),
            height: context.s(110),
            decoration: BoxDecoration(
              color: stt.listening ? AppTheme.coral : AppTheme.honey,
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
        SizedBox(height: context.s(14)),
        Text(
          normalized.isEmpty
              ? 'Tap and say each letter slowly'
              : normalized.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: context.s(20),
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  Widget _revealCard() {
    final ok = _lastCorrect ?? false;
    return Container(
      padding: EdgeInsets.all(context.s(16)),
      decoration: BoxDecoration(
        color: (ok ? AppTheme.sage : AppTheme.coral).withValues(alpha: 0.12),
        border: Border.all(
          color: ok ? AppTheme.sage : AppTheme.coral,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(context.s(16)),
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
            'The word is "${_w.text}"',
            style: TextStyle(
              fontSize: context.s(16),
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          SizedBox(height: context.s(4)),
          Text(_w.definition,
              style: const TextStyle(color: AppTheme.mute, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _primaryButton() {
    final label = _revealed
        ? (_last ? 'Finish' : 'Next word')
        : 'Check my spelling';
    return SizedBox(
      width: double.infinity,
      height: context.s(56),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.honey,
          foregroundColor: AppTheme.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.s(16)),
          ),
        ),
        onPressed: _revealed ? _next : _submit,
        child: Text(
          label,
          style: TextStyle(
            fontSize: context.s(16),
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _HearCard extends StatelessWidget {
  final VoidCallback onHearWord;
  final VoidCallback onHearDefinition;
  final VoidCallback onHearExample;

  const _HearCard({
    required this.onHearWord,
    required this.onHearDefinition,
    required this.onHearExample,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.s(16)),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.outline),
        borderRadius: BorderRadius.circular(context.s(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: FilledButton.tonalIcon(
              onPressed: onHearWord,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.honey,
                foregroundColor: AppTheme.ink,
                padding: EdgeInsets.symmetric(
                    horizontal: context.s(24), vertical: context.s(14)),
              ),
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text('Hear the word'),
            ),
          ),
          SizedBox(height: context.s(10)),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onHearDefinition,
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: const Text('Definition'),
                ),
              ),
              SizedBox(width: context.s(8)),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onHearExample,
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('In a sentence'),
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.honey : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? AppTheme.ink : AppTheme.mute),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: selected ? AppTheme.ink : AppTheme.mute,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }
}
