import 'package:flutter/material.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/models/progression.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/widgets/celebration.dart';

/// Rank + honey + progress to the next rank. Compact enough for the top of
/// the dashboard, honest enough for the parent view.
class RankCard extends StatelessWidget {
  final Progression progression;
  final bool compact;
  const RankCard({super.key, required this.progression, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final p = progression;
    final rank = p.rank;
    final next = rank.next;
    final progress = rank.progressFor(p.honey);
    return Container(
      padding: EdgeInsets.all(context.s(compact ? 14 : 16)),
      decoration: AppTheme.card(
        color: AppTheme.surface,
        gradient: AppTheme.surfaceLiftGradient,
        radius: context.s(22),
      ),
      child: Row(
        children: [
          Container(
            width: context.s(52),
            height: context.s(52),
            decoration: BoxDecoration(
              color: rank.color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(color: rank.color.withValues(alpha: 0.45)),
            ),
            child: Icon(rank.icon, color: rank.color, size: context.s(28)),
          ),
          SizedBox(width: context.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rank.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: context.s(17),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const HoneyDrop(size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${p.honey}',
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.s(7)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: context.s(9),
                    color: rank.color,
                    backgroundColor: AppTheme.surface2,
                  ),
                ),
                SizedBox(height: context.s(5)),
                Text(
                  next == null
                      ? 'Top of the hive — Queen Bee!'
                      : '${next.minHoney - p.honey} honey to ${next.title}',
                  style: const TextStyle(
                    color: AppTheme.mute,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Today's three quests with live progress bars.
class QuestsCard extends StatelessWidget {
  final List<QuestDef> quests;
  final Progression progression;
  const QuestsCard({
    super.key,
    required this.quests,
    required this.progression,
  });

  @override
  Widget build(BuildContext context) {
    final done = quests.where(progression.isComplete).length;
    return Container(
      padding: EdgeInsets.all(context.s(16)),
      decoration: AppTheme.card(
        color: AppTheme.mint,
        gradient: AppTheme.successGradient,
        border: AppTheme.sage.withValues(alpha: 0.3),
        radius: context.s(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: context.s(40),
                height: context.s(40),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(context.s(13)),
                ),
                child: const Icon(Icons.flag_rounded, color: AppTheme.sage),
              ),
              SizedBox(width: context.s(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's quests",
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      done == quests.length
                          ? 'All done — Quest Master!'
                          : '$done of ${quests.length} done · new quests every day',
                      style: const TextStyle(color: AppTheme.mute, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.s(12)),
          for (var i = 0; i < quests.length; i++) ...[
            if (i > 0) SizedBox(height: context.s(8)),
            _QuestRow(quest: quests[i], progression: progression),
          ],
        ],
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  final QuestDef quest;
  final Progression progression;
  const _QuestRow({required this.quest, required this.progression});

  @override
  Widget build(BuildContext context) {
    final value = progression.progressFor(quest).clamp(0, quest.target);
    final done = value >= quest.target;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.s(12),
        vertical: context.s(10),
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: done ? 0.55 : 0.85),
        borderRadius: BorderRadius.circular(context.s(14)),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : quest.icon,
            color: done ? AppTheme.sage : AppTheme.honeyDark,
            size: 22,
          ),
          SizedBox(width: context.s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: AppTheme.mute,
                  ),
                ),
                SizedBox(height: context.s(5)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: quest.target == 0 ? 1 : value / quest.target,
                    minHeight: context.s(6),
                    color: done ? AppTheme.sage : AppTheme.honey,
                    backgroundColor: AppTheme.surface2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.s(10)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$value/${quest.target}',
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HoneyDrop(size: 12),
                  const SizedBox(width: 2),
                  Text(
                    '+${quest.rewardHoney}',
                    style: const TextStyle(
                      color: AppTheme.honeyDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (quest.bonusCredit) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.bolt_rounded,
                      size: 12,
                      color: AppTheme.violet,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Every badge, earned ones in colour and locked ones as quiet outlines —
/// the locked ones are the roadmap, so they stay visible.
class BadgesGrid extends StatelessWidget {
  final Progression progression;
  const BadgesGrid({super.key, required this.progression});

  @override
  Widget build(BuildContext context) {
    final earned = kBadges.where((b) => progression.badges.containsKey(b.id));
    return Container(
      padding: EdgeInsets.all(context.s(16)),
      decoration: AppTheme.card(
        gradient: AppTheme.surfaceLiftGradient,
        radius: context.s(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: context.s(42),
                height: context.s(42),
                decoration: BoxDecoration(
                  color: AppTheme.lilac,
                  borderRadius: BorderRadius.circular(context.s(14)),
                ),
                child: const Icon(
                  Icons.military_tech_rounded,
                  color: AppTheme.violet,
                ),
              ),
              SizedBox(width: context.s(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Badges',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${earned.length} of ${kBadges.length} earned',
                      style: const TextStyle(color: AppTheme.mute, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.s(12)),
          LayoutBuilder(
            builder: (context, constraints) {
              final gap = context.s(8);
              final columns = constraints.maxWidth >= context.s(380) ? 4 : 3;
              final w = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final b in kBadges)
                    SizedBox(
                      width: w,
                      child: _BadgeTile(
                        badge: b,
                        earned: progression.badges.containsKey(b.id),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final BadgeDef badge;
  final bool earned;
  const _BadgeTile({required this.badge, required this.earned});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: badge.description,
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: context.s(10),
          horizontal: context.s(6),
        ),
        decoration: BoxDecoration(
          color: earned
              ? badge.color.withValues(alpha: 0.14)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(context.s(16)),
          border: Border.all(
            color: earned
                ? badge.color.withValues(alpha: 0.5)
                : AppTheme.outline,
          ),
        ),
        child: Column(
          children: [
            Icon(
              earned ? badge.icon : Icons.lock_outline_rounded,
              color: earned ? badge.color : AppTheme.outline,
              size: context.s(26),
            ),
            SizedBox(height: context.s(5)),
            Text(
              badge.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: earned ? AppTheme.ink : AppTheme.mute,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
