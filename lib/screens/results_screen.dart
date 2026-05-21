import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/data/voice_phrase_bank.dart';
import 'package:spellbee/core/models/test_result.dart';
import 'package:spellbee/core/models/word.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/test_screen.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  final TestResult result;
  final String title;
  const ResultsScreen({super.key, required this.result, required this.title});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tts = ref.read(ttsServiceProvider);
      final premium = ref.read(isPremiumProvider);
      final stub = VoicePhraseBank.pick(
        widget.result.accuracy >= 1.0
            ? VoicePhraseBank.perfectFinish
            : VoicePhraseBank.finish,
      );
      tts.playPhrase(stub, premium: premium);
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final title = widget.title;
    final pct = (result.accuracy * 100).round();
    final missedWords = _missedWords(result);
    String blurb;
    if (pct == 100) {
      blurb = 'Perfect! Every word nailed. Ready for the next level?';
    } else if (pct >= 80) {
      blurb = 'Great work. A few to polish — check the list below.';
    } else if (pct >= 50) {
      blurb = 'Solid effort. Review the misses and try again.';
    } else {
      blurb = 'Keep going — every bee starts here.';
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        foregroundColor: AppTheme.ink,
        title: Text(title),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
        child: SafeArea(
          child: ResponsiveContentBox(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.s(20)),
              child: ListView(
                padding: EdgeInsets.symmetric(vertical: context.s(20)),
                children: [
                  _score(context, pct),
                  SizedBox(height: context.s(16)),
                  Container(
                    padding: EdgeInsets.all(context.s(16)),
                    decoration: AppTheme.card(
                      gradient: AppTheme.surfaceLiftGradient,
                      radius: context.s(16),
                    ),
                    child: Text(
                      blurb,
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: context.s(15),
                        height: 1.45,
                      ),
                    ),
                  ),
                  SizedBox(height: context.s(18)),
                  Text(
                    'Review',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: context.s(8)),
                  for (final item in result.items) _row(context, item),
                  SizedBox(height: context.s(24)),
                  if (missedWords.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      height: context.s(54),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.ink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.s(16)),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => TestScreen(
                                words: missedWords,
                                title: 'Retry missed words',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text(
                          'Practice missed words',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: context.s(10)),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: context.s(54),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(context.s(16)),
                        onTap: () {
                          Navigator.of(context).popUntil((r) => r.isFirst);
                          ref.read(tabProvider.notifier).go(AppTab.home);
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: AppTheme.ctaGradient,
                            borderRadius: BorderRadius.circular(context.s(16)),
                            boxShadow: AppTheme.softShadow,
                          ),
                          child: const Center(
                            child: Text(
                              'Back to home',
                              style: TextStyle(
                                color: AppTheme.ink,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Word> _missedWords(TestResult result) {
    final seen = <String>{};
    final words = <Word>[];
    for (final item in result.items.where((item) => !item.isCorrect)) {
      final key = item.target.toLowerCase();
      if (!seen.add(key)) continue;
      words.add(Word(item.target, item.definition, item.example));
    }
    return words;
  }

  Widget _score(BuildContext context, int pct) {
    return Container(
      padding: EdgeInsets.all(context.s(20)),
      decoration: BoxDecoration(
        gradient: pct >= 80 ? AppTheme.successGradient : AppTheme.ctaGradient,
        borderRadius: BorderRadius.circular(context.s(22)),
        border: Border.all(color: AppTheme.outline),
        boxShadow: AppTheme.liftedShadow,
      ),
      child: Row(
        children: [
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: context.s(56),
              fontWeight: FontWeight.w900,
              color: AppTheme.ink,
            ),
          ),
          SizedBox(width: context.s(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.result.correct} of ${widget.result.total} correct',
                  style: TextStyle(
                    fontSize: context.s(16),
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                SizedBox(height: context.s(4)),
                Text(
                  '${widget.result.elapsed.inSeconds}s total',
                  style: const TextStyle(color: AppTheme.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AskedItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: context.s(8)),
      padding: EdgeInsets.all(context.s(14)),
      decoration: AppTheme.card(
        color: item.isCorrect ? AppTheme.mint : AppTheme.rose,
        gradient: item.isCorrect
            ? AppTheme.successGradient
            : AppTheme.errorGradient,
        border: item.isCorrect ? AppTheme.sage : AppTheme.coral,
        radius: context.s(12),
        shadow: false,
      ),
      child: Row(
        children: [
          Icon(
            item.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: item.isCorrect ? AppTheme.sage : AppTheme.coral,
          ),
          SizedBox(width: context.s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.target,
                  style: TextStyle(
                    fontSize: context.s(15),
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                if (!item.isCorrect && item.submitted.isNotEmpty)
                  Text(
                    'You said: ${item.submitted}',
                    style: const TextStyle(color: AppTheme.mute, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
