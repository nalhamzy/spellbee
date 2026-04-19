import 'package:flutter/material.dart';

/// Responsive scale helper. Use context.s(24) in place of a hardcoded 24 to
/// get smooth scaling across phones and tablets. Inspired by the pattern
/// used in ChromaPulse / Parenting Pulse.
extension ResponsiveContextX on BuildContext {
  double s(double v) {
    final w = MediaQuery.of(this).size.width;
    // Scale factor: 1.0 at a 390-wide iPhone, capped between 0.85 and 1.6.
    final f = (w / 390).clamp(0.85, 1.6);
    return v * f;
  }
}

class ResponsiveContentBox extends StatelessWidget {
  final Widget child;
  const ResponsiveContentBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: child,
      ),
    );
  }
}
