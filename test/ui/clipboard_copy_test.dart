import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_network_inspector/src/ui/components/copy_button.dart';
import 'package:fl_network_inspector/src/ui/network_inspector_detail_screen.dart';

import 'helpers/test_record_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Clipboard Copy Tests', () {
    testWidgets('CopyButton copies text to clipboard and shows SnackBar',
        (tester) async {
      String? copiedData;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          copiedData = (methodCall.arguments as Map<dynamic, dynamic>)['text']
              as String?;
          return null;
        }
        return null;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CopyButton(
              textProvider: () => 'curl -X GET "https://api.example.com"',
              sectionName: 'cURL Command',
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CopyButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(copiedData, 'curl -X GET "https://api.example.com"');
      expect(find.text('Copied cURL Command to clipboard'), findsOneWidget);
    });

    testWidgets('NetworkInspectorDetailScreen URL copy button copies full URL',
        (tester) async {
      String? copiedData;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          copiedData = (methodCall.arguments as Map<dynamic, dynamic>)['text']
              as String?;
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

      // Find URL copy button in Header Summary Card
      final copyUrlButton = find.byTooltip('Copy URL');
      expect(copyUrlButton, findsOneWidget);

      await tester.tap(copyUrlButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(copiedData, 'https://api.example.com/v1/users');
      expect(find.text('Copied URL to clipboard'), findsOneWidget);
    });
  });
}
