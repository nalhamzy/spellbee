import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Responsive scale helper. Use context.s(24) in place of a hardcoded 24 to
/// get smooth scaling across phones and tablets. Inspired by the pattern
/// used in ChromaPulse / Parenting Pulse.
extension ResponsiveContextX on BuildContext {
  double s(double v) {
    final w = responsiveViewportWidth(this);
    // Scale factor: 1.0 at a 390-wide iPhone, capped between 0.85 and 1.6.
    final f = (w / 390).clamp(0.85, 1.6);
    return v * f;
  }
}

double responsiveViewportWidth(BuildContext context) {
  final mediaWidth = MediaQuery.sizeOf(context).width;
  if (!kIsWeb || Uri.base.queryParameters['screenshot'] != '1') {
    return mediaWidth;
  }

  final forcedWidth = double.tryParse(Uri.base.queryParameters['vw'] ?? '');
  if (forcedWidth == null || forcedWidth <= 0) {
    return mediaWidth;
  }
  return forcedWidth;
}

double responsiveMaxContentWidth(BuildContext context) {
  return math.min(responsiveViewportWidth(context), 720.0);
}

class ResponsiveContentBox extends StatelessWidget {
  final Widget child;
  const ResponsiveContentBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = responsiveViewportWidth(context);
        final constraintWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : viewportWidth;
        final available = math.min(viewportWidth, constraintWidth);
        final width = math.min(available, responsiveMaxContentWidth(context));
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: width, child: child),
        );
      },
    );
  }
}
