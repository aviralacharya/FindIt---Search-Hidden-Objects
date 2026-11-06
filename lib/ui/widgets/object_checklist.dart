import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/art/object_art.dart';
import '../../core/domain/game_engine.dart';
import '../../core/domain/puzzle.dart';

/// A pinned checklist, independent of the scene's pan/zoom transform.
class ObjectChecklist extends StatelessWidget {
  const ObjectChecklist({super.key, required this.game, this.vertical = false});
  final GameEngine game;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final objects = [
      for (final id in game.puzzle.answerIds)
        game.puzzle.scene!.objects.firstWhere((o) => o.id == id),
    ];
    Widget item(int index) {
      final object = objects[index];
      final found = game.found.contains(object.id);
      return Semantics(
        key: ValueKey('target-${object.id}'),
        label:
            '${objectDescription(object.kind, color: object.color, variant: object.variant)}, ${found ? 'found' : 'still to find'}',
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: found ? FindItColors.sage : FindItColors.cream,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: found ? FindItColors.forest : FindItColors.line,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Opacity(
                    opacity: found ? .45 : 1,
                    child: ObjectGlyph(
                      object.kind,
                      colorIndex: object.color,
                      variant: object.variant,
                      size: 45,
                      semanticLabel: false,
                    ),
                  ),
                  if (found)
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 19,
                        color: FindItColors.forest,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                objectLabel(object.kind),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  decoration: found ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final header = Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Find these objects',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Text(
            '${game.answersFound}/${objects.length}',
            style: const TextStyle(
              color: FindItColors.forest,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    return Column(
      key: const ValueKey('search-object-checklist'),
      mainAxisSize: vertical ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (vertical)
          Expanded(
            child: GridView.builder(
              itemCount: objects.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 92 + (scale - 1) * 24,
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
              ),
              itemBuilder: (_, index) => item(index),
            ),
          )
        else
          SizedBox(
            height: 90 + (scale - 1) * 24,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: objects.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) =>
                  SizedBox(width: 80 + (scale - 1) * 18, child: item(index)),
            ),
          ),
      ],
    );
  }
}
