import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/constants.dart';

/// Controller managing accelerometer shake detection and app lifecycle observation (SHAKE-01, SHAKE-02, SHAKE-03).
class ShakeDetector with WidgetsBindingObserver {
  /// Callback triggered when a qualifying shake gesture is detected.
  final VoidCallback onShake;

  /// Acceleration magnitude threshold in m/s² (SHAKE-01, SHAKE-02).
  final double threshold;

  /// Debounce window in milliseconds to suppress repeat firings (SHAKE-02).
  final int debounceMs;

  /// Custom sensor stream for testing or platform overrides.
  final Stream<UserAccelerometerEvent>? _customStream;

  /// Clock provider for timestamps (defaults to [DateTime.now]).
  final DateTime Function() _clock;

  /// Mock stream used across tests when platform channels are absent.
  @visibleForTesting
  static Stream<UserAccelerometerEvent>? mockStream;

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  int _lastShakeTimestamp = 0;
  bool _isStarted = false;
  bool _isPaused = false;
  bool _hasReportedError = false;

  ShakeDetector({
    required this.onShake,
    this.threshold = NetworkInspectorConstants.defaultShakeThreshold,
    this.debounceMs = NetworkInspectorConstants.defaultShakeDebounceMs,
    Stream<UserAccelerometerEvent>? customStream,
    DateTime Function()? clock,
  })  : _customStream = customStream,
        _clock = clock ?? DateTime.now;

  /// Returns whether the detector is currently actively listening.
  bool get isListening => _isStarted && !_isPaused && _subscription != null;

  /// Returns whether the detector has been started.
  bool get isStarted => _isStarted;

  /// Returns whether the detector is currently paused due to lifecycle state.
  bool get isPaused => _isPaused;

  /// Starts listening to accelerometer sensor events and registers lifecycle observer.
  void start() {
    if (_isStarted) return;
    _isStarted = true;
    _isPaused = false;

    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    _subscribe();
  }

  void _subscribe() {
    if (_subscription != null) return;

    try {
      final stream =
          _customStream ?? mockStream ?? userAccelerometerEventStream();
      _subscription = stream.listen(
        _handleEvent,
        onError: (Object error) {
          if (!_hasReportedError) {
            _hasReportedError = true;
            if (kDebugMode) {
              debugPrint(
                '[NetworkInspector] Accelerometer sensor unavailable. Shake detection disabled: $error',
              );
            }
          }
          _unsubscribe();
        },
        cancelOnError: true,
      );
    } catch (error) {
      if (!_hasReportedError) {
        _hasReportedError = true;
        if (kDebugMode) {
          debugPrint(
            '[NetworkInspector] Failed to initialize accelerometer stream: $error',
          );
        }
      }
    }
  }

  void _handleEvent(UserAccelerometerEvent event) {
    if (!_isStarted || _isPaused) return;

    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (magnitude >= threshold) {
      final now = _clock().millisecondsSinceEpoch;
      if (now - _lastShakeTimestamp >= debounceMs) {
        _lastShakeTimestamp = now;
        onShake();
      }
    }
  }

  /// Pauses accelerometer event sampling (SHAKE-03).
  void pause() {
    if (!_isStarted || _isPaused) return;
    _isPaused = true;
    _subscription?.pause();
  }

  /// Resumes accelerometer event sampling (SHAKE-03).
  void resume() {
    if (!_isStarted || !_isPaused) return;
    _isPaused = false;
    _subscription?.resume();
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Stops listening to accelerometer events and removes lifecycle observer.
  void stop() {
    if (!_isStarted) return;
    _isStarted = false;
    _isPaused = false;
    WidgetsBinding.instance.removeObserver(this);
    _unsubscribe();
  }

  /// AppLifecycleState change handler (SHAKE-03).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        resume();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        pause();
        break;
    }
  }

  /// Disposes the shake detector.
  void dispose() {
    stop();
  }
}
