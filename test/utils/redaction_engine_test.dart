import 'dart:convert';

import 'package:flutter_network_inspector/src/core/constants.dart';
import 'package:flutter_network_inspector/src/utils/redaction_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RedactionEngine Key Normalization (D-11)', () {
    test('normalizes casing, hyphens, underscores, and dots uniformly', () {
      expect(RedactionEngine.normalizeKey('api_key'), equals('apikey'));
      expect(RedactionEngine.normalizeKey('API-KEY'), equals('apikey'));
      expect(RedactionEngine.normalizeKey('apiKey'), equals('apikey'));
      expect(RedactionEngine.normalizeKey('auth.token'), equals('authtoken'));
      expect(RedactionEngine.normalizeKey('access_token'), equals('accesstoken'));
      expect(RedactionEngine.normalizeKey('accessToken'), equals('accesstoken'));
    });

    test('recognizes standard sensitive keys across all formatting styles', () {
      final engine = RedactionEngine();

      expect(engine.isSensitive('Authorization'), isTrue);
      expect(engine.isSensitive('authorization'), isTrue);
      expect(engine.isSensitive('cookie'), isTrue);
      expect(engine.isSensitive('Set-Cookie'), isTrue);
      expect(engine.isSensitive('token'), isTrue);
      expect(engine.isSensitive('access_token'), isTrue);
      expect(engine.isSensitive('accessToken'), isTrue);
      expect(engine.isSensitive('refresh_token'), isTrue);
      expect(engine.isSensitive('password'), isTrue);
      expect(engine.isSensitive('secret'), isTrue);
      expect(engine.isSensitive('api_key'), isTrue);
      expect(engine.isSensitive('apiKey'), isTrue);
      expect(engine.isSensitive('API-KEY'), isTrue);
      expect(engine.isSensitive('private_key'), isTrue);

      // Non-sensitive keys
      expect(engine.isSensitive('username'), isFalse);
      expect(engine.isSensitive('email'), isFalse);
      expect(engine.isSensitive('page'), isFalse);
    });

    test('supports custom redaction keys via constructor', () {
      final engine = RedactionEngine(customKeys: const ['client_secret', 'pin_code']);

      expect(engine.isSensitive('client_secret'), isTrue);
      expect(engine.isSensitive('clientSecret'), isTrue);
      expect(engine.isSensitive('pin-code'), isTrue);
      expect(engine.isSensitive('pinCode'), isTrue);
    });
  });

  group('RedactionEngine Header & Query Redaction (D-09, D-12)', () {
    final engine = RedactionEngine();

    test('redacts sensitive headers while preserving non-sensitive headers', () {
      final headers = {
        'Authorization': 'Bearer eyJhbGciOi...',
        'Cookie': 'session=abc123xyz',
        'Content-Type': 'application/json',
        'Accept': '*/*',
      };

      final sanitized = engine.redactHeaders(headers);

      expect(sanitized['Authorization'], equals(NetworkInspectorConstants.redactedPlaceholder));
      expect(sanitized['Cookie'], equals(NetworkInspectorConstants.redactedPlaceholder));
      expect(sanitized['Content-Type'], equals('application/json'));
      expect(sanitized['Accept'], equals('*/*'));
    });

    test('redacts query parameter maps', () {
      final params = {
        'api_key': 'super_secret_key',
        'format': 'json',
        'token': 'session_token_123',
      };

      final sanitized = engine.redactQueryParams(params);

      expect(sanitized['api_key'], equals(NetworkInspectorConstants.redactedPlaceholder));
      expect(sanitized['token'], equals(NetworkInspectorConstants.redactedPlaceholder));
      expect(sanitized['format'], equals('json'));
    });

    test('redacts sensitive query parameters in full URLs', () {
      const url = 'https://api.example.com/v1/search?q=flutter&api_key=secret99&page=2#section1';
      final sanitized = engine.redactUrl(url);

      expect(sanitized, contains('q=flutter'));
      expect(sanitized, contains('page=2'));
      expect(sanitized, contains('api_key=%5BREDACTED%5D'));
      expect(sanitized, isNot(contains('secret99')));
      expect(sanitized, contains('section1'));
      expect(sanitized.startsWith('https://api.example.com/v1/search'), isTrue);
    });

    test('returns original URL when no query or no sensitive parameters exist', () {
      const url = 'https://api.example.com/users/profile?id=42';
      expect(engine.redactUrl(url), equals(url));
    });
  });

  group('RedactionEngine Body Redaction (D-10)', () {
    final engine = RedactionEngine();

    test('deeply redacts nested JSON maps and lists at arbitrary depth', () {
      final jsonBody = jsonEncode({
        'status': 'ok',
        'data': {
          'user': {
            'id': 101,
            'name': 'Alice',
            'password': 'mypassword123',
            'tokens': [
              {'access_token': 'token_alpha', 'type': 'bearer'},
              {'access_token': 'token_beta', 'type': 'refresh'},
            ],
          },
          'metadata': {
            'apiKey': 'key_abc',
          },
        },
      });

      final redacted = engine.redactBody(jsonBody, 'application/json');
      expect(redacted, isNotNull);

      final decoded = jsonDecode(redacted!) as Map<String, dynamic>;
      final user = (decoded['data'] as Map<String, dynamic>)['user'] as Map<String, dynamic>;

      expect(user['name'], equals('Alice'));
      expect(user['password'], equals(NetworkInspectorConstants.redactedPlaceholder));

      final tokens = user['tokens'] as List<dynamic>;
      for (final t in tokens) {
        final tokenMap = t as Map<String, dynamic>;
        expect(tokenMap['access_token'], equals(NetworkInspectorConstants.redactedPlaceholder));
        expect(tokenMap['type'], isNotNull);
      }

      final metadata = (decoded['data'] as Map<String, dynamic>)['metadata'] as Map<String, dynamic>;
      expect(metadata['apiKey'], equals(NetworkInspectorConstants.redactedPlaceholder));
    });

    test('redacts form URL-encoded body strings', () {
      const formBody = 'username=john&password=secret123&grant_type=password&api_key=abc';
      final redacted = engine.redactBody(formBody, 'application/x-www-form-urlencoded');

      expect(redacted, isNotNull);
      expect(redacted, contains('username=john'));
      expect(redacted, contains('grant_type=password'));
      expect(redacted, contains('password=%5BREDACTED%5D'));
      expect(redacted, contains('api_key=%5BREDACTED%5D'));
      expect(redacted, isNot(contains('secret123')));
      expect(redacted, isNot(contains('abc')));
    });

    test('returns null or empty bodies without alteration', () {
      expect(engine.redactBody(null, 'application/json'), isNull);
      expect(engine.redactBody('', 'application/json'), equals(''));
    });
  });
}
