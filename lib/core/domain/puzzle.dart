import 'dart:math' as math;

enum GameMode {
  differences(
    'spot',
    'Spot the Difference',
    'A little change. A big discovery.',
    'SPOT',
  ),
  hidden(
    'hidden',
    'Hidden Objects',
    'Little treasures, hiding in plain sight.',
    'SEEK',
  ),
  odd(
    'odd',
    'Find the Odd One',
    'One of these is not like the others.',
    'NOTICE',
  ),
  memory(
    'memory',
    'Memory Challenge',
    'Look. Remember. Surprise yourself.',
    'REMEMBER',
  ),
  quick(
    'quick',
    'Quick Find',
    'Sharp eyes. Quick taps. Keep the combo.',
    'FOCUS',
  ),
  daily(
    'daily',
    'Daily Challenge',
    'A fresh little adventure, every day.',
    'TODAY',
  );

  const GameMode(this.slug, this.title, this.subtitle, this.eyebrow);
  final String slug;
  final String title;
  final String subtitle;
  final String eyebrow;

  static GameMode fromSlug(String slug) =>
      values.firstWhere((mode) => mode.slug == slug);

  String get instructions => switch (this) {
    differences =>
      'Compare the pictures. Tap each difference in either picture.',
    hidden => 'Find the objects on your list. Tap them in the scene.',
    odd => 'Look closely at the grid. Tap the one object that is different.',
    memory => 'Remember the objects, then answer what changed.',
    quick => 'Find the target in the grid. Accurate taps build your combo.',
    daily => 'Finish all three puzzles to collect your daily bonus.',
  };

  bool get isScene => this == differences || this == hidden;
}

/// Coordinates are normalized to the original image, never the screen.
class Region {
  const Region(this.x, this.y, this.width, this.height);
  final double x;
  final double y;
  final double width;
  final double height;
  double get centerX => x + width / 2;
  double get centerY => y + height / 2;

  bool contains(double px, double py) =>
      px >= x && px <= x + width && py >= y && py <= y + height;

  bool overlaps(Region other, {double padding = 0}) =>
      x < other.x + other.width + padding &&
      x + width + padding > other.x &&
      y < other.y + other.height + padding &&
      y + height + padding > other.y;

  bool get valid =>
      [x, y, width, height].every((v) => v.isFinite) &&
      x >= 0 &&
      y >= 0 &&
      width > 0 &&
      height > 0 &&
      x + width <= 1.000001 &&
      y + height <= 1.000001;

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'w': width, 'h': height};
  factory Region.fromJson(Map<String, dynamic> json) => Region(
    (json['x'] as num).toDouble(),
    (json['y'] as num).toDouble(),
    (json['w'] as num).toDouble(),
    (json['h'] as num).toDouble(),
  );
}

const objectKinds = <String>[
  'plant',
  'vase',
  'clock',
  'book',
  'mug',
  'cat',
  'cake',
  'apple',
  'pear',
  'lemon',
  'camera',
  'umbrella',
  'bird',
  'fish',
  'boat',
  'car',
  'scooter',
  'train',
  'hat',
  'key',
  'shoe',
  'ball',
  'star',
  'shell',
  'feather',
  'leaf',
  'butterfly',
  'flower',
  'gift',
  'basket',
  'lantern',
  'teapot',
  'binoculars',
  'map',
  'compass',
  'bottle',
  'watermelon',
  'strawberry',
  'donut',
  'pizza',
  'bread',
  'pineapple',
  'backpack',
  'pencil',
  'notebook',
  'ruler',
  'globe',
  'flag',
  'telescope',
  'rocket',
  'dog',
  'cherry',
];

String objectLabel(String kind) => switch (kind) {
  'plant' => 'Potted plant',
  'mug' => 'Cup',
  'ball' => 'Beach ball',
  'binoculars' => 'Binoculars',
  'watermelon' => 'Melon slice',
  'backpack' => 'Backpack',
  _ => kind.isEmpty ? '' : '${kind[0].toUpperCase()}${kind.substring(1)}',
};

const objectColorNames = [
  'coral',
  'blue',
  'green',
  'gold',
  'purple',
  'slate blue',
];

/// Describes the same shape, accent color, and markings rendered by ObjectPainter.
/// Labels never identify whether an object is an answer.
String objectDescription(String kind, {int color = 0, int variant = 0}) {
  final markings = switch (variant) {
    1 => 'white stripe',
    2 => 'white spots',
    _ => 'plain',
  };
  return '${objectLabel(kind)}, ${objectColorNames[color % objectColorNames.length]}, $markings';
}

class SceneObject {
  const SceneObject({
    required this.id,
    required this.kind,
    required this.region,
    this.color = 0,
    this.variant = 0,
    this.rotation = 0,
    this.alternateKind,
    this.alternateColor,
    this.alternateVariant,
    this.alternateHidden = false,
  });
  final String id;
  final String kind;
  final Region region;
  final int color;
  final int variant;
  final double rotation;
  final String? alternateKind;
  final int? alternateColor;
  final int? alternateVariant;
  final bool alternateHidden;

  bool get hasDifference =>
      alternateHidden ||
      alternateKind != null ||
      alternateColor != null ||
      alternateVariant != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'region': region.toJson(),
    'color': color,
    'variant': variant,
    'rotation': rotation,
    if (alternateKind != null) 'alternateKind': alternateKind,
    if (alternateColor != null) 'alternateColor': alternateColor,
    if (alternateVariant != null) 'alternateVariant': alternateVariant,
    if (alternateHidden) 'alternateHidden': true,
  };

  factory SceneObject.fromJson(Map<String, dynamic> j) => SceneObject(
    id: j['id'] as String,
    kind: j['kind'] as String,
    region: Region.fromJson(j['region'] as Map<String, dynamic>),
    color: j['color'] as int? ?? 0,
    variant: j['variant'] as int? ?? 0,
    rotation: (j['rotation'] as num? ?? 0).toDouble(),
    alternateKind: j['alternateKind'] as String?,
    alternateColor: j['alternateColor'] as int?,
    alternateVariant: j['alternateVariant'] as int?,
    alternateHidden: j['alternateHidden'] as bool? ?? false,
  );
}

class SceneData {
  const SceneData({
    required this.template,
    required this.palette,
    required this.layout,
    required this.seed,
    required this.objects,
  });
  final String template;
  final int palette;
  final int layout;
  final int seed;
  final List<SceneObject> objects;

  Map<String, dynamic> toJson() => {
    'template': template,
    'palette': palette,
    'layout': layout,
    'seed': seed,
    'objects': objects.map((o) => o.toJson()).toList(),
  };
  factory SceneData.fromJson(Map<String, dynamic> j) => SceneData(
    template: j['template'] as String,
    palette: j['palette'] as int,
    layout: j['layout'] as int,
    seed: j['seed'] as int,
    objects: (j['objects'] as List)
        .map((v) => SceneObject.fromJson(v as Map<String, dynamic>))
        .toList(),
  );
}

class TileData {
  const TileData({required this.kind, this.color = 0, this.variant = 0});
  final String kind;
  final int color;
  final int variant;
  String get signature => '$kind:$color:$variant';
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'color': color,
    'variant': variant,
  };
  factory TileData.fromJson(Map<String, dynamic> j) => TileData(
    kind: j['kind'] as String,
    color: j['color'] as int? ?? 0,
    variant: j['variant'] as int? ?? 0,
  );
}

enum MemoryRule { disappeared, added, moved, duplicated }

class PuzzleRound {
  const PuzzleRound({
    required this.columns,
    required this.tiles,
    required this.answers,
    this.target,
    this.preview = const [],
    this.rule,
    this.previewSeconds = 4,
  });
  final int columns;
  final List<TileData> tiles;
  final List<int> answers;
  final TileData? target;
  final List<TileData> preview;
  final MemoryRule? rule;
  final int previewSeconds;
  String get question => switch (rule) {
    MemoryRule.disappeared => 'Which object disappeared?',
    MemoryRule.added => 'Which object was added?',
    MemoryRule.moved => 'Tap the two positions that changed.',
    MemoryRule.duplicated => 'Which object appeared twice?',
    null => 'Find the target',
  };

  Map<String, dynamic> toJson() => {
    'columns': columns,
    'tiles': tiles.map((t) => t.toJson()).toList(),
    'answers': answers,
    'preview': preview.map((t) => t.toJson()).toList(),
    'previewSeconds': previewSeconds,
    if (target != null) 'target': target!.toJson(),
    if (rule != null) 'rule': rule!.name,
  };
  factory PuzzleRound.fromJson(Map<String, dynamic> j) => PuzzleRound(
    columns: j['columns'] as int,
    tiles: (j['tiles'] as List)
        .map((t) => TileData.fromJson(t as Map<String, dynamic>))
        .toList(),
    answers: (j['answers'] as List).cast<int>(),
    target: j['target'] == null
        ? null
        : TileData.fromJson(j['target'] as Map<String, dynamic>),
    preview: (j['preview'] as List? ?? [])
        .map((t) => TileData.fromJson(t as Map<String, dynamic>))
        .toList(),
    rule: j['rule'] == null
        ? null
        : MemoryRule.values.byName(j['rule'] as String),
    previewSeconds: j['previewSeconds'] as int? ?? 4,
  );
}

class Puzzle {
  const Puzzle({
    required this.id,
    required this.mode,
    required this.title,
    required this.category,
    required this.difficulty,
    required this.level,
    required this.seed,
    required this.reward,
    required this.parSeconds,
    required this.timeLimitSeconds,
    required this.answerIds,
    required this.rounds,
    this.scene,
    this.imageA,
    this.imageB,
    this.validation = 'automated',
    this.generatorVersion = 1,
  });
  final String id;
  final GameMode mode;
  final String title;
  final String category;
  final int difficulty;
  final int level;
  final int seed;
  final int reward;
  final int parSeconds;
  final int timeLimitSeconds;
  final List<String> answerIds;
  final List<PuzzleRound> rounds;
  final SceneData? scene;
  final String? imageA;
  final String? imageB;
  final String validation;
  final int generatorVersion;

  int get totalAnswers => mode.isScene
      ? answerIds.length
      : rounds.fold(0, (sum, r) => sum + r.answers.length);
  String get difficultyLabel => difficulty <= 2
      ? 'Easy'
      : difficulty <= 4
      ? 'Medium'
      : 'Hard';

  Map<String, dynamic> toJson() => {
    'id': id,
    'mode': mode.slug,
    'title': title,
    'category': category,
    'difficulty': difficulty,
    'level': level,
    'seed': seed,
    'reward': reward,
    'parSeconds': parSeconds,
    'timeLimitSeconds': timeLimitSeconds,
    'answerIds': answerIds,
    'rounds': rounds.map((r) => r.toJson()).toList(),
    'validation': validation,
    'generatorVersion': generatorVersion,
    if (scene != null) 'scene': scene!.toJson(),
    if (imageA != null) 'imageA': imageA,
    if (imageB != null) 'imageB': imageB,
  };
  factory Puzzle.fromJson(Map<String, dynamic> j) => Puzzle(
    id: j['id'] as String,
    mode: GameMode.fromSlug(j['mode'] as String),
    title: j['title'] as String,
    category: j['category'] as String,
    difficulty: j['difficulty'] as int,
    level: j['level'] as int,
    seed: j['seed'] as int,
    reward: j['reward'] as int,
    parSeconds: j['parSeconds'] as int,
    timeLimitSeconds: j['timeLimitSeconds'] as int,
    answerIds: (j['answerIds'] as List).cast<String>(),
    rounds: (j['rounds'] as List)
        .map((r) => PuzzleRound.fromJson(r as Map<String, dynamic>))
        .toList(),
    scene: j['scene'] == null
        ? null
        : SceneData.fromJson(j['scene'] as Map<String, dynamic>),
    imageA: j['imageA'] as String?,
    imageB: j['imageB'] as String?,
    validation: j['validation'] as String? ?? 'unvalidated',
    generatorVersion: j['generatorVersion'] as int? ?? 1,
  );
}

/// A small versioned PRNG: unlike Random/hashCode, stable across runtimes.
class SeededRandom {
  SeededRandom(int seed) : _state = seed & 0xffffffff;
  int _state;
  int nextInt(int maximum) {
    if (maximum <= 0) throw ArgumentError.value(maximum);
    _state = (1664525 * _state + 1013904223) & 0xffffffff;
    return ((_state >>> 8) % maximum);
  }

  double nextDouble() => nextInt(1 << 24) / (1 << 24);
  void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
  }
}

int stableSeed(String value) {
  var hash = 2166136261;
  for (final char in value.codeUnits) {
    final value32 = hash ^ char;
    // Keep every intermediate below 2^53. The naive FNV multiplication can
    // lose low bits in JavaScript, changing offline daily sets across platforms.
    hash =
        ((value32 & 0xffff) * 16777619 +
            (((value32 >>> 16) * 16777619) & 0xffff) * 65536) &
        0xffffffff;
  }
  return hash;
}

int clampInt(int value, int low, int high) =>
    math.max(low, math.min(value, high));
