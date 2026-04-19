import 'package:equatable/equatable.dart';

class TestResult extends Equatable {
  /// Every word in the order asked, with what was typed/spoken.
  final List<AskedItem> items;
  final Duration elapsed;
  final DateTime endedAt;

  const TestResult({
    required this.items,
    required this.elapsed,
    required this.endedAt,
  });

  int get correct => items.where((i) => i.isCorrect).length;
  int get total => items.length;
  double get accuracy => total == 0 ? 0 : correct / total;

  @override
  List<Object?> get props => [items, elapsed, endedAt];
}

class AskedItem extends Equatable {
  final String target;
  final String submitted;
  final bool isCorrect;

  const AskedItem({
    required this.target,
    required this.submitted,
    required this.isCorrect,
  });

  @override
  List<Object?> get props => [target, submitted, isCorrect];
}
