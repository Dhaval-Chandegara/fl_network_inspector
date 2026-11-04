import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_network_inspector/src/models/http_error_details.dart';
import 'package:fl_network_inspector/src/models/multipart_entry.dart';
import 'package:fl_network_inspector/src/models/network_status.dart';
import 'package:fl_network_inspector/src/ui/components/export_action_sheet.dart';
import 'package:fl_network_inspector/src/ui/network_inspector_detail_screen.dart';

import 'helpers/test_record_fixtures.dart';

void main() {
  group('NetworkInspectorDetailScreen 4-Tab Tests', () {
    testWidgets('renders Header Summary Card and Overview tab details', (tester) async {
      final record = TestRecordFixtures.getSuccessRecord;

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorDetailScreen(record: record),
        ),
      );

      await tester.pumpAndSettle();

      // Header summary card
      expect(find.text('Request Details'), findsOneWidget);
      expect(find.text('GET'), findsNWidgets(2)); // Badge and table
      expect(find.text('200'), findsNWidgets(2)); // Badge and table
      expect(find.text('45 ms'), findsNWidgets(2)); // Card and table
      expect(find.text('https://api.example.com/v1/users'), findsNWidgets(2));

      // 4 Tabs
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Request'), findsOneWidget);
      expect(find.text('Response'), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);

      // Overview table items
      expect(find.text('Method'), findsOneWidget);
      expect(find.text('Status Code'), findsOneWidget);
      expect(find.text('Base URL'), findsOneWidget);
      expect(find.text('https://api.example.com'), findsOneWidget);
      expect(find.text('/v1/users'), findsOneWidget);
    });

    testWidgets('Request tab displays headers and query parameters', (tester) async {
      final record = TestRecordFixtures.createRecord(
        url: 'https://api.example.com/search?q=flutter&page=1',
        method: 'GET',
      ).copyWith(
        requestQueryParams: {'q': 'flutter', 'page': '1'},
        multipartEntries: [
          const MultipartEntry(
            fieldName: 'avatar',
            fileName: 'profile.png',
            contentType: 'image/png',
            byteSize: 4096,
            filePath: '/tmp/profile.png',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorDetailScreen(record: record),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Request tab
      await tester.tap(find.text('Request'));
      await tester.pumpAndSettle();

      expect(find.text('Request Headers'), findsOneWidget);
      expect(find.text('Content-Type'), findsOneWidget);
      expect(find.text('Query Parameters'), findsOneWidget);
      expect(find.text('q'), findsOneWidget);
      expect(find.text('flutter'), findsOneWidget);

      // Multipart uploads
      expect(find.text('Multipart Uploads'), findsOneWidget);
      expect(find.text('Field: avatar'), findsOneWidget);
      expect(find.text('File: profile.png'), findsOneWidget);
    });

    testWidgets('Response tab displays response headers and body', (tester) async {
      final record = TestRecordFixtures.getSuccessRecord;

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorDetailScreen(record: record),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Response tab
      await tester.tap(find.text('Response'));
      await tester.pumpAndSettle();

      expect(find.text('Response Headers'), findsOneWidget);
      expect(find.text('Response Body'), findsOneWidget);
    });

    testWidgets('Error tab shows checkmark when request has no errors', (tester) async {
      final record = TestRecordFixtures.getSuccessRecord;

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorDetailScreen(record: record),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Error'));
      await tester.pumpAndSettle();

      expect(find.text('No errors encountered for this request'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('Error tab shows message, exception, and stack trace when failed',
        (tester) async {
      final record = TestRecordFixtures.createRecord(
        url: 'https://api.example.com/fail',
        method: 'POST',
        statusCode: 500,
        status: NetworkStatus.failed,
        error: const HttpErrorDetails(
          message: 'Database connection failed',
          errorType: 'TimeoutException',
          stackTrace: 'Error at line 42 in main.dart',
          statusCode: 500,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorDetailScreen(record: record),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Error'));
      await tester.pumpAndSettle();

      expect(find.text('Database connection failed'), findsOneWidget);
      expect(find.text('TimeoutException'), findsOneWidget);
      expect(find.text('Error at line 42 in main.dart'), findsOneWidget);
    });

    testWidgets('AppBar Copy cURL action copies bash cURL and shows SnackBar', (tester) async {
      String? clipboardData;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          clipboardData = (methodCall.arguments as Map)['text'] as String?;
          return null;
        }
        return null;
      });

      final record = TestRecordFixtures.getSuccessRecord;

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorDetailScreen(record: record),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Copy as cURL'));
      await tester.pumpAndSettle();

      expect(clipboardData, isNotNull);
      expect(clipboardData, contains("curl -X GET \\\n  'https://api.example.com/v1/users'"));
      expect(find.text('Copied cURL to clipboard'), findsOneWidget);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('AppBar Share action opens ExportActionSheet bottom sheet', (tester) async {
      final record = TestRecordFixtures.getSuccessRecord;

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorDetailScreen(record: record),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Share request details'));
      await tester.pumpAndSettle();

      expect(find.byType(ExportActionSheet), findsOneWidget);
      expect(find.text('Share Request Details'), findsOneWidget);
    });
  });
}
