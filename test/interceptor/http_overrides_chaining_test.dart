import 'dart:io';

import 'package:flutter_network_inspector/flutter_network_inspector.dart';
import 'package:flutter_network_inspector/src/interceptor/io/http_overrides_manager.dart';
import 'package:flutter_network_inspector/src/interceptor/io/inspector_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockParentHttpOverrides extends HttpOverrides {
  bool createHttpClientCalled = false;
  bool findProxyCalled = false;
  SecurityContext? capturedContext;
  Uri? capturedUrl;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    createHttpClientCalled = true;
    capturedContext = context;
    return super.createHttpClient(context);
  }

  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    findProxyCalled = true;
    capturedUrl = url;
    return 'PROXY mock.corporate.proxy:8080';
  }
}

void main() {
  group('HttpOverrides Chaining & Lifecycle (INTC-01, INTC-02, D-38, D-40)', () {
    late HttpOverrides? originalGlobalOverrides;

    setUp(() {
      originalGlobalOverrides = HttpOverrides.current;
      NetworkInspector.resetForTesting();
    });

    tearDown(() {
      NetworkInspector.resetForTesting();
      HttpOverrides.global = originalGlobalOverrides;
    });

    test('InspectorHttpOverrides delegates createHttpClient and findProxy to parent overrides',
        () {
      final parentOverrides = _MockParentHttpOverrides();
      const config = NetworkInspectorConfig(enabled: true);

      final inspectorOverrides = InspectorHttpOverrides(
        previousOverrides: parentOverrides,
        config: config,
      );

      // Test createHttpClient delegation
      final client = inspectorOverrides.createHttpClient(null);
      expect(client, isA<InspectorHttpClient>());
      expect(parentOverrides.createHttpClientCalled, isTrue);

      // Test findProxyFromEnvironment delegation
      final proxy = inspectorOverrides.findProxyFromEnvironment(
        Uri.parse('https://example.com/api'),
        null,
      );
      expect(parentOverrides.findProxyCalled, isTrue);
      expect(parentOverrides.capturedUrl?.toString(), equals('https://example.com/api'));
      expect(proxy, equals('PROXY mock.corporate.proxy:8080'));
    });

    test('startAutoCapture installs InspectorHttpOverrides and preserves previous overrides',
        () async {
      final customParent = _MockParentHttpOverrides();
      HttpOverrides.global = customParent;

      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(enabled: true, enableAutoCapture: false),
        repository: InMemoryNetworkInspectorRepository(),
      );

      expect(HttpOverrides.current, same(customParent));

      // Explicitly start auto-capture
      NetworkInspector.startAutoCapture();

      expect(HttpOverrides.current, isA<InspectorHttpOverrides>());
      final activeOverrides = HttpOverrides.current as InspectorHttpOverrides;
      expect(activeOverrides.previousOverrides, same(customParent));

      // Stopping auto-capture restores the exact customParent
      NetworkInspector.stopAutoCapture();
      expect(HttpOverrides.current, same(customParent));
    });

    test('dispose() and resetForTesting() cleanly restore pre-existing HttpOverrides', () async {
      final initialParent = _MockParentHttpOverrides();
      HttpOverrides.global = initialParent;

      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(enabled: true, enableAutoCapture: true),
        repository: InMemoryNetworkInspectorRepository(),
      );

      expect(HttpOverrides.current, isA<InspectorHttpOverrides>());

      // Calling dispose cleanly restores initialParent
      await NetworkInspector.dispose();
      expect(HttpOverrides.current, same(initialParent));
    });

    test('runZoned executes within zone-scoped InspectorHttpOverrides without mutating global',
        () async {
      final initialParent = _MockParentHttpOverrides();
      HttpOverrides.global = initialParent;

      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(enabled: true, enableAutoCapture: false),
        repository: InMemoryNetworkInspectorRepository(),
      );

      expect(HttpOverrides.current, same(initialParent));

      final zoneResult = NetworkInspector.runZoned(() {
        expect(HttpOverrides.current, isA<InspectorHttpOverrides>());
        final zoneOverrides = HttpOverrides.current as InspectorHttpOverrides;
        expect(zoneOverrides.previousOverrides, same(initialParent));
        return 'zone-success';
      });

      expect(zoneResult, equals('zone-success'));
      // Global overrides remains unchanged
      expect(HttpOverrides.current, same(initialParent));
    });
  });
}
