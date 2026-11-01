import 'dart:io';

import '../../config/network_inspector_config.dart';
import 'inspector_http_client.dart';

/// Custom [HttpOverrides] that safely delegates unmatched calls to [previousOverrides]
/// while wrapping created clients in [InspectorHttpClient] (INTC-01, INTC-02, D-38).
class InspectorHttpOverrides extends HttpOverrides {
  final HttpOverrides? previousOverrides;
  final NetworkInspectorConfig config;

  InspectorHttpOverrides({
    this.previousOverrides,
    required this.config,
  });

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final HttpClient client = previousOverrides != null
        ? previousOverrides!.createHttpClient(context)
        : super.createHttpClient(context);
    return InspectorHttpClient(client, config);
  }

  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    if (previousOverrides != null) {
      return previousOverrides!.findProxyFromEnvironment(url, environment);
    }
    return super.findProxyFromEnvironment(url, environment);
  }
}
