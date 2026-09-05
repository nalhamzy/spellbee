import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/models/progression.dart';
import 'package:spellbee/core/utils/responsive.dart';

/// Paper confetti in the app palette, falling once and settling. Painted,
/// not widget-per-particle, so it costs nothing on a low-end tablet.
class ConfettiBurst extends StatefulWidget {
  final Duration duration;
  final int count;
  const ConfettiBurst({
    super.key,
    this.duration = const Duration(milliseconds: 2600),
    this.count = 70,
  });

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;

  static const _palette = [
    AppTheme.honey,
    AppTheme.coral,
    AppTheme.sage,
    AppTheme.sky,
    AppTheme.violet,
    AppTheme.peach,
  ];

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _particles = List.generate(widget.count, (i) {
      return _Particle(
        x: rng.nextDouble(),
        delay: rng.nextDouble() * 0.35,
        drift: (rng.nextDouble() - 0.5) * 0.35,
        spin: (rng.nextDouble() - 0.5) * 12,
        size: 6 + rng.nextDouble() * 8,
        color: _palette[i % _palette.length],
        round: rng.nextBool(),
      );
    });
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => CustomPaint(
          painter: _ConfettiPainter(_particles, _ctrl.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  final double x, delay, drift, spin, size;
  final Color color;
  final bool round;
  const _Particle({
    required this.x,
    required this.delay,
    required this.drift,
    required this.spin,
    required this.size,
    required this.color,
    required this.round,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final eased = Curves.easeIn.transform(local);
      final y = -20 + eased * (size.height + 40);
      final x = (p.x + p.drift * math.sin(local * math.pi * 2)) * size.width;
      final fade = local > 0.8 ? (1 - local) / 0.2 : 1.0;
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

/// The "what you just earned" card: honey, finished quests, new badges,
/// rank-ups. Only renders rows that apply, so a plain round shows a single
/// honey line and a big day shows the whole stack.
class RewardsCard extends StatelessWidget {
  final ProgressionOutcome outcome;
  const RewardsCard({super.key, required this.outcome});

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    return Container(
      padding: EdgeInsets.all(context.s(16)),
      decoration: AppTheme.card(
        color: AppTheme.peach,
        gradient: AppTheme.ctaGradient,
        border: AppTheme.honeyDark.withValues(alpha: 0.35),
        radius: context.s(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const HoneyDrop(size: 34),
              SizedBox(width: context.s(10)),
              Expanded(
                child: Text(
                  '+${o.honeyEarned} honey',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: context.s(22),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (o.bonusCredits > 0)
                _Pill(
                  icon: Icons.bolt_rounded,
                  label: '+${o.bonusCredits} word pack',
                  color: AppTheme.violet,
                ),
            ],
          ),
          if (o.rankedUp) ...[
            SizedBox(height: context.s(12)),
            _RewardRow(
              icon: o.rankAfter.icon,
              color: o.rankAfter.color,
              title: 'Rank up! You are a ${o.rankAfter.title}',
              subtitle: 'From ${o.rankBefore.title} to ${o.rankAfter.title}.',
            ),
          ],
          for (final q in o.questsCompleted) ...[
            SizedBox(height: context.s(10)),
            _RewardRow(
              icon: Icons.task_alt_rounded,
              color: AppTheme.sage,
              title: 'Quest done: ${q.title}',
              subtitle: '+${q.rewardHoney} honey',
            ),
          ],
          for (final b in o.newBadges) ...[
            SizedBox(height: context.s(10)),
            _RewardRow(
              icon: b.icon,
              color: b.color,
              title: 'New badge: ${b.title}',
              subtitle: b.description,
            ),
          ],
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _RewardRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.s(10)),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(context.s(14)),
      ),
      child: Row(
        children: [
          Container(
            width: context.s(36),
            height: context.s(36),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: context.s(20)),
          ),
          SizedBox(width: context.s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
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

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// A little honey drop — the app's currency glyph, drawn so it matches the
/// palette on every platform instead of depending on an emoji font.
class HoneyDrop extends StatelessWidget {
  final double size;
  const HoneyDrop({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _HoneyDropPainter()),
    );
  }
}

class _HoneyDropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, 0)
      ..cubicTo(w * 0.62, h * 0.28, w, h * 0.42, w, h * 0.66)
      ..arcToPoint(Offset(0, h * 0.66), radius: Radius.circular(w / 2))
      ..cubicTo(0, h * 0.42, w * 0.38, h * 0.28, w / 2, 0)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppTheme.honey, AppTheme.honeyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppTheme.ink.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, w * 0.07),
    );
    canvas.drawCircle(
      Offset(w * 0.36, h * 0.6),
      w * 0.09,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
