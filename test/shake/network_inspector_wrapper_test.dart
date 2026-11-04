import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_network_inspector/fl_network_inspector.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<UserAccelerometerEvent> sensorController;

  setUp(() async {
    sensorController = StreamController<UserAccelerometerEvent>.broadcast();
    ShakeDetector.mockStream = sensorController.stream;
    await NetworkInspector.initialize(
      config: const NetworkInspectorConfig(
        enabled: true,
        enableDatabase: false,
        shakeThreshold: 10.0,
        shakeDebounceMs: 100,
      ),
    );
  });

  tearDown(() async {
    ShakeDetector.mockStream = null;
    await sensorController.close();
    NetworkInspector.resetForTesting();
  });

  group('NetworkInspectorWrapper Tests', () {
    testWidgets('renders child widget directly with no extra layout wrappers', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NetworkInspectorWrapper(
            child: Scaffold(
              body: Center(child: Text('Test Child')),
            ),
          ),
        ),
      );

      expect(find.text('Test Child'), findsOneWidget);
    });

    testWidgets('triggers NetworkInspector.open on shake above threshold', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NetworkInspectorWrapper(
            child: Scaffold(
              body: Center(child: Text('App Content')),
            ),
          ),
        ),
      );

      // Verify inspector is not open initially
      expect(NetworkInspector.isOpen, isFalse);

      // Simulate a violent shake event (magnitude > 10.0: sqrt(100+100) ~ 14.14)
      sensorController
          .add(UserAccelerometerEvent(10.0, 10.0, 0.0, DateTime.now()));
      await tester.pumpAndSettle();

      // Verify inspector opened and route is shown
      expect(NetworkInspector.isOpen, isTrue);
      expect(find.byType(NetworkInspectorScreen), findsOneWidget);
    });

    testWidgets('ignores shake events below threshold', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NetworkInspectorWrapper(
            child: Scaffold(
              body: Center(child: Text('App Content')),
            ),
          ),
        ),
      );

      // Simulate gentle movement (magnitude: sqrt(1+1) ~ 1.41 < 10.0)
      sensorController
          .add(UserAccelerometerEvent(1.0, 1.0, 0.0, DateTime.now()));
      await tester.pumpAndSettle();

      expect(NetworkInspector.isOpen, isFalse);
      expect(find.byType(NetworkInspectorScreen), findsNothing);
    });

    testWidgets('debounces rapid shake events', (tester) async {
      int openCallCount = 0;
      DateTime fakeTime = DateTime(2026, 1, 1, 12, 0, 0);

      final detector = ShakeDetector(
        clock: () => fakeTime,
        onShake: () {
          openCallCount++;
        },
        threshold: 10.0,
        debounceMs: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorWrapper(
            customShakeDetector: detector,
            child: const Scaffold(
              body: Center(child: Text('App Content')),
            ),
          ),
        ),
      );

      // First shake event
      sensorController
          .add(UserAccelerometerEvent(15.0, 0.0, 0.0, DateTime.now()));
      await tester.pump();
      expect(openCallCount, 1);

      // Immediate second shake within debounce window (0ms elapsed)
      sensorController
          .add(UserAccelerometerEvent(15.0, 0.0, 0.0, DateTime.now()));
      await tester.pump();
      expect(openCallCount, 1);

      // Advance clock past debounce window (100ms)
      fakeTime = fakeTime.add(const Duration(milliseconds: 150));

      // Third shake event after cooldown
      sensorController
          .add(UserAccelerometerEvent(15.0, 0.0, 0.0, DateTime.now()));
      await tester.pump();
      expect(openCallCount, 2);
    });

    testWidgets('reentrancy guard prevents opening inspector if already open', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NetworkInspectorWrapper(
            child: Scaffold(
              body: Center(child: Text('App Content')),
            ),
          ),
        ),
      );

      // First shake opens inspector
      sensorController
          .add(UserAccelerometerEvent(15.0, 0.0, 0.0, DateTime.now()));
      await tester.pumpAndSettle();

      expect(NetworkInspector.isOpen, isTrue);
      expect(find.byType(NetworkInspectorScreen), findsOneWidget);

      // Advance time beyond debounce window
      await tester.pump(const Duration(milliseconds: 200));

      // Second shake while inspector is already open
      sensorController
          .add(UserAccelerometerEvent(15.0, 0.0, 0.0, DateTime.now()));
      await tester.pumpAndSettle();

      // Should still only have one NetworkInspectorScreen on route stack
      expect(find.byType(NetworkInspectorScreen), findsOneWidget);
    });

    testWidgets('NetworkInspector.open works with explicitly passed context', (
      tester,
    ) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(
                body: Center(child: Text('Direct Open')),
              );
            },
          ),
        ),
      );

      expect(NetworkInspector.isOpen, isFalse);

      unawaited(NetworkInspector.open(capturedContext));
      await tester.pumpAndSettle();

      expect(NetworkInspector.isOpen, isTrue);
      expect(find.byType(NetworkInspectorScreen), findsOneWidget);

      // Pop route
      Navigator.of(capturedContext, rootNavigator: true).pop();
      await tester.pumpAndSettle();

      expect(NetworkInspector.isOpen, isFalse);
      expect(find.byType(NetworkInspectorScreen), findsNothing);
    });

    testWidgets(
        'NetworkInspector.open works contextless via NetworkInspector.navigatorKey',
        (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: NetworkInspector.navigatorKey,
          home: const Scaffold(
            body: Center(child: Text('NavigatorKey Test')),
          ),
        ),
      );

      expect(NetworkInspector.isOpen, isFalse);

      unawaited(NetworkInspector.open());
      await tester.pumpAndSettle();

      expect(NetworkInspector.isOpen, isTrue);
      expect(find.byType(NetworkInspectorScreen), findsOneWidget);

      Navigator.of(NetworkInspector.navigatorKey.currentContext!,
              rootNavigator: true)
          .pop();
      await tester.pumpAndSettle();

      expect(NetworkInspector.isOpen, isFalse);
    });

    testWidgets(
        'NetworkInspectorWrapper works with MaterialApp using NetworkInspector.navigatorKey',
        (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: NetworkInspector.navigatorKey,
          home: const NetworkInspectorWrapper(
            child: Scaffold(
              body: Center(child: Text('NavigatorKey App')),
            ),
          ),
        ),
      );

      expect(NetworkInspector.isOpen, isFalse);

      // Violent shake event
      sensorController
          .add(UserAccelerometerEvent(15.0, 0.0, 0.0, DateTime.now()));
      await tester.pumpAndSettle();

      expect(NetworkInspector.isOpen, isTrue);
      expect(find.byType(NetworkInspectorScreen), findsOneWidget);
    });

    testWidgets(
        'standalone shake detection triggers NetworkInspector.open via NetworkInspector.navigatorKey without wrapper',
        (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: NetworkInspector.navigatorKey,
          home: const Scaffold(
            body: Center(child: Text('Standalone Shake App')),
          ),
        ),
      );

      expect(NetworkInspector.isOpen, isFalse);

      sensorController
          .add(UserAccelerometerEvent(15.0, 0.0, 0.0, DateTime.now()));
      await tester.pumpAndSettle();

      expect(NetworkInspector.isOpen, isTrue);
      expect(find.byType(NetworkInspectorScreen), findsOneWidget);
    });
  });
}
