import '../domain/puzzle.dart';

/// Coordinates are authored against the same 600 x 450 artboard as the
/// reused ScenePainter. Every visible glyph has a unique, non-overlapping
/// region; decorative furniture never hides an entire target.
abstract final class FeaturedScenes {
  static const templates = [
    'illustrated-home',
    'illustrated-garden',
    'illustrated-cafe',
  ];
  static const titles = [
    'Sunlit reading room',
    'The secret garden',
    'A corner café',
  ];
  static const categories = ['Home', 'Garden', 'Café'];

  static Puzzle create(
    int sceneNumber, {
    required int seed,
    int? level,
    String? id,
    int difficulty = 1,
    bool bundledImage = true,
  }) {
    RangeError.checkValueInInterval(sceneNumber, 1, 3, 'sceneNumber');
    final index = sceneNumber - 1;
    final number = level ?? sceneNumber;
    final puzzleId = id ?? 'hidden-${number.toString().padLeft(3, '0')}';
    final random = SeededRandom(seed);
    final objects = [
      for (final (i, placement) in _placements[index].indexed)
        SceneObject(
          id: '$puzzleId-object-$i',
          kind: placement.$1,
          region: Region(
            placement.$2 / 600,
            placement.$3 / 450,
            placement.$4 / 600,
            placement.$4 / 450,
          ),
          color: random.nextInt(6),
          rotation: (random.nextDouble() - .5) * .22,
        ),
    ];
    return Puzzle(
      id: puzzleId,
      mode: GameMode.hidden,
      title: '${titles[index]} · ${categories[index]}',
      category: categories[index],
      difficulty: difficulty,
      level: number,
      seed: seed,
      reward: 30 + difficulty * 5,
      parSeconds: 100 + difficulty * 15,
      timeLimitSeconds: 240 + difficulty * 20,
      answerIds: objects.take(5 + difficulty).map((o) => o.id).toList(),
      rounds: const [],
      scene: SceneData(
        template: templates[index],
        palette: random.nextInt(6),
        layout: index,
        seed: seed,
        objects: objects,
      ),
      imageA: bundledImage ? 'assets/scenes/$puzzleId-a.png' : null,
    );
  }

  // First entries are targets; later entries are recognizable distractors.
  // Positions follow shelves, seating, worktops, flower beds and pathways,
  // rather than a regular grid of floating icons.
  static const _placements = <List<(String, double, double, double)>>[
    [
      ('key', 112, 135, 40),
      ('book', 164, 66, 40),
      ('mug', 275, 306, 44),
      ('cat', 455, 319, 60),
      ('camera', 377, 146, 44),
      ('hat', 59, 279, 46),
      ('plant', 42, 38, 55),
      ('vase', 104, 43, 49),
      ('clock', 239, 42, 51),
      ('notebook', 43, 126, 40),
      ('gift', 163, 137, 40),
      ('lantern', 43, 211, 44),
      ('teapot', 105, 213, 47),
      ('basket', 163, 220, 44),
      ('apple', 350, 318, 37),
      ('ball', 195, 359, 47),
      ('backpack', 520, 262, 49),
      ('umbrella', 525, 179, 51),
      ('feather', 370, 234, 36),
      ('map', 266, 224, 47),
      ('bottle', 112, 356, 38),
      ('shoe', 389, 384, 45),
      ('dog', 46, 359, 50),
      ('pencil', 225, 158, 36),
      ('flower', 469, 201, 48),
      ('star', 456, 80, 34),
      ('globe', 300, 110, 42),
    ],
    [
      ('butterfly', 105, 91, 38),
      ('binoculars', 365, 257, 43),
      ('key', 139, 313, 35),
      ('apple', 452, 206, 38),
      ('hat', 51, 261, 46),
      ('bottle', 245, 378, 38),
      ('plant', 39, 169, 48),
      ('book', 174, 265, 40),
      ('mug', 220, 278, 38),
      ('shell', 323, 384, 38),
      ('feather', 520, 330, 35),
      ('bird', 252, 66, 40),
      ('clock', 404, 113, 43),
      ('cat', 548, 267, 46),
      ('ball', 67, 358, 46),
      ('umbrella', 146, 201, 48),
      ('map', 492, 88, 43),
      ('lantern', 551, 168, 39),
      ('teapot', 408, 321, 44),
      ('basket', 336, 315, 46),
      ('camera', 323, 205, 41),
      ('leaf', 181, 86, 40),
      ('flower', 486, 371, 51),
      ('train', 155, 386, 43),
      ('star', 346, 45, 35),
      ('dog', 9, 323, 46),
      ('notebook', 213, 187, 41),
      ('vase', 388, 383, 43),
      ('scooter', 259, 320, 49),
    ],
    [
      ('donut', 108, 191, 38),
      ('teapot', 331, 303, 46),
      ('key', 259, 362, 35),
      ('book', 84, 89, 40),
      ('camera', 478, 147, 42),
      ('cat', 507, 356, 52),
      ('mug', 160, 187, 42),
      ('cake', 48, 184, 56),
      ('notebook', 139, 92, 37),
      ('bottle', 196, 86, 39),
      ('plant', 339, 79, 54),
      ('vase', 485, 37, 51),
      ('clock', 243, 41, 52),
      ('gift', 205, 278, 42),
      ('apple', 69, 132, 40),
      ('bread', 154, 132, 41),
      ('basket', 144, 255, 55),
      ('lemon', 432, 307, 37),
      ('flower', 400, 153, 44),
      ('hat', 435, 366, 43),
      ('lantern', 423, 44, 39),
      ('umbrella', 550, 207, 47),
      ('backpack', 472, 238, 49),
      ('feather', 324, 206, 36),
      ('map', 358, 356, 48),
      ('bird', 283, 123, 40),
      ('shell', 203, 394, 39),
      ('ball', 99, 380, 50),
      ('pencil', 278, 238, 35),
      ('cherry', 252, 306, 37),
      ('shoe', 409, 412, 36),
      ('train', 340, 405, 40),
    ],
  ];
}
