import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:fl_network_inspector/src/shake/shake_detector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShakeDetector', () {
    late StreamController<UserAccelerometerEvent> controller;
    late List<DateTime> shakeEvents;
    late ShakeDetector detector;

    setUp(() {
      controller = StreamController<UserAccelerometerEvent>.broadcast();
      shakeEvents = [];
      detector = ShakeDetector(
        onShake: () => shakeEvents.add(DateTime.now()),
        threshold: 15.0,
        debounceMs: 500, // shorter debounce for testing
        customStream: controller.stream,
      );
    });

    tearDown(() async {
      detector.dispose();
      await controller.close();
    });

    test('starts and listens to custom stream', () {
      expect(detector.isStarted, isFalse);
      expect(detector.isListening, isFalse);

      detector.start();

      expect(detector.isStarted, isTrue);
      expect(detector.isListening, isTrue);
      expect(detector.isPaused, isFalse);
    });

    test('ignores events below threshold', () async {
      detector.start();

      // Magnitude = sqrt(2^2 + 3^2 + 1^2) = sqrt(14) ≈ 3.74 < 15.0
      controller.add(UserAccelerometerEvent(2.0, 3.0, 1.0, DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(shakeEvents, isEmpty);
    });

    test('triggers onShake when vector magnitude exceeds threshold', () async {
      detector.start();

      // Magnitude = sqrt(10^2 + 10^2 + 5^2) = sqrt(225) = 15.0 >= 15.0
      controller.add(UserAccelerometerEvent(10.0, 10.0, 5.0, DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(shakeEvents.length, equals(1));
    });

    test('enforces debounce cooldown window to suppress rapid repeat events', () async {
      detector.start();

      // First shake event
      controller.add(UserAccelerometerEvent(12.0, 10.0, 5.0, DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(shakeEvents.length, equals(1));

      // Second shake event immediately (within 500ms debounce)
      controller.add(UserAccelerometerEvent(15.0, 12.0, 8.0, DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(shakeEvents.length, equals(1), reason: 'Debounce should suppress rapid repeat');

      // Wait for debounce window to elapse
      await Future<void>.delayed(const Duration(milliseconds: 550));

      // Third shake event after cooldown
      controller.add(UserAccelerometerEvent(11.0, 11.0, 4.0, DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(shakeEvents.length, equals(2), reason: 'Shake after debounce window should trigger');
    });

    test('pauses and resumes sampling across app lifecycle states', () async {
      detector.start();
      expect(detector.isPaused, isFalse);

      // App transitions to background (paused)
      detector.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(detector.isPaused, isTrue);

      // Event emitted during pause should be ignored
      controller.add(UserAccelerometerEvent(20.0, 20.0, 20.0, DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(shakeEvents, isEmpty);

      // App returns to foreground (resumed)
      detector.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(detector.isPaused, isFalse);

      // Subsequent event triggers onShake
      controller.add(UserAccelerometerEvent(10.0, 10.0, 5.0, DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(shakeEvents.length, equals(1));
    });

    test('pauses sampling on inactive and hidden lifecycle states', () {
      detector.start();

      detector.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(detector.isPaused, isTrue);

      detector.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(detector.isPaused, isFalse);

      detector.didChangeAppLifecycleState(AppLifecycleState.hidden);
      expect(detector.isPaused, isTrue);
    });

    test('catches stream errors gracefully without throwing unhandled exceptions', () async {
      detector.start();

      controller.addError(Exception('Platform sensor channel failure'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Subscription should be cancelled gracefully
      expect(detector.isListening, isFalse);
    });

    test('stop and dispose cleanly cancel subscription', () {
      detector.start();
      expect(detector.isStarted, isTrue);

      detector.stop();
      expect(detector.isStarted, isFalse);
      expect(detector.isListening, isFalse);

      // Calling stop or dispose multiple times is idempotent and safe
      detector.dispose();
      expect(detector.isStarted, isFalse);
    });
  });
}
