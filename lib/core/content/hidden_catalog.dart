import '../domain/puzzle.dart';
import 'featured_scenes.dart';
import 'puzzle_generator.dart';

/// Reuses FindIt's 60 hidden-object levels, replacing the first three
/// compositions with richer, deliberately placed illustrated scenes.
abstract final class HiddenCatalog {
  static const levelCount = 60;

  static List<Puzzle> launchCatalog() => [
    for (var level = 1; level <= levelCount; level++)
      if (level <= 3)
        FeaturedScenes.create(
          level,
          seed: stableSeed('findit-v1-hidden-$level'),
        )
      else
        PuzzleGenerator.generate(
          GameMode.hidden,
          seed: stableSeed('findit-v1-hidden-$level'),
          level: level,
        ),
  ];
}
