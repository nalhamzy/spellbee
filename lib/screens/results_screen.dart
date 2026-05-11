import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/models/test_result.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';

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
      final stub = widget.result.accuracy >= 1.0 ? 'new_best' : 'test_complete';
      tts.playPhrase(stub, premium: premium);
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final title = widget.title;
    final pct = (result.accuracy * 100).round();
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
      body: SafeArea(
        child: ResponsiveContentBox(
          child: ListView(
            padding: EdgeInsets.all(context.s(20)),
            children: [
              _score(context, pct),
              SizedBox(height: context.s(16)),
              Container(
                padding: EdgeInsets.all(context.s(16)),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.outline),
                  borderRadius: BorderRadius.circular(context.s(16)),
                ),
                child: Text(blurb,
                    style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: context.s(15),
                        height: 1.45)),
              ),
              SizedBox(height: context.s(18)),
              Text('Review', style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: context.s(8)),
              for (final item in result.items)
                _row(context, item),
              SizedBox(height: context.s(24)),
              SizedBox(
                width: double.infinity,
                height: context.s(54),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.honey,
                    foregroundColor: AppTheme.ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.s(16)),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    ref.read(tabProvider.notifier).go(AppTab.home);
                  },
                  child: const Text('Back to home',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _score(BuildContext context, int pct) {
    return Container(
      padding: EdgeInsets.all(context.s(20)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.honey, AppTheme.honey.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(context.s(22)),
      ),
      child: Row(
        children: [
          Text('$pct%',
              style: TextStyle(
                fontSize: context.s(56),
                fontWeight: FontWeight.w900,
                color: AppTheme.ink,
              )),
          SizedBox(width: context.s(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.result.correct} of ${widget.result.total} correct',
                    style: TextStyle(
                        fontSize: context.s(16),
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink)),
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
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(
          color: item.isCorrect ? AppTheme.sage : AppTheme.coral,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(context.s(12)),
      ),
      child: Row(
        children: [
          Icon(
            item.isCorrect
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            color: item.isCorrect ? AppTheme.sage : AppTheme.coral,
          ),
          SizedBox(width: context.s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.target,
                    style: TextStyle(
                        fontSize: context.s(15),
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink)),
                if (!item.isCorrect && item.submitted.isNotEmpty)
                  Text('You said: ${item.submitted}',
                      style: const TextStyle(
                          color: AppTheme.mute, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
