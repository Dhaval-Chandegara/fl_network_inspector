import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_network_inspector/flutter_network_inspector.dart';
import 'package:flutter_network_inspector/src/ui/components/export_action_sheet.dart';
import 'package:flutter_network_inspector/src/ui/utils/share_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sampleRecord = NetworkRecord(
    id: 'test-share-123',
    url: 'https://api.example.com/v1/users/42',
    baseUrl: 'https://api.example.com',
    path: '/v1/users/42',
    method: 'GET',
    requestHeaders: const {
      'Authorization': 'Bearer [REDACTED]',
      'Accept': 'application/json',
    },
    requestTimestamp: DateTime(2026, 11, 2, 12, 30),
    responseStatusCode: 200,
    responseHeaders: const {
      'Content-Type': 'application/json; charset=utf-8',
      'Set-Cookie': '[REDACTED]',
    },
    responseBody: const PayloadData(
      body: '{"id":42,"name":"Alice","token":"[REDACTED]"}',
      bodyType: BodyType.json,
      byteSize: 46,
    ),
    durationMs: 120,
    status: NetworkStatus.success,
  );

  tearDown(() {
    ShareExporter.mockShareDelegate = null;
  });

  group('ShareExporter Formatting', () {
    test('formatMarkdown formats complete report including headers and body', () {
      final md = ShareExporter.formatMarkdown(sampleRecord);

      expect(md, contains('# Network Request Inspection'));
      expect(md, contains('- **Method**: GET'));
      expect(md, contains('- **URL**: https://api.example.com/v1/users/42'));
      expect(md, contains('- **Status**: 200'));
      expect(md, contains('- **Duration**: 120 ms'));
      expect(md, contains('## Request Headers'));
      expect(md, contains('`Authorization`: Bearer [REDACTED]'));
      expect(md, contains('## Response Headers'));
      expect(md, contains('`Content-Type`: application/json; charset=utf-8'));
      expect(md, contains('## Response Body'));
      expect(md, contains('{"id":42,"name":"Alice","token":"[REDACTED]"}'));
    });

    test('formatMarkdown omits headers when excludeHeaders is true', () {
      final md = ShareExporter.formatMarkdown(sampleRecord, excludeHeaders: true);

      expect(md, isNot(contains('## Request Headers')));
      expect(md, isNot(contains('`Authorization`: Bearer [REDACTED]')));
      expect(md, isNot(contains('## Response Headers')));
      expect(md, isNot(contains('Set-Cookie')));
      expect(md, contains('## Response Body'));
    });

    test('formatCurl delegates to CurlGenerator respecting excludeHeaders', () {
      final curlWithHeaders = ShareExporter.formatCurl(sampleRecord, excludeHeaders: false);
      expect(curlWithHeaders, contains("-H 'Authorization: Bearer [REDACTED]'"));

      final curlWithoutHeaders = ShareExporter.formatCurl(sampleRecord, excludeHeaders: true);
      expect(curlWithoutHeaders, isNot(contains("-H 'Authorization")));
      expect(curlWithoutHeaders, contains("curl -X GET \\\n  'https://api.example.com/v1/users/42'"));
    });

    test('formatJson formats valid JSON with redactions preserved', () {
      final jsonStr = ShareExporter.formatJson(sampleRecord, excludeHeaders: false);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(decoded['id'], 'test-share-123');
      expect(decoded['url'], 'https://api.example.com/v1/users/42');
      expect(decoded['response_status_code'], 200);

      // Verify nested headers are present and retain [REDACTED]
      final reqHeaders = decoded['request_headers'] as Map<String, dynamic>;
      expect(reqHeaders['Authorization'], 'Bearer [REDACTED]');

      // Verify response body retains [REDACTED]
      final resBody = decoded['response_body'] as Map<String, dynamic>;
      expect(resBody['body'], contains('[REDACTED]'));
    });

    test('formatJson strips request and response headers when excludeHeaders is true', () {
      final jsonStr = ShareExporter.formatJson(sampleRecord, excludeHeaders: true);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(decoded.containsKey('request_headers'), isFalse);
      expect(decoded.containsKey('response_headers'), isFalse);
      expect(decoded.containsKey('requestHeaders'), isFalse);
      expect(decoded.containsKey('responseHeaders'), isFalse);
      expect(decoded['url'], 'https://api.example.com/v1/users/42');
    });
  });

  group('ShareExporter calculateAnchor', () {
    testWidgets('calculates valid anchor rect from attached widget context', (tester) async {
      late Rect anchor;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      anchor = ShareExporter.calculateAnchor(context);
                    },
                    child: const Text('Test Anchor'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test Anchor'));
      await tester.pump();

      expect(anchor, isNotNull);
      expect(anchor.width, greaterThan(0));
      expect(anchor.height, greaterThan(0));
    });
  });

  group('ExportActionSheet Widget', () {
    testWidgets('renders all share options and exclude headers checkbox', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportActionSheet(record: sampleRecord),
          ),
        ),
      );

      expect(find.text('Share Request Details'), findsOneWidget);
      expect(find.text('Exclude all headers'), findsOneWidget);
      expect(find.text('Share as Markdown Summary'), findsOneWidget);
      expect(find.text('Share as cURL Command'), findsOneWidget);
      expect(find.text('Share as Full JSON'), findsOneWidget);
    });

    testWidgets('dispatches shareRecord with selected format and excludeHeaders state', (tester) async {
      String? sharedText;
      String? sharedSubject;
      Rect? sharedOrigin;

      ShareExporter.mockShareDelegate = (text, {subject, sharePositionOrigin}) async {
        sharedText = text;
        sharedSubject = subject;
        sharedOrigin = sharePositionOrigin;
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ExportActionSheet.show(context, record: sampleRecord);
                  },
                  child: const Text('Open Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Toggle Exclude all headers
      await tester.tap(find.text('Exclude all headers'));
      await tester.pumpAndSettle();

      // Tap Share as cURL Command
      await tester.tap(find.text('Share as cURL Command'));
      await tester.pumpAndSettle();

      expect(sharedText, isNotNull);
      expect(sharedSubject, 'GET /v1/users/42 (200)');
      expect(sharedOrigin, isNotNull);
      // Because excludeHeaders was toggled, cURL should have no -H
      expect(sharedText, isNot(contains("-H 'Authorization")));
    });
  });
}
