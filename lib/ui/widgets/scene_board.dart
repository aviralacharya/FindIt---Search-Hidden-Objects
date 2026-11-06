import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/art/scene_art.dart';
import '../../core/domain/puzzle.dart';

class SceneBoard extends StatefulWidget {
  const SceneBoard({
    super.key,
    required this.puzzle,
    required this.alternate,
    required this.found,
    this.onTap,
    this.hintId,
    this.hintIsPrecise = true,
    this.fillAvailable = false,
    this.wrongPoint,
  });
  final Puzzle puzzle;
  final bool alternate;
  final Set<String> found;
  final String? hintId;
  final bool hintIsPrecise;
  final bool fillAvailable;
  final Offset? wrongPoint;
  final void Function(double x, double y)? onTap;
  @override
  State<SceneBoard> createState() => _SceneBoardState();
}

class _SceneBoardState extends State<SceneBoard> {
  final _transform = TransformationController();
  Size _viewportSize = Size.zero;
  Size _sceneSize = Size.zero;
  Matrix4 _homeTransform = Matrix4.identity();
  String? _lastHint;
  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.alternate
        ? widget.puzzle.imageB
        : widget.puzzle.imageA;
    final viewport = LayoutBuilder(
      key: const ValueKey('scene-viewport'),
      builder: (context, constraints) {
        final size = constraints.biggest;
        final width = widget.fillAvailable
            ? math.max(size.width, size.height * 4 / 3)
            : size.width;
        final contentSize = Size(width, width * 3 / 4);
        final resized = size != _viewportSize || contentSize != _sceneSize;
        _viewportSize = size;
        _sceneSize = contentSize;
        _homeTransform = Matrix4.translationValues(
          (size.width - contentSize.width) / 2,
          (size.height - contentSize.height) / 2,
          0,
        );
        final hint = widget.hintId == null
            ? null
            : '${widget.hintId}:${widget.hintIsPrecise}';
        if (resized || (hint != null && hint != _lastHint)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (resized) _transform.value = _homeTransform.clone();
            if (hint != null) {
              final object = widget.puzzle.scene!.objects.firstWhere(
                (o) => o.id == widget.hintId,
              );
              if (widget.hintIsPrecise) {
                _focusObject(object, precise: true);
              } else {
                // Center the broad search cell, not the exact target. Keyboard
                // focus still brings an individual object into view below.
                _centerAt(
                  Offset(
                    ((object.region.centerX * 3).floor() + .5) *
                        _sceneSize.width /
                        3,
                    ((object.region.centerY * 3).floor() + .5) *
                        _sceneSize.height /
                        3,
                  ),
                  _transform.value.getMaxScaleOnAxis(),
                );
              }
            }
          });
        }
        _lastHint = hint;
        return Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              transformationController: _transform,
              constrained: false,
              minScale: 1,
              maxScale: 5,
              trackpadScrollCausesScale: true,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: contentSize.width,
                height: contentSize.height,
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    key: ValueKey('scene-${widget.alternate ? 'b' : 'a'}'),
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTapUp: widget.onTap == null
                        ? null
                        : (details) => widget.onTap!(
                            details.localPosition.dx / constraints.maxWidth,
                            details.localPosition.dy / constraints.maxHeight,
                          ),
                    child: FocusTraversalGroup(
                      child: RepaintBoundary(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (image != null)
                              Image.asset(
                                image,
                                fit: BoxFit.fill,
                                filterQuality: FilterQuality.medium,
                                errorBuilder: (_, _, _) => CustomPaint(
                                  painter: ScenePainter(
                                    widget.puzzle.scene!,
                                    alternate: widget.alternate,
                                  ),
                                ),
                              )
                            else
                              CustomPaint(
                                painter: ScenePainter(
                                  widget.puzzle.scene!,
                                  alternate: widget.alternate,
                                ),
                              ),
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _FindMarkers(
                                  widget.puzzle,
                                  Set.of(widget.found),
                                  widget.hintId,
                                  widget.wrongPoint,
                                  widget.hintIsPrecise,
                                ),
                              ),
                            ),
                            for (final object in widget.puzzle.scene!.objects)
                              if (!widget.alternate || !object.alternateHidden)
                                Positioned.fromRect(
                                  rect: Rect.fromLTWH(
                                    object.region.x * constraints.maxWidth,
                                    object.region.y * constraints.maxHeight,
                                    object.region.width * constraints.maxWidth,
                                    object.region.height *
                                        constraints.maxHeight,
                                  ),
                                  child: _SceneObjectTarget(
                                    key: ValueKey(
                                      'scene-${widget.alternate ? 'b' : 'a'}-object-${object.id}',
                                    ),
                                    label: _objectLabel(object),
                                    found: widget.found.contains(object.id),
                                    onActivate:
                                        widget.onTap == null ||
                                            widget.found.contains(object.id)
                                        ? null
                                        : () => widget.onTap!(
                                            object.region.centerX,
                                            object.region.centerY,
                                          ),
                                    onKeyboardFocus: () => _focusObject(object),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  _viewButton(
                    'scene-zoom-out',
                    'Zoom out',
                    Icons.remove_rounded,
                    () => _zoom(.8),
                  ),
                  const SizedBox(width: 5),
                  _viewButton(
                    'scene-zoom-in',
                    'Zoom in',
                    Icons.add_rounded,
                    () => _zoom(1.25),
                  ),
                  const SizedBox(width: 5),
                  _viewButton(
                    'scene-reset',
                    'Reset view',
                    Icons.zoom_out_map_rounded,
                    () => _transform.value = _homeTransform.clone(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.puzzle.mode == GameMode.hidden
          ? 'Hidden object scene. Drag to explore. Pinch, use the mouse wheel or the zoom buttons to zoom. Every visible object can also be explored with Tab or a screen reader.'
          : 'Picture ${widget.alternate ? 'B' : 'A'}. Compare object descriptions between pictures. Explore with Tab or a screen reader. Pinch or use the mouse wheel to zoom.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: widget.fillAvailable
            ? viewport
            : AspectRatio(aspectRatio: 4 / 3, child: viewport),
      ),
    );
  }

  Widget _viewButton(
    String key,
    String label,
    IconData icon,
    VoidCallback action,
  ) => SizedBox(
    width: 48,
    height: 48,
    child: IconButton.filledTonal(
      key: ValueKey(key),
      tooltip: label,
      style: IconButton.styleFrom(
        backgroundColor: FindItColors.paper.withValues(alpha: .94),
        foregroundColor: FindItColors.ink,
      ),
      onPressed: action,
      icon: Icon(icon, size: 19),
    ),
  );

  void _zoom(double factor) {
    final scale = (_transform.value.getMaxScaleOnAxis() * factor).clamp(
      1.0,
      5.0,
    );
    final center = _transform.toScene(_viewportSize.center(Offset.zero));
    _centerAt(center, scale);
  }

  void _focusObject(SceneObject object, {bool precise = false}) {
    final scale = precise
        ? math.max(2.0, _transform.value.getMaxScaleOnAxis())
        : _transform.value.getMaxScaleOnAxis();
    _centerAt(
      Offset(
        object.region.centerX * _sceneSize.width,
        object.region.centerY * _sceneSize.height,
      ),
      scale,
    );
  }

  void _centerAt(Offset point, double scale) {
    final dx = (_viewportSize.width / 2 - point.dx * scale)
        .clamp(
          math.min(0.0, _viewportSize.width - _sceneSize.width * scale),
          0.0,
        )
        .toDouble();
    final dy = (_viewportSize.height / 2 - point.dy * scale)
        .clamp(
          math.min(0.0, _viewportSize.height - _sceneSize.height * scale),
          0.0,
        )
        .toDouble();
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(dx, dy, 0);
  }

  String _objectLabel(SceneObject object) {
    final alternate = widget.alternate;
    final description = objectDescription(
      alternate ? object.alternateKind ?? object.kind : object.kind,
      color: alternate ? object.alternateColor ?? object.color : object.color,
      variant: alternate
          ? object.alternateVariant ?? object.variant
          : object.variant,
    );
    final horizontal = object.region.centerX < 1 / 3
        ? 'left'
        : object.region.centerX > 2 / 3
        ? 'right'
        : 'center';
    final vertical = object.region.centerY < 1 / 3
        ? 'top'
        : object.region.centerY > 2 / 3
        ? 'bottom'
        : 'middle';
    return 'Picture ${alternate ? 'B' : 'A'}, $description, $vertical $horizontal${widget.found.contains(object.id)
        ? ', found'
        : widget.hintId == object.id && widget.hintIsPrecise
        ? ', hint highlighted'
        : ''}';
  }
}

/// Transparent to scene gestures; only keyboard focus draws an outline. Every
/// visible object is navigable, not just answers, so accessibility does not
/// reveal the solution or change normalized touch coordinates.
class _SceneObjectTarget extends StatefulWidget {
  const _SceneObjectTarget({
    super.key,
    required this.label,
    required this.found,
    required this.onActivate,
    required this.onKeyboardFocus,
  });
  final String label;
  final bool found;
  final VoidCallback? onActivate;
  final VoidCallback onKeyboardFocus;

  @override
  State<_SceneObjectTarget> createState() => _SceneObjectTargetState();
}

class _SceneObjectTargetState extends State<_SceneObjectTarget> {
  final _focus = FocusNode();
  bool _highlight = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    button: true,
    enabled: widget.onActivate != null,
    selected: widget.found,
    onTap: widget.onActivate,
    child: FocusableActionDetector(
      focusNode: _focus,
      enabled: widget.onActivate != null,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onActivate?.call();
            return null;
          },
        ),
      },
      onShowFocusHighlight: (value) {
        if (value) {
          widget.onKeyboardFocus();
          Scrollable.ensureVisible(context);
        }
        setState(() => _highlight = value);
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: _highlight
              ? Border.all(color: FindItColors.forest, width: 2.5)
              : null,
        ),
      ),
    ),
  );
}

class _FindMarkers extends CustomPainter {
  const _FindMarkers(
    this.puzzle,
    this.found,
    this.hint,
    this.wrong,
    this.precise,
  );
  final Puzzle puzzle;
  final Set<String> found;
  final String? hint;
  final Offset? wrong;
  final bool precise;
  @override
  void paint(Canvas canvas, Size size) {
    for (final object in puzzle.scene!.objects) {
      final isFound = found.contains(object.id);
      if (!isFound && hint != object.id) continue;
      final region = object.region;
      if (!isFound && !precise) {
        final column = (region.centerX * 3).floor().clamp(0, 2);
        final row = (region.centerY * 3).floor().clamp(0, 2);
        final area = Rect.fromLTWH(
          column * size.width / 3,
          row * size.height / 3,
          size.width / 3,
          size.height / 3,
        ).deflate(3);
        final rounded = RRect.fromRectAndRadius(
          area,
          const Radius.circular(12),
        );
        canvas.drawRRect(
          rounded,
          Paint()..color = FindItColors.gold.withValues(alpha: .18),
        );
        canvas.drawRRect(
          rounded,
          Paint()
            ..color = FindItColors.gold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        continue;
      }
      final center = Offset(
        region.centerX * size.width,
        region.centerY * size.height,
      );
      final rect = Rect.fromCenter(
        center: center,
        width: region.width * size.width + 4,
        height: region.height * size.height + 4,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..color = isFound ? FindItColors.forest : FindItColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = isFound ? 2.5 : 3,
      );
      if (isFound) {
        final tick = Offset(rect.right - 3, rect.top + 6);
        canvas.drawCircle(tick, 9, Paint()..color = FindItColors.forest);
        final path = Path()
          ..moveTo(tick.dx - 4, tick.dy)
          ..lineTo(tick.dx - 1, tick.dy + 3)
          ..lineTo(tick.dx + 4, tick.dy - 3);
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      } else {
        canvas.drawOval(
          rect.inflate(5),
          Paint()
            ..color = FindItColors.gold.withValues(alpha: .55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
    if (wrong != null) {
      final p = Offset(wrong!.dx * size.width, wrong!.dy * size.height);
      canvas.drawCircle(
        p,
        12,
        Paint()
          ..color = FindItColors.coral.withValues(alpha: .85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      canvas.drawLine(
        p - const Offset(4, 4),
        p + const Offset(4, 4),
        Paint()
          ..color = FindItColors.coral
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        p - const Offset(4, -4),
        p + const Offset(4, -4),
        Paint()
          ..color = FindItColors.coral
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_FindMarkers old) =>
      old.puzzle != puzzle ||
      old.found.length != found.length ||
      !old.found.containsAll(found) ||
      old.hint != hint ||
      old.precise != precise ||
      old.wrong != wrong;
}
