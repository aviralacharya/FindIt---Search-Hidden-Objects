import 'package:findit/core/content/puzzle_generator.dart';
import 'package:findit/core/domain/puzzle.dart';

Map<String, dynamic> _integer(int minimum, int maximum) => {
  'type': 'integer',
  'minimum': minimum,
  'maximum': maximum,
};
Map<String, dynamic> _string(int minimum, int maximum) => {
  'type': 'string',
  'minLength': minimum,
  'maxLength': maximum,
};
Map<String, dynamic> _ref(String name) => {r'$ref': '#/\$defs/$name'};
Map<String, dynamic> _array(Map<String, dynamic> items, int min, int max) => {
  'type': 'array',
  'items': items,
  'minItems': min,
  'maxItems': max,
};
Map<String, dynamic> _object(
  Map<String, dynamic> properties,
  List<String> required,
) => {
  'type': 'object',
  'additionalProperties': false,
  'required': required,
  'properties': properties,
};

/// Authoring schema for canonical downloadable packs, not the bundled raster
/// catalog. Cross-field gameplay rules still require the shared Dart validator.
Map<String, dynamic> packSchema() => {
  r'$schema': 'https://json-schema.org/draft/2020-12/schema',
  'title': 'FindIt Hidden Objects declarative scene pack v1',
  'description': 'Hidden-object scenes only. No code, remote images, ZIPs or daily IDs. Also run tool/pack_tool.dart validate.',
  ..._object(
    {
      'schemaVersion': {'const': 1},
      'contentVersion': {'type': 'integer', 'minimum': 1},
      'packId': {'type': 'string', 'pattern': r'^[a-z0-9][a-z0-9_-]{2,79}$'},
      'title': _string(1, 120),
      'license': _string(1, 2000),
      'puzzles': _array(_ref('puzzle'), 1, 1000),
    },
    ['schemaVersion', 'contentVersion', 'packId', 'license', 'puzzles'],
  ),
  r'$defs': {
    'region': _object(
      {
        'x': {'type': 'number', 'minimum': 0, 'maximum': 1},
        'y': {'type': 'number', 'minimum': 0, 'maximum': 1},
        'w': {'type': 'number', 'minimum': .055, 'maximum': 1},
        'h': {'type': 'number', 'minimum': .055, 'maximum': 1},
      },
      ['x', 'y', 'w', 'h'],
    ),
    'sceneObject': _object(
      {
        'id': _string(1, 100),
        'kind': {'enum': objectKinds},
        'region': _ref('region'),
        'color': _integer(0, 5),
        'variant': _integer(0, 2),
        'rotation': {'type': 'number', 'minimum': -.5, 'maximum': .5},
        'alternateKind': {'enum': objectKinds},
        'alternateColor': _integer(0, 5),
        'alternateVariant': _integer(0, 2),
        'alternateHidden': {'type': 'boolean'},
      },
      ['id', 'kind', 'region', 'color', 'variant', 'rotation'],
    ),
    'scene': _object(
      {
        'template': {'enum': sceneTemplates},
        'palette': _integer(0, 5),
        'layout': _integer(0, 1000),
        'seed': _integer(0, 0xffffffff),
        'objects': _array(_ref('sceneObject'), 5, 60),
      },
      ['template', 'palette', 'layout', 'seed', 'objects'],
    ),
    'puzzle': {
      ..._object(
        {
          'id': {
            'type': 'string',
            'pattern': r'^(?!daily-)[a-z0-9][a-z0-9_-]{2,99}$',
          },
          'mode': {'const': 'hidden'},
          'title': _string(1, 120),
          'category': _string(1, 60),
          'difficulty': _integer(1, 5),
          'level': _integer(1, 10000),
          'seed': _integer(0, 0xffffffff),
          'reward': _integer(0, 1000),
          'parSeconds': _integer(1, 3600),
          'timeLimitSeconds': _integer(0, 3600),
          'answerIds': {..._array(_string(1, 100), 5, 10), 'uniqueItems': true},
          'rounds': {'type': 'array', 'maxItems': 0},
          'validation': {
            'enum': ['automated', 'reviewed'],
          },
          'generatorVersion': {'const': 1},
          'scene': _ref('scene'),
        },
        [
          'id',
          'mode',
          'title',
          'category',
          'difficulty',
          'level',
          'seed',
          'reward',
          'parSeconds',
          'timeLimitSeconds',
          'answerIds',
          'rounds',
          'validation',
          'generatorVersion',
          'scene',
        ],
      ),
    },
  },
};
