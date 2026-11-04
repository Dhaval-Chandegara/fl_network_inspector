import '../../config/network_inspector_config.dart';

/// Web no-op stubs for HttpOverrides management.
void installHttpOverrides(NetworkInspectorConfig config) {}

/// Restores previous HttpOverrides on Web (no-op).
void restoreHttpOverrides() {}

/// Executes [body] with zone-scoped HttpOverrides (no-op on Web).
R runWithHttpOverrides<R>(R Function() body, NetworkInspectorConfig config) =>
    body();
