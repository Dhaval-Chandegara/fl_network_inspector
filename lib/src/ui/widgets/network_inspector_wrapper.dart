import 'package:flutter/material.dart';

import '../../core/network_inspector.dart';
import '../../shake/shake_detector.dart';

/// Root application widget that enables shake-to-open gesture detection and lifecycle management (DEV-02, SHAKE-01, SHAKE-03).
///
/// Wraps the host application's root widget tree, automatically attaching [ShakeDetector]
/// when enabled and capturing [navigatorKey] for contextless programmatic opening.
class NetworkInspectorWrapper extends StatefulWidget {
  /// The root widget tree (typically [MaterialApp] or [CupertinoApp]).
  final Widget child;

  /// Optional root navigator key for programmatic opening without [BuildContext].
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Whether shake detection and inspector invocation should be active.
  ///
  /// Defaults to `null`, which inherits [NetworkInspector.isEnabled].
  final bool? enabled;

  /// Optional custom shake detector for testing or specialized gesture handling.
  final ShakeDetector? customShakeDetector;

  const NetworkInspectorWrapper({
    super.key,
    required this.child,
    this.navigatorKey,
    this.enabled,
    this.customShakeDetector,
  });

  @override
  State<NetworkInspectorWrapper> createState() =>
      _NetworkInspectorWrapperState();
}

class _NetworkInspectorWrapperState extends State<NetworkInspectorWrapper> {
  ShakeDetector? _shakeDetector;

  bool get _shouldEnable => widget.enabled ?? NetworkInspector.isEnabled;

  @override
  void initState() {
    super.initState();
    _initShakeDetector();
  }

  @override
  void didUpdateWidget(NetworkInspectorWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigatorKey != oldWidget.navigatorKey) {
      NetworkInspector.unregisterWrapperNavigatorKey(oldWidget.navigatorKey);
      _registerNavigatorKey();
    }
    if (widget.enabled != oldWidget.enabled) {
      _initShakeDetector();
    }
  }

  void _registerNavigatorKey() {
    if (widget.navigatorKey != null) {
      NetworkInspector.registerWrapperNavigatorKey(widget.navigatorKey);
    }
  }

  void _initShakeDetector() {
    _registerNavigatorKey();

    if (!_shouldEnable ||
        !NetworkInspector.currentConfig.enableShakeDetection) {
      _shakeDetector?.dispose();
      _shakeDetector = null;
      return;
    }

    if (_shakeDetector == null) {
      _shakeDetector = widget.customShakeDetector ??
          ShakeDetector(
            onShake: _onShakeTriggered,
            threshold: NetworkInspector.currentConfig.shakeThreshold,
            debounceMs: NetworkInspector.currentConfig.shakeDebounceMs,
          );
      _shakeDetector!.start();
    }
  }

  void _onShakeTriggered() {
    NetworkInspector.open(context);
  }

  @override
  void dispose() {
    _shakeDetector?.dispose();
    _shakeDetector = null;
    NetworkInspector.unregisterWrapperNavigatorKey(widget.navigatorKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
