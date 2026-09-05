import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/utils/responsive.dart';

/// The state of one word's tile puzzle: a shuffled tray of letters (the
/// answer plus a few decoys) and the slots the child has filled so far.
/// Lives in the test screen's per-item state so switching modes or paging
/// back and forth never loses a half-built word.
class TileBoard {
  final List<String> tray;
  final int answerLength;

  /// Slot index → tray index, in the order placed.
  final List<int> placed = [];

  TileBoard._(this.tray, this.answerLength);

  factory TileBoard.forWord(String letters, {math.Random? random}) {
    final rng = random ?? math.Random();
    final answer = letters.toLowerCase().split('');
    final decoyCount = answer.length <= 4
        ? 2
        : answer.length <= 8
        ? 3
        : 4;
    const alphabet = 'abcdefghijklmnopqrstuvwxyz';
    final decoys = <String>[];
    var guard = 0;
    while (decoys.length < decoyCount && guard++ < 100) {
      final c = alphabet[rng.nextInt(alphabet.length)];
      // A decoy that already appears in the word is not a decoy — it just
      // makes a second, equally-correct copy.
      if (answer.contains(c) || decoys.contains(c)) continue;
      decoys.add(c);
    }
    final tray = [...answer, ...decoys];
    // Shuffle until the tray does not start by spelling the answer.
    for (var i = 0; i < 10; i++) {
      tray.shuffle(rng);
      if (tray.take(answer.length).join() != answer.join()) break;
    }
    return TileBoard._(tray, answer.length);
  }

  bool get isFull => placed.length >= answerLength;
  bool get isEmpty => placed.isEmpty;
  bool isPlaced(int trayIndex) => placed.contains(trayIndex);
  String get built => placed.map((i) => tray[i]).join();

  void place(int trayIndex) {
    if (isFull || isPlaced(trayIndex)) return;
    placed.add(trayIndex);
  }

  void removeSlot(int slot) {
    if (slot < 0 || slot >= placed.length) return;
    placed.removeAt(slot);
  }

  void clear() => placed.clear();
}

/// Tap-to-build letter tiles: honey tiles in a tray, paper slots above.
/// Tap a tile to drop it in the next empty slot; tap a slot to send its
/// letter back. Designed for small fingers: 46 px targets, big letters.
class LetterTilesInput extends StatelessWidget {
  final TileBoard board;
  final bool enabled;
  final bool? correct;
  final VoidCallback onChanged;

  const LetterTilesInput({
    super.key,
    required this.board,
    required this.enabled,
    required this.onChanged,
    this.correct,
  });

  @override
  Widget build(BuildContext context) {
    final long = board.answerLength > 9;
    final slotSize = context.s(long ? 34 : 44);
    final tileSize = context.s(46);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(context.s(12)),
          decoration: AppTheme.card(
            gradient: AppTheme.surfaceLiftGradient,
            radius: context.s(18),
            shadow: false,
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: context.s(6),
            runSpacing: context.s(6),
            children: [
              for (var slot = 0; slot < board.answerLength; slot++)
                _Slot(
                  size: slotSize,
                  letter: slot < board.placed.length
                      ? board.tray[board.placed[slot]]
                      : null,
                  correct: correct,
                  onTap: enabled && slot < board.placed.length
                      ? () {
                          HapticFeedback.selectionClick();
                          board.removeSlot(slot);
                          onChanged();
                        }
                      : null,
                ),
            ],
          ),
        ),
        SizedBox(height: context.s(12)),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: context.s(8),
          runSpacing: context.s(8),
          children: [
            for (var i = 0; i < board.tray.length; i++)
              _Tile(
                size: tileSize,
                letter: board.tray[i],
                used: board.isPlaced(i),
                onTap: enabled && !board.isPlaced(i) && !board.isFull
                    ? () {
                        HapticFeedback.selectionClick();
                        board.place(i);
                        onChanged();
                      }
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  final double size;
  final String? letter;
  final bool? correct;
  final VoidCallback? onTap;

  const _Slot({
    required this.size,
    required this.letter,
    required this.correct,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filled = letter != null;
    Color fill = filled ? AppTheme.surface2 : AppTheme.surface;
    Color border = filled ? AppTheme.honeyDark : AppTheme.outline;
    if (correct == true) {
      fill = AppTheme.mint;
      border = AppTheme.sage;
    } else if (correct == false && filled) {
      fill = AppTheme.rose;
      border = AppTheme.coral;
    }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: size,
        height: size * 1.1,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(size * 0.26),
          border: Border.all(color: border, width: filled ? 2 : 1.5),
        ),
        child: Center(
          child: Text(
            (letter ?? '').toUpperCase(),
            style: TextStyle(
              fontSize: size * 0.58,
              fontWeight: FontWeight.w900,
              color: AppTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final double size;
  final String letter;
  final bool used;
  final VoidCallback? onTap;

  const _Tile({
    required this.size,
    required this.letter,
    required this.used,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: used ? 0.28 : 1,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          scale: used ? 0.9 : 1,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: used ? null : AppTheme.ctaGradient,
              color: used ? AppTheme.surface2 : AppTheme.honey,
              borderRadius: BorderRadius.circular(size * 0.28),
              border: Border.all(
                color: AppTheme.honeyDark.withValues(alpha: used ? 0.2 : 0.5),
              ),
              boxShadow: used ? null : AppTheme.tintedShadow(AppTheme.honeyDark),
            ),
            child: Center(
              child: Text(
                letter.toUpperCase(),
                style: TextStyle(
                  fontSize: size * 0.52,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
