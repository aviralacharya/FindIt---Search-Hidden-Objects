import '../domain/puzzle.dart';

const spotCategories = [
  'Living room',
  'Kitchen',
  'Bedroom',
  'Animals',
  'Nature',
  'Beach',
  'City',
  'Food',
  'Transportation',
  'Everyday objects',
];
const hiddenCategories = [
  'Home',
  'Garden',
  'Shopping mall',
  'Beach',
  'Forest',
  'Restaurant',
  'School',
  'Travel',
  'City',
  'Adventure',
];
const sceneTemplates = [
  'illustrated-home',
  'illustrated-garden',
  'illustrated-cafe',
  'living',
  'kitchen',
  'bedroom',
  'animals',
  'nature',
  'beach',
  'city',
  'food',
  'transport',
  'studio',
  'home',
  'garden',
  'mall',
  'forest',
  'restaurant',
  'school',
  'travel',
  'adventure',
];

const _spotTemplates = [
  'living',
  'kitchen',
  'bedroom',
  'animals',
  'nature',
  'beach',
  'city',
  'food',
  'transport',
  'studio',
];
const _hiddenTemplates = [
  'home',
  'garden',
  'mall',
  'beach',
  'forest',
  'restaurant',
  'school',
  'travel',
  'city',
  'adventure',
];
const _moments = [
  'Morning light',
  'A cozy corner',
  'Sunday afternoon',
  'Little treasures',
  'Golden hour',
  'A quiet moment',
];
const _pairs = <String, String>{
  'apple': 'pear',
  'pear': 'apple',
  'cat': 'dog',
  'dog': 'cat',
  'clock': 'compass',
  'compass': 'clock',
  'mug': 'teapot',
  'teapot': 'mug',
  'plant': 'flower',
  'flower': 'plant',
  'ball': 'donut',
  'donut': 'ball',
  'boat': 'car',
  'car': 'boat',
  'star': 'shell',
  'shell': 'star',
  'lemon': 'strawberry',
  'strawberry': 'lemon',
  'book': 'notebook',
  'notebook': 'book',
  'hat': 'umbrella',
  'umbrella': 'hat',
  'rocket': 'telescope',
  'telescope': 'rocket',
  'basket': 'gift',
  'gift': 'basket',
};

class PuzzleGenerator {
  static List<Puzzle> launchCatalog() => [
    for (final mode in GameMode.values.where((m) => m != GameMode.daily))
      for (var level = 1; level <= 60; level++)
        generate(
          mode,
          seed: stableSeed('findit-v1-${mode.slug}-$level'),
          level: level,
        ),
  ];

  static Puzzle generate(
    GameMode mode, {
    required int seed,
    required int level,
    String? id,
    int? difficulty,
  }) {
    if (mode == GameMode.daily) {
      throw ArgumentError('Daily is a set of puzzles.');
    }
    final d = difficulty ?? clampInt(1 + (level - 1) ~/ 12, 1, 5);
    final rng = SeededRandom(seed);
    final puzzleId = id ?? '${mode.slug}-${level.toString().padLeft(3, '0')}';
    if (mode.isScene) return _scene(mode, puzzleId, level, seed, d, rng);
    final rounds = <PuzzleRound>[];
    final count = switch (mode) {
      GameMode.odd => 4 + d,
      GameMode.memory => 3,
      GameMode.quick => 6 + d,
      _ => 0,
    };
    for (var round = 0; round < count; round++) {
      rounds.add(switch (mode) {
        GameMode.odd => _odd(rng, d),
        GameMode.memory => _memory(
          rng,
          d,
          MemoryRule.values[(level + round - 1) % 4],
        ),
        GameMode.quick => _quick(rng, d, round),
        _ => throw StateError('Unsupported grid mode'),
      });
    }
    return Puzzle(
      id: puzzleId,
      mode: mode,
      title: switch (mode) {
        GameMode.odd => [
          'A fresh perspective',
          'Tiny details',
          'Not quite twins',
          'The little exception',
          'A sharp eye',
          'Stand out',
        ][rng.nextInt(6)],
        GameMode.memory => [
          'Picture this',
          'A moment to remember',
          'Mindful little things',
          'Now you see it',
          'Keep it in mind',
          'A good memory',
        ][rng.nextInt(6)],
        _ => [
          'Ready, set, find',
          'In a heartbeat',
          'On the lookout',
          'Find your rhythm',
          'Eyes on the prize',
          'A little faster',
        ][rng.nextInt(6)],
      },
      category: mode == GameMode.memory
          ? 'Observation & recall'
          : [
              'Little things',
              'Nature notes',
              'Everyday favorites',
              'Color & shape',
            ][rng.nextInt(4)],
      difficulty: d,
      level: level,
      seed: seed,
      reward: 25 + d * 5,
      parSeconds: mode == GameMode.quick ? 35 + d * 5 : 45 + d * 8,
      timeLimitSeconds: switch (mode) {
        GameMode.quick => 50 + d * 9,
        GameMode.odd => 100 + d * 8,
        _ => 0,
      },
      answerIds: const [],
      rounds: rounds,
    );
  }

  static Puzzle _scene(
    GameMode mode,
    String id,
    int level,
    int seed,
    int difficulty,
    SeededRandom rng,
  ) {
    final categoryIndex = (level - 1) % 10;
    final layout = (level - 1) ~/ 10;
    final template = mode == GameMode.differences
        ? _spotTemplates[categoryIndex]
        : _hiddenTemplates[categoryIndex];
    final categories = mode == GameMode.differences
        ? spotCategories
        : hiddenCategories;
    final kinds = List<String>.of(objectKinds);
    rng.shuffle(kinds);
    final slots = <Region>[];
    // Purposefully separated silhouettes. Clutter comes from the background,
    // never from overlapping target hit regions or invisible objects.
    final columns = difficulty >= 4 ? 6 : 5;
    final rows = 4;
    final w = columns == 6 ? .113 : .132;
    final h = w * 4 / 3;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        final x = .022 + col * (.95 / columns) + rng.nextDouble() * .021;
        final y = .115 + row * .207 + rng.nextDouble() * .012;
        slots.add(Region(x, y, w, h));
      }
    }
    rng.shuffle(slots);
    final targets = mode == GameMode.differences ? 5 : 5 + difficulty;
    final objects = <SceneObject>[];
    final answerIds = <String>[];
    for (var i = 0; i < slots.length; i++) {
      final objectId = '$id-object-$i';
      final kind = kinds[i];
      final color = rng.nextInt(6);
      final isTarget = i < targets;
      if (isTarget) answerIds.add(objectId);
      final changed = mode == GameMode.differences && isTarget;
      // Exactly five edits: two silhouette changes, two clear color changes,
      // and one removed object. No added marks outside the answer regions.
      objects.add(
        SceneObject(
          id: objectId,
          kind: kind,
          region: slots[i],
          color: color,
          variant: 0,
          rotation: (rng.nextDouble() - .5) * .18,
          alternateKind: changed && i < 2
              ? (_pairs[kind] ?? kinds[slots.length + i])
              : null,
          alternateColor: changed && (i == 2 || i == 3)
              ? (color + 3) % 6
              : null,
          alternateHidden: changed && i == 4,
        ),
      );
    }
    // Put target IDs in scene drawing order, but keep target locations shuffled.
    rng.shuffle(objects);
    return Puzzle(
      id: id,
      mode: mode,
      title: '${_moments[layout % 6]} · ${categories[categoryIndex]}',
      category: categories[categoryIndex],
      difficulty: difficulty,
      level: level,
      seed: seed,
      reward: 30 + difficulty * 5,
      parSeconds: 100 + difficulty * 15,
      timeLimitSeconds: 240 + difficulty * 20,
      answerIds: answerIds,
      rounds: const [],
      scene: SceneData(
        template: template,
        palette: rng.nextInt(6),
        layout: layout,
        seed: seed,
        objects: objects,
      ),
      imageA: 'assets/scenes/$id-a.png',
      imageB: mode == GameMode.differences ? 'assets/scenes/$id-b.png' : null,
    );
  }

  static PuzzleRound _odd(SeededRandom rng, int difficulty) {
    final columns = clampInt(2 + difficulty, 3, 6);
    final pool = _pairs.keys.toList();
    final kind = pool[rng.nextInt(pool.length)];
    final color = rng.nextInt(6);
    final oddAt = rng.nextInt(columns * columns);
    final useColor = difficulty >= 4 && rng.nextInt(2) == 0;
    final tiles = List<TileData>.generate(
      columns * columns,
      (i) => TileData(
        kind: i == oddAt && !useColor ? _pairs[kind]! : kind,
        color: i == oddAt && useColor ? (color + 3) % 6 : color,
      ),
    );
    return PuzzleRound(columns: columns, tiles: tiles, answers: [oddAt]);
  }

  static PuzzleRound _quick(SeededRandom rng, int difficulty, int round) {
    final columns = clampInt(3 + (difficulty + round ~/ 3) ~/ 2, 3, 6);
    final kinds = List<String>.of(objectKinds);
    rng.shuffle(kinds);
    final count = columns * columns;
    final tiles = [
      for (var i = 0; i < count; i++)
        TileData(kind: kinds[i], color: rng.nextInt(6)),
    ];
    final targetIndex = rng.nextInt(count);
    return PuzzleRound(
      columns: columns,
      tiles: tiles,
      answers: [targetIndex],
      target: tiles[targetIndex],
    );
  }

  static PuzzleRound _memory(
    SeededRandom rng,
    int difficulty,
    MemoryRule rule,
  ) {
    final pool = List<String>.of(objectKinds);
    rng.shuffle(pool);
    final count = 4 + difficulty;
    final original = [
      for (var i = 0; i < count; i++)
        TileData(kind: pool[i], color: rng.nextInt(6)),
    ];
    final index = rng.nextInt(count);
    final seconds = clampInt(7 - difficulty, 3, 6);
    switch (rule) {
      case MemoryRule.disappeared:
        final choices = [
          original[index],
          ...original.where((t) => t.kind != original[index].kind).take(3),
        ];
        rng.shuffle(choices);
        final preview = List<TileData>.of(original);
        // The UI shows the remaining objects above the answer choices, so the
        // user observes a genuine disappearance rather than a trivia question.
        return PuzzleRound(
          columns: 2,
          tiles: choices,
          answers: [choices.indexWhere((t) => t.kind == original[index].kind)],
          target: original[index],
          preview: preview,
          rule: rule,
          previewSeconds: seconds,
        );
      case MemoryRule.added:
        final added = TileData(kind: pool[count], color: rng.nextInt(6));
        final after = [...original, added];
        rng.shuffle(after);
        return PuzzleRound(
          columns: 3,
          tiles: after,
          answers: [after.indexOf(added)],
          preview: original,
          rule: rule,
          previewSeconds: seconds,
        );
      case MemoryRule.moved:
        final other = (index + 1 + rng.nextInt(count - 1)) % count;
        final after = List<TileData>.of(original);
        after[index] = original[other];
        after[other] = original[index];
        return PuzzleRound(
          columns: 3,
          tiles: after,
          answers: [index, other],
          preview: original,
          rule: rule,
          previewSeconds: seconds,
        );
      case MemoryRule.duplicated:
        final preview = [...original, original[index]];
        rng.shuffle(preview);
        final choices = [
          original[index],
          ...original.where((t) => t.kind != original[index].kind).take(3),
        ];
        rng.shuffle(choices);
        return PuzzleRound(
          columns: 2,
          tiles: choices,
          answers: [choices.indexWhere((t) => t.kind == original[index].kind)],
          preview: preview,
          rule: rule,
          previewSeconds: seconds,
        );
    }
  }
}
