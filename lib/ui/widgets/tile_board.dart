import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/art/object_art.dart';
import '../../core/domain/puzzle.dart';

class TileBoard extends StatelessWidget {
  const TileBoard({
    super.key,
    required this.tiles,
    required this.columns,
    this.onTap,
    this.selected = const {},
    this.eliminated = const {},
    this.hint,
    this.wrong,
    this.numbered = false,
    this.boardKey = 'tiles',
  });
  final List<TileData> tiles;
  final int columns;
  final void Function(int)? onTap;
  final Set<int> selected;
  final Set<int> eliminated;
  final int? hint;
  final int? wrong;
  final bool numbered;
  final String boardKey;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 9.0;
      // Reflow only when necessary to keep tappable tiles at least 48 logical px.
      // Memory position puzzles always have three columns and preserve their order.
      final actualColumns = math.min(
        columns,
        math.max(2, ((constraints.maxWidth + gap) / 57).floor()),
      );
      final tileSize =
          (constraints.maxWidth - gap * (actualColumns - 1)) / actualColumns;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tiles.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: actualColumns,
          crossAxisSpacing: gap,
          mainAxisSpacing: gap,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final tile = tiles[index];
          final found = selected.contains(index);
          final hidden = eliminated.contains(index);
          final active = onTap != null && !hidden && !found;
          final border = found
              ? FindItColors.forest
              : wrong == index
              ? FindItColors.coral
              : hint == index
              ? FindItColors.gold
              : FindItColors.line;
          return Semantics(
            label:
                '${numbered ? 'Position ${index + 1}, ' : ''}${objectDescription(tile.kind, color: tile.color, variant: tile.variant)}${found
                    ? ', found'
                    : hidden
                    ? ', eliminated'
                    : hint == index
                    ? ', hint highlighted'
                    : ''}',
            button: onTap != null,
            enabled: onTap != null ? active : null,
            selected: onTap != null ? found : null,
            onTap: active ? () => onTap!(index) : null,
            excludeSemantics: true,
            child: Opacity(
              opacity: hidden ? .16 : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  color: found ? const Color(0xFFE7EFE2) : FindItColors.paper,
                  borderRadius: BorderRadius.circular(tileSize > 70 ? 17 : 12),
                  border: Border.all(
                    color: border,
                    width: found || hint == index || wrong == index ? 2 : 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('$boardKey-$index'),
                    borderRadius: BorderRadius.circular(15),
                    onTap: active ? () => onTap!(index) : null,
                    child: Stack(
                      children: [
                        Center(
                          child: ObjectGlyph(
                            tile.kind,
                            colorIndex: tile.color,
                            variant: tile.variant,
                            size: tileSize * .69,
                            semanticLabel: false,
                          ),
                        ),
                        if (numbered)
                          Positioned(
                            top: 6,
                            left: 8,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 10,
                                color: FindItColors.muted,
                              ),
                            ),
                          ),
                        if (found)
                          const Positioned(
                            top: 5,
                            right: 5,
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: FindItColors.forest,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
