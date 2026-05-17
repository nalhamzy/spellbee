import 'package:spellbee/core/models/word.dart';

class ThemedWordPack {
  final String id;
  final Set<String> aliases;
  final Set<String> keywords;
  final List<Word> words;

  const ThemedWordPack({
    required this.id,
    required this.aliases,
    required this.keywords,
    required this.words,
  });

  bool matchesQuery(String query) {
    final normalized = normalizeThemeQuery(query);
    if (normalized.isEmpty) return false;
    final tokens = normalized.split(' ').where((t) => t.isNotEmpty).toSet();
    return aliases.any((alias) {
      final a = normalizeThemeQuery(alias);
      return normalized == a || normalized.contains(a) || tokens.contains(a);
    });
  }

  bool matchesWord(Word word) {
    final text = word.text.toLowerCase().trim();
    if (words.any((local) => local.text == text)) return true;
    final haystack = normalizeThemeQuery(
      '${word.text} ${word.definition} ${word.example}',
    );
    return keywords.any((keyword) => haystack.contains(keyword)) ||
        aliases.any((alias) => haystack.contains(normalizeThemeQuery(alias)));
  }
}

String normalizeThemeQuery(String input) => input
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

ThemedWordPack? findThemedWordPack(String query) {
  final normalized = normalizeThemeQuery(query);
  if (normalized.isEmpty) return null;
  for (final pack in kThemedWordPacks) {
    if (pack.matchesQuery(normalized)) return pack;
  }
  return null;
}

const kThemedWordPacks = <ThemedWordPack>[
  ThemedWordPack(
    id: 'space',
    aliases: {
      'space',
      'planet',
      'planets',
      'solar',
      'moon',
      'stars',
      'astronomy',
      'universe',
      'rocket',
    },
    keywords: {
      'space',
      'planet',
      'star',
      'moon',
      'sun',
      'orbit',
      'rocket',
      'comet',
      'meteor',
      'astronaut',
      'galaxy',
      'lunar',
      'solar',
      'crater',
      'telescope',
      'satellite',
      'cosmic',
      'nebula',
      'eclipse',
      'asteroid',
      'universe',
      'gravity',
    },
    words: [
      Word(
        'sun',
        'The star at the center of our solar system.',
        'The sun warmed the launch pad.',
      ),
      Word(
        'moon',
        'A natural object that orbits a planet.',
        'The moon glowed over the observatory.',
      ),
      Word(
        'star',
        'A huge ball of hot gas that shines in space.',
        'A bright star appeared after sunset.',
      ),
      Word(
        'sky',
        'The space above Earth where clouds and stars appear.',
        'The rocket climbed into the dark sky.',
      ),
      Word(
        'mars',
        'A red planet that orbits the sun.',
        'Mars can look like a tiny red star.',
      ),
      Word(
        'orbit',
        'The path one object follows around another in space.',
        'The satellite entered orbit above Earth.',
      ),
      Word(
        'comet',
        'An icy space object that can grow a glowing tail.',
        'A comet streaked past the telescope.',
      ),
      Word(
        'rocket',
        'A vehicle designed to travel into space.',
        'The rocket carried supplies to the station.',
      ),
      Word(
        'planet',
        'A large round world that travels around a star.',
        'Earth is the planet we call home.',
      ),
      Word(
        'lunar',
        'Related to the moon.',
        'The lunar rover rolled across gray dust.',
      ),
      Word('solar', 'Related to the sun.', 'A solar flare burst from the sun.'),
      Word(
        'crater',
        'A bowl-shaped hollow on a moon or planet.',
        'The crater was visible through the telescope.',
      ),
      Word(
        'meteor',
        'A space rock that burns brightly in the sky.',
        'A meteor flashed for one second.',
      ),
      Word(
        'galaxy',
        'A huge system of stars, dust, and gas.',
        'Our galaxy contains billions of stars.',
      ),
      Word(
        'cosmic',
        'Related to the universe or outer space.',
        'The scientist studied cosmic dust.',
      ),
      Word(
        'eclipse',
        'When one space object blocks light from another.',
        'The class watched the eclipse with safe glasses.',
      ),
      Word(
        'nebula',
        'A cloud of gas and dust in space.',
        'The nebula looked pink in the image.',
      ),
      Word(
        'asteroid',
        'A rocky object that travels around the sun.',
        'The asteroid passed safely by Earth.',
      ),
      Word(
        'satellite',
        'An object that orbits a planet.',
        'The satellite sent pictures from space.',
      ),
      Word(
        'astronaut',
        'A person trained to travel and work in space.',
        'The astronaut checked her helmet.',
      ),
      Word(
        'telescope',
        'A tool that makes faraway space objects look closer.',
        'He aimed the telescope at Jupiter.',
      ),
      Word(
        'gravity',
        'The force that pulls objects toward each other.',
        'Gravity keeps the moon in orbit.',
      ),
      Word(
        'universe',
        'All of space and everything in it.',
        'The universe is larger than we can imagine.',
      ),
      Word(
        'constellation',
        'A pattern of stars seen from Earth.',
        'Orion is a famous constellation.',
      ),
      Word(
        'observatory',
        'A building where people study stars and planets.',
        'The observatory opened after dark.',
      ),
      Word(
        'trajectory',
        'The curved path of a moving object.',
        'The rocket followed a careful trajectory.',
      ),
      Word(
        'atmosphere',
        'The layer of gases around a planet.',
        'Earth has an atmosphere we can breathe.',
      ),
      Word(
        'interstellar',
        'Located or traveling between stars.',
        'The probe began an interstellar journey.',
      ),
    ],
  ),
  ThemedWordPack(
    id: 'animals',
    aliases: {'animal', 'animals', 'pets', 'zoo', 'wildlife', 'creatures'},
    keywords: {
      'animal',
      'pet',
      'zoo',
      'wild',
      'mammal',
      'bird',
      'fish',
      'reptile',
      'insect',
      'creature',
    },
    words: [
      Word(
        'cat',
        'A small furry animal often kept as a pet.',
        'The cat slept near the window.',
      ),
      Word(
        'dog',
        'A loyal animal that often lives with people.',
        'The dog chased a ball.',
      ),
      Word(
        'bird',
        'An animal with feathers and wings.',
        'The bird built a nest.',
      ),
      Word(
        'fish',
        'An animal that lives and swims in water.',
        'The fish darted behind a rock.',
      ),
      Word(
        'sheep',
        'A farm animal with wool.',
        'The sheep followed the shepherd.',
      ),
      Word(
        'rabbit',
        'A small animal with long ears.',
        'The rabbit nibbled a carrot.',
      ),
      Word('kitten', 'A young cat.', 'The kitten played with yarn.'),
      Word(
        'walrus',
        'A large sea mammal with tusks.',
        'The walrus rested on the ice.',
      ),
      Word(
        'giraffe',
        'A tall animal with a long neck.',
        'The giraffe reached high leaves.',
      ),
      Word(
        'turtle',
        'A reptile with a hard shell.',
        'The turtle crossed the path slowly.',
      ),
      Word(
        'parrot',
        'A colorful bird that can copy sounds.',
        'The parrot whistled at breakfast.',
      ),
      Word(
        'elephant',
        'A very large mammal with a trunk.',
        'The elephant sprayed water.',
      ),
      Word(
        'dolphin',
        'A smart sea mammal.',
        'The dolphin leaped beside the boat.',
      ),
      Word(
        'penguin',
        'A flightless bird that swims well.',
        'The penguin slid across the ice.',
      ),
      Word('leopard', 'A spotted wild cat.', 'The leopard moved silently.'),
      Word(
        'kangaroo',
        'An Australian animal that hops.',
        'The kangaroo carried a joey.',
      ),
      Word(
        'crocodile',
        'A large reptile with strong jaws.',
        'The crocodile waited in the river.',
      ),
      Word(
        'rhinoceros',
        'A large mammal with a horn on its nose.',
        'The rhinoceros grazed in the grass.',
      ),
      Word(
        'hippopotamus',
        'A large animal that spends time in water.',
        'The hippopotamus yawned in the river.',
      ),
      Word(
        'chameleon',
        'A lizard that can change color.',
        'The chameleon blended with the branch.',
      ),
    ],
  ),
  ThemedWordPack(
    id: 'sports',
    aliases: {
      'sport',
      'sports',
      'game',
      'games',
      'soccer',
      'football',
      'basketball',
      'baseball',
      'tennis',
    },
    keywords: {
      'sport',
      'game',
      'team',
      'goal',
      'score',
      'coach',
      'athlete',
      'field',
      'court',
      'race',
      'tournament',
      'championship',
    },
    words: [
      Word(
        'ball',
        'A round object used in many sports.',
        'The ball bounced across the court.',
      ),
      Word(
        'team',
        'A group that plays or works together.',
        'The team practiced after school.',
      ),
      Word(
        'goal',
        'A point scored in some sports.',
        'She kicked the winning goal.',
      ),
      Word(
        'score',
        'The number of points in a game.',
        'The score was tied at halftime.',
      ),
      Word(
        'coach',
        'A person who trains a team or athlete.',
        'The coach called the next play.',
      ),
      Word(
        'soccer',
        'A sport played by kicking a ball into a goal.',
        'Soccer is played on a field.',
      ),
      Word(
        'tennis',
        'A sport played with rackets and a net.',
        'Tennis players served carefully.',
      ),
      Word(
        'hockey',
        'A sport played with sticks and a puck or ball.',
        'The hockey team skated fast.',
      ),
      Word(
        'racing',
        'A contest to see who is fastest.',
        'Racing takes speed and focus.',
      ),
      Word(
        'athlete',
        'A person trained in sports.',
        'The athlete stretched before the race.',
      ),
      Word(
        'pitcher',
        'A baseball player who throws the ball.',
        'The pitcher took a deep breath.',
      ),
      Word(
        'goalkeeper',
        'A player who guards the goal.',
        'The goalkeeper blocked the shot.',
      ),
      Word(
        'marathon',
        'A long running race.',
        'The marathon wound through the city.',
      ),
      Word(
        'stadium',
        'A large place where sports are played.',
        'Fans filled the stadium.',
      ),
      Word(
        'referee',
        'An official who enforces game rules.',
        'The referee blew the whistle.',
      ),
      Word(
        'tournament',
        'A series of games to find a winner.',
        'The tournament lasted all weekend.',
      ),
      Word(
        'gymnastics',
        'A sport with flips, jumps, and balance.',
        'Gymnastics requires strength and grace.',
      ),
      Word(
        'basketball',
        'A sport where teams shoot a ball through a hoop.',
        'Basketball practice began at four.',
      ),
      Word(
        'volleyball',
        'A sport where teams hit a ball over a net.',
        'Volleyball players called for the ball.',
      ),
      Word(
        'championship',
        'The final contest to decide a winner.',
        'The championship game was close.',
      ),
    ],
  ),
  ThemedWordPack(
    id: 'dinosaurs',
    aliases: {
      'dinosaur',
      'dinosaurs',
      'dino',
      'fossil',
      'prehistoric',
      'jurassic',
    },
    keywords: {
      'dinosaur',
      'fossil',
      'prehistoric',
      'jurassic',
      'cretaceous',
      'extinct',
      'paleontology',
      'skeleton',
      'raptor',
      'claw',
    },
    words: [
      Word(
        'egg',
        'A shell-covered object that some dinosaurs laid.',
        'The fossil egg was found in a nest.',
      ),
      Word(
        'claw',
        'A sharp curved nail on an animal or dinosaur.',
        'The raptor had a curved claw.',
      ),
      Word(
        'tail',
        'The back part of an animal or dinosaur.',
        'The dinosaur used its tail for balance.',
      ),
      Word(
        'track',
        'A footprint left in mud or stone.',
        'The track showed where a dinosaur walked.',
      ),
      Word(
        'amber',
        'Hardened tree resin that can preserve ancient things.',
        'A tiny insect was trapped in amber.',
      ),
      Word(
        'fossil',
        'The preserved remains of an ancient plant or animal.',
        'The fossil came from a dinosaur bone.',
      ),
      Word(
        'raptor',
        'A fast dinosaur with sharp claws.',
        'The raptor chased small prey.',
      ),
      Word(
        'skeleton',
        'The frame of bones inside a body.',
        'The museum displayed a dinosaur skeleton.',
      ),
      Word(
        'dinosaur',
        'A prehistoric reptile that lived long ago.',
        'The dinosaur exhibit filled the hall.',
      ),
      Word(
        'sauropod',
        'A large long-necked dinosaur.',
        'The sauropod stretched toward the trees.',
      ),
      Word(
        'herbivore',
        'An animal that eats plants.',
        'Many dinosaurs were herbivores.',
      ),
      Word(
        'carnivore',
        'An animal that eats meat.',
        'A carnivore hunted other animals.',
      ),
      Word(
        'extinction',
        'The dying out of a whole kind of living thing.',
        'Dinosaur extinction happened long ago.',
      ),
      Word(
        'excavate',
        'To carefully dig something out of the ground.',
        'Scientists excavate fossils with brushes.',
      ),
      Word(
        'jurassic',
        'Related to a time when many dinosaurs lived.',
        'Jurassic rocks can contain dinosaur fossils.',
      ),
      Word(
        'cretaceous',
        'Related to the last period of the dinosaurs.',
        'Cretaceous fossils were found nearby.',
      ),
      Word(
        'triceratops',
        'A dinosaur with three horns.',
        'The triceratops lowered its head.',
      ),
      Word(
        'stegosaurus',
        'A dinosaur with plates along its back.',
        'The stegosaurus model stood by the door.',
      ),
      Word(
        'velociraptor',
        'A small fast predatory dinosaur.',
        'The velociraptor had sharp claws.',
      ),
      Word(
        'paleontology',
        'The study of fossils and ancient life.',
        'Paleontology helps us understand dinosaurs.',
      ),
    ],
  ),
  ThemedWordPack(
    id: 'ocean',
    aliases: {'ocean', 'sea', 'beach', 'underwater', 'marine'},
    keywords: {
      'ocean',
      'sea',
      'water',
      'marine',
      'reef',
      'coral',
      'wave',
      'tide',
      'shore',
      'fish',
      'whale',
      'dolphin',
    },
    words: [
      Word(
        'fish',
        'An animal that lives and swims in water.',
        'The fish swam near the reef.',
      ),
      Word('wave', 'A moving ridge of water.', 'A wave rolled onto the beach.'),
      Word(
        'tide',
        'The regular rise and fall of the sea.',
        'The tide covered the rocks.',
      ),
      Word(
        'shell',
        'The hard outer covering of some sea animals.',
        'She found a shell by the shore.',
      ),
      Word(
        'reef',
        'A ridge of coral or rock under the sea.',
        'The reef was full of color.',
      ),
      Word(
        'coral',
        'A tiny sea animal that can form reefs.',
        'Coral grows in warm ocean water.',
      ),
      Word(
        'ocean',
        'A very large body of salt water.',
        'The ocean stretched to the horizon.',
      ),
      Word(
        'shark',
        'A large fish with sharp teeth.',
        'The shark swam below the boat.',
      ),
      Word('whale', 'A very large sea mammal.', 'The whale rose for air.'),
      Word('dolphin', 'A smart sea mammal.', 'The dolphin clicked underwater.'),
      Word(
        'current',
        'A steady flow of water in the ocean.',
        'The current carried the boat along.',
      ),
      Word(
        'harbor',
        'A sheltered place where boats can stay.',
        'The fishing boats rested in the harbor.',
      ),
      Word(
        'island',
        'Land with water all around it.',
        'The island had a quiet beach.',
      ),
      Word(
        'octopus',
        'A sea animal with eight arms.',
        'The octopus hid under a rock.',
      ),
      Word(
        'seahorse',
        'A small sea fish with a curled tail.',
        'The seahorse drifted among plants.',
      ),
      Word(
        'jellyfish',
        'A soft sea animal with stinging tentacles.',
        'A jellyfish floated in the water.',
      ),
      Word(
        'submarine',
        'A vessel that travels underwater.',
        'The submarine explored the deep ocean.',
      ),
      Word(
        'plankton',
        'Tiny organisms that drift in water.',
        'Many ocean animals eat plankton.',
      ),
      Word(
        'coastline',
        'The land along the edge of the sea.',
        'The coastline curved around the bay.',
      ),
      Word(
        'estuary',
        'A place where river water meets the sea.',
        'Birds gathered near the estuary.',
      ),
    ],
  ),
  ThemedWordPack(
    id: 'cooking',
    aliases: {'cooking', 'cook', 'kitchen', 'food', 'baking', 'recipe'},
    keywords: {
      'cook',
      'kitchen',
      'food',
      'bake',
      'recipe',
      'meal',
      'ingredient',
      'dessert',
      'bread',
      'sugar',
    },
    words: [
      Word(
        'milk',
        'A white drink often used in recipes.',
        'She poured milk into the batter.',
      ),
      Word('cake', 'A sweet baked dessert.', 'The cake cooled on the counter.'),
      Word(
        'bread',
        'A baked food made from flour.',
        'Warm bread smelled delicious.',
      ),
      Word(
        'sugar',
        'Sweet grains used in cooking and baking.',
        'He added sugar to the bowl.',
      ),
      Word(
        'spoon',
        'A tool used to scoop or stir food.',
        'The spoon clinked in the pot.',
      ),
      Word(
        'apple',
        'A fruit used in snacks and pies.',
        'She sliced an apple for lunch.',
      ),
      Word(
        'lemon',
        'A sour yellow fruit used in cooking.',
        'Lemon made the sauce bright.',
      ),
      Word(
        'cherry',
        'A small red fruit used in desserts.',
        'A cherry topped the cake.',
      ),
      Word(
        'kitchen',
        'The room where meals are prepared.',
        'The kitchen smelled like soup.',
      ),
      Word(
        'recipe',
        'Instructions for making food.',
        'The recipe called for cinnamon.',
      ),
      Word(
        'simmer',
        'To cook gently just below boiling.',
        'Let the soup simmer slowly.',
      ),
      Word(
        'butter',
        'A creamy food used in cooking and baking.',
        'Butter melted in the pan.',
      ),
      Word(
        'pancake',
        'A flat cake cooked on a hot pan.',
        'The pancake flipped neatly.',
      ),
      Word('toaster', 'A machine that browns bread.', 'The toaster popped up.'),
      Word(
        'cinnamon',
        'A sweet spice used in baking.',
        'Cinnamon sprinkled over the toast.',
      ),
      Word(
        'ingredient',
        'One item used to make a recipe.',
        'Flour is the first ingredient.',
      ),
      Word(
        'whisk',
        'To beat or stir food quickly.',
        'Whisk the eggs until smooth.',
      ),
      Word('skillet', 'A frying pan used for cooking.', 'The skillet was hot.'),
      Word(
        'dessert',
        'A sweet food served after a meal.',
        'Fruit was dessert after dinner.',
      ),
      Word(
        'casserole',
        'A baked dish cooked in one pan.',
        'The casserole fed the whole family.',
      ),
    ],
  ),
  ThemedWordPack(
    id: 'school',
    aliases: {'school', 'class', 'classroom', 'homework', 'teacher', 'reading'},
    keywords: {
      'school',
      'class',
      'teacher',
      'student',
      'homework',
      'book',
      'pencil',
      'lesson',
      'library',
      'study',
    },
    words: [
      Word(
        'book',
        'Pages bound together for reading.',
        'The book stayed on her desk.',
      ),
      Word(
        'pencil',
        'A tool used to write on paper.',
        'He sharpened his pencil.',
      ),
      Word(
        'school',
        'A place where children go to learn.',
        'School started after breakfast.',
      ),
      Word(
        'teacher',
        'A person who helps students learn.',
        'The teacher wrote on the board.',
      ),
      Word(
        'library',
        'A place where books are kept.',
        'The library was quiet.',
      ),
      Word(
        'homework',
        'Schoolwork done outside class.',
        'Homework took twenty minutes.',
      ),
      Word(
        'notebook',
        'A book of blank pages for notes.',
        'Her notebook was full of spelling words.',
      ),
      Word(
        'classroom',
        'A room where students learn.',
        'The classroom had bright posters.',
      ),
      Word(
        'recess',
        'A break during the school day.',
        'Recess was after math.',
      ),
      Word(
        'project',
        'A piece of schoolwork planned over time.',
        'The science project used magnets.',
      ),
      Word(
        'science',
        'The study of the natural world.',
        'Science class studied planets.',
      ),
      Word(
        'history',
        'The study of the past.',
        'History lessons covered ancient cities.',
      ),
      Word(
        'equation',
        'A math statement with equal values.',
        'The equation fit on one line.',
      ),
      Word(
        'grammar',
        'Rules for using words and sentences.',
        'Grammar helped the sentence make sense.',
      ),
      Word(
        'academy',
        'A school or place of learning.',
        'The academy hosted a spelling bee.',
      ),
      Word(
        'dictionary',
        'A book or tool that explains words.',
        'The dictionary gave the meaning.',
      ),
      Word(
        'assignment',
        'A task given by a teacher.',
        'The assignment was due Friday.',
      ),
      Word(
        'cafeteria',
        'A place where students eat at school.',
        'The cafeteria served soup.',
      ),
    ],
  ),
];
