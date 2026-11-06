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
      expect(document.appName, 'FindIt');
      expect(document.sections, hasLength(11));
      expect(
        document.revisionLabel,
        'Last updated: 6 November 2026 · Policy version 1.0.0',
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

  test('policy explains every release permission and its purpose', () {
    final document = PrivacyPolicyDocument.fromJson(_source());
    final section = document.sections.firstWhere(
      (section) => section.id == 'permissions_backups',
    );
    final text = [...section.paragraphs, ...section.bullets].join('\n');
    for (final permission in [
      'android.permission.INTERNET',
      'android.permission.VIBRATE',
      'DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
    ]) {
      expect(text, contains(permission));
    }
    expect(text, contains('normal permissions'));
    expect(text, contains('signature-protected'));
    expect(text, contains('does not record audio'));
    expect(text, contains('disabled in the Android configuration'));
  });

  test(
    'policy excludes app package identifiers in metadata and legal text',
    () {
      final source = _source();
      expect(source.containsKey('androidPackage'), isFalse);
      expect(source.containsKey('launcherName'), isFalse);
      expect(jsonEncode(source), isNot(contains('abiral.mobile.')));
      for (final package in [
        'abiral.mobile.findit',
        'abiral.mobile.findithiddenobjects',
      ]) {
        for (final target in [
          'metadata',
          'intro',
          'footer',
          'heading',
          'paragraph',
          'bullet',
          'badge',
        ]) {
          final value = _source();
          if (target == 'metadata') {
            value['androidPackage'] = package;
          } else if (target == 'intro' || target == 'footer') {
            value[target] = '${value[target]} $package';
          } else if (target == 'heading') {
            final section = (value['sections'] as List).first as Map;
            section['title'] = '${section['title']} $package';
          } else if (target == 'badge') {
            (value['summaryBadges'] as List).add(package);
          } else {
            final section = (value['sections'] as List).first as Map;
            (section['${target}s'] as List).add(package);
          }
          expect(
            () => PrivacyPolicyDocument.fromJson(value),
            throwsFormatException,
            reason: '$target: $package',
          );
        }
      }
    },
  );

  test('policy explains local gameplay, clipboard actions, and services', () {
    final document = PrivacyPolicyDocument.fromJson(_source());
    String textFor(String id) {
      final section = document.sections.firstWhere(
        (section) => section.id == id,
      );
      return [...section.paragraphs, ...section.bullets].join('\n');
    }

    expect(textFor('local_data'), contains('completion dates'));
    expect(textFor('local_data'), contains('Local puzzle/session identifiers'));
    expect(textFor('local_data'), contains('unused compatibility fields'));
    expect(textFor('collection_sharing'), contains('Copy developer email'));
    expect(textFor('collection_sharing'), contains('Android clipboard'));
    expect(
      textFor('collection_sharing'),
      contains('does not automatically read'),
    );
    expect(textFor('network_services'), contains('using its local date'));
    expect(
      textFor('network_services'),
      contains('download form is unavailable'),
    );
    expect(textFor('network_services'), contains('IP address'));
    expect(textFor('network_services'), contains('Email service providers'));
    expect(textFor('choices_deletion'), contains('logical deletion'));
    expect(textFor('choices_deletion'), contains('does not delete emails'));
  });

  test('policy excludes hosting and publishing implementation copy', () {
    final text = jsonEncode(_source()).toLowerCase();
    for (final phrase in [
      'github',
      'public privacy policy',
      'public policy',
      'hosting infrastructure',
      'policy is hosted',
      'policy source',
      'policy html',
    ]) {
      expect(text, isNot(contains(phrase)), reason: phrase);
    }
  });

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
