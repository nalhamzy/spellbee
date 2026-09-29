import 'package:spellbee/core/data/words_catalog.dart';
import 'package:spellbee/core/models/word.dart';

/// Authored stories; no generated story content or child data leaves the device.
class AdventureWorld {
  final String id, title, subtitle, introduction, reward;
  final List<String> stops;
  final bool premium;
  const AdventureWorld({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.introduction,
    required this.reward,
    required this.stops,
    this.premium = true,
  });

  String get image => 'assets/adventures/$id.png';
  String stopId(int stop) => '$id.$stop';
  bool available(bool hasPremium) => !premium || hasPremium;
}

const adventureWorlds = [
  AdventureWorld(
    id: 'meadow',
    title: 'Sunny Meadow',
    subtitle: 'Help the flowers bloom',
    premium: false,
    introduction:
        'The meadow needs a little bee magic. Help four flowers bloom with four words at each stop.',
    reward: 'The meadow is blooming!',
    stops: [
      'Wake the sleepy seed.',
      'Help the little sprout grow.',
      'Open the sunny flower.',
      'Light up the whole meadow.',
    ],
  ),
  AdventureWorld(
    id: 'moonlight',
    title: 'Moonlight Garden',
    subtitle: 'Light a path for little friends',
    introduction:
        'The moonlight garden has lost its glow. Help four lanterns shine for our night time friends.',
    reward: 'The garden is glowing!',
    stops: [
      'Find the first firefly.',
      'Light the lantern path.',
      'Guide the moth home.',
      'Make the garden glow.',
    ],
  ),
  AdventureWorld(
    id: 'rainbow',
    title: 'Rainbow Falls',
    subtitle: 'Bring the colors home',
    introduction:
        'A rainbow is hiding behind the waterfall. Follow four stepping stones and bring its colors back.',
    reward: 'The rainbow is back!',
    stops: [
      'Cross the little stream.',
      'Find the misty bridge.',
      'Reach the rainbow pool.',
      'Bring the rainbow home.',
    ],
  ),
];

const adventureFinishNarration =
    'You helped this place shine. Come back another day for more word adventures.';

class AdventureProgress {
  final Set<String> completed;
  AdventureProgress([Iterable<String> values = const []])
    : completed = Set.unmodifiable(
        values.where(
          (value) => adventureWorlds.any(
            (world) =>
                List.generate(world.stops.length, world.stopId).contains(value),
          ),
        ),
      );

  bool isDone(AdventureWorld world, int stop) =>
      completed.contains(world.stopId(stop));
  int count(AdventureWorld world) => List.generate(
    world.stops.length,
    (i) => i,
  ).where((i) => isDone(world, i)).length;
  bool canPlay(AdventureWorld world, int stop, {required bool premium}) =>
      stop >= 0 &&
      stop < world.stops.length &&
      world.available(premium) &&
      (stop == 0 || isDone(world, stop - 1));

  AdventureProgress finish(
    AdventureWorld world,
    int stop, {
    required bool premium,
  }) {
    if (!canPlay(world, stop, premium: premium)) return this;
    return AdventureProgress({...completed, world.stopId(stop)});
  }
}

/// A stable round for this stop today; replaying tomorrow rotates the practice.
/// Story completion is separate from the spaced-recall learning record.
List<Word> adventureWords(
  AdventureWorld world,
  int stop,
  int level,
  DateTime day,
) {
  final pool = kWordsCatalog[level] ?? kWordsCatalog[1]!;
  final dayNumber =
      DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  final worldIndex = adventureWorlds.indexWhere((w) => w.id == world.id);
  final offset = dayNumber + worldIndex * 16 + stop * 4;
  return List.generate(4, (i) => pool[(offset + i) % pool.length]);
}
