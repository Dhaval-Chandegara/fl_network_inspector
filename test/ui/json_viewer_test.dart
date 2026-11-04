import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_network_inspector/src/models/body_type.dart';
import 'package:fl_network_inspector/src/ui/components/json_viewer.dart';
import 'package:fl_network_inspector/src/ui/utils/json_format_isolate.dart';

void main() {
  group('JsonViewerWidget & Isolate Formatter Tests', () {
    test('formatJsonIsolate indents raw JSON string', () {
      const raw = '{"name":"Alice","age":30,"active":true}';
      final formatted = formatJsonIsolate(raw);

      expect(formatted, contains('  "name": "Alice"'));
      expect(formatted, contains('  "age": 30'));
      expect(formatted, contains('  "active": true'));
    });

    testWidgets(
        'renders empty state "No payload body recorded" when null or empty',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JsonViewerWidget(rawPayload: null),
          ),
        ),
      );

      expect(find.text('No payload body recorded'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JsonViewerWidget(rawPayload: ''),
          ),
        ),
      );

      expect(find.text('No payload body recorded'), findsOneWidget);
    });

    testWidgets(
        'renders warning banner "[Body truncated at 1MB]" when isTruncated is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JsonViewerWidget(
              rawPayload: '{"truncated": true}',
              isTruncated: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('[Body truncated at 1MB]'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('toggles between Raw and Pretty modes', (tester) async {
      const raw = '{"title":"Flutter","count":42}';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JsonViewerWidget(
              rawPayload: raw,
              bodyType: BodyType.json,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Starts in Pretty mode with toggle button showing "Raw"
      expect(find.text('Raw'), findsOneWidget);

      // Tap Raw to switch to raw view
      await tester.tap(find.text('Raw'));
      await tester.pumpAndSettle();

      // Toggle button now shows "Pretty"
      expect(find.text('Pretty'), findsOneWidget);
      // Raw string displayed
      expect(find.text(raw), findsOneWidget);

      // Tap Pretty to switch back
      await tester.tap(find.text('Pretty'));
      await tester.pumpAndSettle();

      expect(find.text('Raw'), findsOneWidget);
    });

    testWidgets('handles large payloads over 50KB cleanly', (tester) async {
      // Create ~60KB JSON string
      final largeJson = '{"data": "${"A" * 60000}"}';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonViewerWidget(
              rawPayload: largeJson,
              bodyType: BodyType.json,
            ),
          ),
        ),
      );

      // Pump through async isolate formatting
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(JsonViewerWidget), findsOneWidget);
    });

    testWidgets(
        'properly classifies string values containing ": and does not falsely treat them as keys',
        (tester) async {
      const payload =
          '{"query": "WHERE col = \\":id\\"", "greeting": "hello:"}';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JsonViewerWidget(
              rawPayload: payload,
              bodyType: BodyType.json,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final selectableTextFinder = find.byType(SelectableText);
      expect(selectableTextFinder, findsOneWidget);

      final selectableText =
          tester.widget<SelectableText>(selectableTextFinder);
      final rootSpan = selectableText.textSpan!;

      final spans = rootSpan.children!.whereType<TextSpan>().toList();

      // Find the span containing the WHERE query string value
      final valueSpan = spans.firstWhere(
        (s) => s.text != null && s.text!.contains('WHERE col ='),
      );
      // Ensure its color is stringColor (0xFF16A34A for light mode default)
      expect(valueSpan.style?.color, const Color(0xFF16A34A));
      expect(valueSpan.style?.fontWeight, isNot(FontWeight.w600));

      // Find the span containing "hello:" string value
      final greetingValueSpan = spans.firstWhere(
        (s) => s.text != null && s.text!.contains('hello:'),
      );
      expect(greetingValueSpan.style?.color, const Color(0xFF16A34A));
      expect(greetingValueSpan.style?.fontWeight, isNot(FontWeight.w600));
    });
  });
}
