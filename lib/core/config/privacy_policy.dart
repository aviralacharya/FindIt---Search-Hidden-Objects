import 'dart:convert';

import 'package:flutter/services.dart';

import 'app_config.dart';

const privacyPolicyAsset = 'assets/legal/privacy-policy.json';

final _urlPattern = RegExp(
  r'\b(?:[a-z][a-z0-9+.-]*://|mailto:|www\.)',
  caseSensitive: false,
);
final _packagePattern = RegExp(
  r'\babiral\.mobile(?:\.[a-z0-9_]+)+\b',
  caseSensitive: false,
);

String _text(Map<String, dynamic> value, String key) {
  final text = value[key];
  if (text is! String || text.trim().isEmpty) {
    throw FormatException('Privacy policy is missing $key.');
  }
  if (_urlPattern.hasMatch(text)) {
    throw const FormatException('The privacy policy must not contain URLs.');
  }
  if (_packagePattern.hasMatch(text)) {
    throw const FormatException(
      'The privacy policy must not contain app package identifiers.',
    );
  }
  return text;
}

List<String> _texts(Object? value) {
  if (value is! List ||
      value.any(
        (item) =>
            item is! String ||
            item.trim().isEmpty ||
            _urlPattern.hasMatch(item) ||
            _packagePattern.hasMatch(item),
      )) {
    throw const FormatException('Invalid privacy policy text list.');
  }
  return List<String>.unmodifiable(value.cast<String>());
}

class PrivacyPolicySection {
  const PrivacyPolicySection({
    required this.id,
    required this.title,
    required this.paragraphs,
    required this.bullets,
  });

  final String id;
  final String title;
  final List<String> paragraphs;
  final List<String> bullets;

  factory PrivacyPolicySection.fromJson(Map<String, dynamic> value) {
    final id = _text(value, 'id');
    if (!RegExp(r'^[a-z][a-z_]*$').hasMatch(id)) {
      throw const FormatException('Invalid privacy policy section ID.');
    }
    final paragraphs = _texts(value['paragraphs']);
    final bullets = _texts(value['bullets']);
    final links = value['links'];
    if ((paragraphs.isEmpty && bullets.isEmpty) ||
        links is! List ||
        links.isNotEmpty) {
      throw const FormatException('Incomplete privacy policy section.');
    }
    return PrivacyPolicySection(
      id: id,
      title: _text(value, 'title'),
      paragraphs: paragraphs,
      bullets: bullets,
    );
  }
}

class PrivacyPolicyDocument {
  const PrivacyPolicyDocument({
    required this.title,
    required this.version,
    required this.updated,
    required this.appName,
    required this.eyebrow,
    required this.intro,
    required this.summaryBadges,
    required this.sections,
    required this.footer,
  });

  final String title;
  final String version;
  final String updated;
  final String appName;
  final String eyebrow;
  final String intro;
  final List<String> summaryBadges;
  final List<PrivacyPolicySection> sections;
  final String footer;

  String get revisionLabel {
    final date = DateTime.parse(updated);
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return 'Last updated: ${date.day} ${months[date.month - 1]} ${date.year} · Policy version $version';
  }

  static Future<PrivacyPolicyDocument> load({AssetBundle? bundle}) async {
    final json = jsonDecode(
      await (bundle ?? rootBundle).loadString(privacyPolicyAsset, cache: false),
    );
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid privacy policy document.');
    }
    return PrivacyPolicyDocument.fromJson(json);
  }

  factory PrivacyPolicyDocument.fromJson(Map<String, dynamic> value) {
    if (value['schemaVersion'] != 1 ||
        value['appName'] != AppConfig.name ||
        value.containsKey('androidPackage') ||
        value['developerName'] != AppConfig.developerName ||
        value['developerEmail'] != AppConfig.developerEmail ||
        value['policyTitle'] != 'Privacy Policy') {
      throw const FormatException(
        'Privacy policy identity does not match this app.',
      );
    }
    final updated = _text(value, 'updated');
    final date = DateTime.tryParse(updated);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(updated) ||
        date == null ||
        date.toIso8601String().substring(0, 10) != updated) {
      throw const FormatException('Invalid privacy policy revision date.');
    }
    final values = value['sections'];
    if (values is! List ||
        values.isEmpty ||
        values.any((section) => section is! Map<String, dynamic>)) {
      throw const FormatException('Missing privacy policy sections.');
    }
    final sections = values
        .map(
          (section) =>
              PrivacyPolicySection.fromJson(section as Map<String, dynamic>),
        )
        .toList(growable: false);
    if (sections.map((section) => section.id).toSet().length !=
        sections.length) {
      throw const FormatException('Duplicate privacy policy sections.');
    }
    const requiredSections = {
      'scope',
      'local_data',
      'collection_sharing',
      'network_services',
      'permissions_backups',
      'security',
      'retention',
      'choices_deletion',
      'children',
      'changes',
      'contact',
    };
    if (!sections
        .map((section) => section.id)
        .toSet()
        .containsAll(requiredSections)) {
      throw const FormatException(
        'Privacy policy is missing required disclosures.',
      );
    }
    return PrivacyPolicyDocument(
      title: _text(value, 'policyTitle'),
      version: _text(value, 'policyVersion'),
      updated: updated,
      appName: _text(value, 'appName'),
      eyebrow: _text(value, 'eyebrow'),
      intro: _text(value, 'intro'),
      summaryBadges: _texts(value['summaryBadges']),
      sections: List.unmodifiable(sections),
      footer: _text(value, 'footer'),
    );
  }
}
