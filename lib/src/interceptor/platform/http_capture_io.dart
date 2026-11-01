import 'dart:io';

import '../../config/network_inspector_config.dart';
import '../io/http_overrides_manager.dart';

HttpOverrides? _previousOverrides;
bool _isInstalled = false;

/// Installs [InspectorHttpOverrides] globally while preserving [_previousOverrides] (INTC-01, INTC-02, D-38).
void installHttpOverrides(NetworkInspectorConfig config) {
  if (_isInstalled) return;
  _previousOverrides = HttpOverrides.current;
  HttpOverrides.global = InspectorHttpOverrides(
    previousOverrides: _previousOverrides,
    config: config,
  );
  _isInstalled = true;
}

/// Restores [_previousOverrides] and cleanly detaches dart:io interception (D-40).
void restoreHttpOverrides() {
  if (!_isInstalled) return;
  HttpOverrides.global = _previousOverrides;
  _previousOverrides = null;
  _isInstalled = false;
}

/// Executes [body] within a Zone configured with [InspectorHttpOverrides] (D-37).
R runWithHttpOverrides<R>(R Function() body, NetworkInspectorConfig config) {
  final overrides = InspectorHttpOverrides(
    previousOverrides: HttpOverrides.current,
    config: config,
  );
  return HttpOverrides.runWithHttpOverrides(body, overrides);
}
