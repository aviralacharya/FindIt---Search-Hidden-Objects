import 'dart:convert';
import 'dart:io';

import 'package:findit/core/config/privacy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _source() =>
    jsonDecode(File(privacyPolicyAsset).readAsStringSync())
        as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the bundled offline policy contains every required disclosure',
    () async {
      final document = await PrivacyPolicyDocument.load();
      expect(document.title, 'Privacy Policy');
      expect(document.sections, hasLength(11));
      expect(
        document.revisionLabel,
        'Last updated: 6 November 2026 · Policy version 1.0',
      );
      final source = _source();
      final sections = source['sections'] as List;
      for (var i = 0; i < sections.length; i++) {
        final section = sections[i] as Map<String, dynamic>;
        expect(document.sections[i].title, section['title']);
        expect(document.sections[i].paragraphs, section['paragraphs']);
        expect(document.sections[i].bullets, section['bullets']);
      }
    },
  );

  test(
    'policy identity, dates, section IDs and required topics fail closed',
    () {
      for (final mutation in [
        'identity',
        'schema',
        'date',
        'duplicate',
        'missing-security',
      ]) {
        final source = _source();
        switch (mutation) {
          case 'identity':
            source['appName'] = 'Original FindIt';
          case 'schema':
            source['schemaVersion'] = 2;
          case 'date':
            source['updated'] = '2026-02-30';
          case 'duplicate':
            (source['sections'] as List).add(
              (source['sections'] as List).first,
            );
          case 'missing-security':
            (source['sections'] as List).removeWhere(
              (section) => (section as Map)['id'] == 'security',
            );
        }
        expect(
          () => PrivacyPolicyDocument.fromJson(source),
          throwsFormatException,
          reason: mutation,
        );
      }
    },
  );

  test('policy keeps the support email plain and rejects links and URLs', () {
    final document = PrivacyPolicyDocument.fromJson(_source());
    expect(
      document.sections.last.paragraphs,
      contains('Email: abiralacharya80@gmail.com.'),
    );
    for (final url in [
      'https://policies.google.com/privacy',
      'mailto:abiralacharya80@gmail.com',
      'javascript:alert(1)',
      'http://example.com',
      'https://user:password@example.com',
      'mailto:someone-else@example.com',
      'mailto:abiralacharya80@gmail.com?subject=unexpected',
    ]) {
      final source = _source();
      (source['sections'] as List).first['links'] = [
        {'label': 'Link', 'url': url},
      ];
      expect(
        () => PrivacyPolicyDocument.fromJson(source),
        throwsFormatException,
      );
    }
    for (final url in [
      'https://example.com',
      'mailto:abiralacharya80@gmail.com',
      'www.example.com',
    ]) {
      final source = _source();
      ((source['sections'] as List).first['paragraphs'] as List).add(
        'See $url',
      );
      expect(
        () => PrivacyPolicyDocument.fromJson(source),
        throwsFormatException,
      );
    }
  });
}
