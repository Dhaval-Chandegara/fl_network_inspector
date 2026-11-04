import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_network_inspector_example/main.dart';
import 'package:fl_network_inspector/fl_network_inspector.dart';

void main() {
  setUp(() async {
    await NetworkInspector.initialize(
      config: const NetworkInspectorConfig(
        enabled: true,
        enableDatabase: false,
        enableShakeDetection: false,
      ),
    );
  });

  tearDown(() {
    NetworkInspector.resetForTesting();
  });

  testWidgets('ExampleApp renders HomeScreen with all action buttons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('Flutter Network Inspector Demo'), findsOneWidget);
    expect(find.text('Shake to Open Inspector'), findsOneWidget);
    expect(find.text('Open Network Inspector Screen'), findsOneWidget);
    expect(find.text('Send HTTP GET (package:http)'), findsOneWidget);
    expect(find.text('Send JSON POST (Dio with redaction)'), findsOneWidget);
    expect(find.text('Send Multipart Upload (Metadata only)'), findsOneWidget);
    expect(find.text('Send HTTP 404 Not Found Request'), findsOneWidget);
    expect(
        find.text('Simulate Network Failure (Socket Error)'), findsOneWidget);
    expect(find.text('Log Custom Manual Call (GraphQL)'), findsOneWidget);
  });
}
