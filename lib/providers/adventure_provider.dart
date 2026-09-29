import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/models/adventure.dart';
import 'package:spellbee/providers/providers.dart';

final adventureProvider =
    NotifierProvider<AdventureNotifier, AdventureProgress>(
      AdventureNotifier.new,
    );

class AdventureNotifier extends Notifier<AdventureProgress> {
  @override
  AdventureProgress build() =>
      ref.read(storageServiceProvider).loadAdventures();

  Future<void> complete(
    AdventureWorld world,
    int stop, {
    bool? startedWithPremium,
  }) async {
    // An earned reward survives expiry during the round. New rounds still
    // check the current entitlement before opening.
    final next = state.finish(
      world,
      stop,
      premium: startedWithPremium ?? ref.read(isPremiumProvider),
    );
    if (next.completed.length == state.completed.length) return;
    await ref.read(storageServiceProvider).saveAdventures(next);
    state = next;
  }
}
