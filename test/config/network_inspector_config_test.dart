import 'package:flutter/foundation.dart';
import 'package:flutter_network_inspector/src/config/network_inspector_config.dart';
import 'package:flutter_network_inspector/src/core/constants.dart';
import 'package:flutter_network_inspector/src/core/network_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkInspectorConfig', () {
    tearDown(() {
      NetworkInspector.resetForTesting();
    });

    test('default constructor matches architectural decisions D-01, D-02, D-04, D-15, D-36', () {
      const config = NetworkInspectorConfig();

      expect(config.maxRecords, equals(500), reason: 'Default maxRecords should be 500 per D-01');
      expect(config.maxBodyBytes, equals(1048576), reason: 'Default maxBodyBytes should be 1MB per D-02');
      expect(config.enableAutoCapture, isTrue, reason: 'enableAutoCapture defaults to true per D-04');
      expect(config.enableShakeDetection, isTrue, reason: 'enableShakeDetection defaults to true per D-04');
      expect(config.shakeThreshold, equals(15.0), reason: 'shakeThreshold defaults to 15.0 m/s² per SHAKE-01');
      expect(config.shakeDebounceMs, equals(1500), reason: 'shakeDebounceMs defaults to 1500ms per SHAKE-02');
      expect(config.enableDatabase, isTrue, reason: 'enableDatabase defaults to true per D-04');
      expect(config.includeMultipartFilePaths, isFalse, reason: 'includeMultipartFilePaths defaults to false per D-15');
      expect(config.customRedactionKeys, isEmpty);
      expect(config.ignoredHosts, isEmpty, reason: 'ignoredHosts defaults to empty per D-36');
      expect(config.ignoredUrls, isEmpty, reason: 'ignoredUrls defaults to empty per D-36');
      expect(config.hasExplicitEnabled, isFalse);
    });

    test('release-mode resolution honors D-03', () {
      // When enabled is omitted, it evaluates to !kReleaseMode
      const defaultConfig = NetworkInspectorConfig();
      expect(defaultConfig.enabled, equals(!kReleaseMode));

      // When explicitly set to true, it evaluates to true
      const enabledConfig = NetworkInspectorConfig(enabled: true);
      expect(enabledConfig.enabled, isTrue);
      expect(enabledConfig.hasExplicitEnabled, isTrue);

      // When explicitly set to false, it evaluates to false
      const disabledConfig = NetworkInspectorConfig(enabled: false);
      expect(disabledConfig.enabled, isFalse);
      expect(disabledConfig.hasExplicitEnabled, isTrue);
    });

    test('granular feature flags can be toggled independently (D-04)', () {
      const config = NetworkInspectorConfig(
        enableAutoCapture: false,
        enableShakeDetection: false,
        enableDatabase: false,
      );

      expect(config.enableAutoCapture, isFalse);
      expect(config.enableShakeDetection, isFalse);
      expect(config.enableDatabase, isFalse);
      expect(config.maxRecords, equals(NetworkInspectorConstants.defaultMaxRecords));
    });

    test('copyWith creates modified copy with exact overrides including blacklists (D-36)', () {
      const original = NetworkInspectorConfig(
        maxRecords: 100,
        customRedactionKeys: ['secret_token'],
        ignoredHosts: ['firebase.com'],
        ignoredUrls: ['/analytics'],
      );

      final modified = original.copyWith(
        maxRecords: 250,
        enableShakeDetection: false,
        shakeThreshold: 20.0,
        shakeDebounceMs: 2500,
        ignoredHosts: ['sentry.io'],
      );

      expect(modified.maxRecords, equals(250));
      expect(modified.enableShakeDetection, isFalse);
      expect(modified.shakeThreshold, equals(20.0));
      expect(modified.shakeDebounceMs, equals(2500));
      expect(modified.customRedactionKeys, equals(['secret_token']));
      expect(modified.ignoredHosts, equals(['sentry.io']));
      expect(modified.ignoredUrls, equals(['/analytics']));
      expect(original.maxRecords, equals(100));
      expect(original.enableShakeDetection, isTrue);
      expect(original.ignoredHosts, equals(['firebase.com']));
    });

    test('supports value equality and hash code with blacklists (D-36)', () {
      const configA = NetworkInspectorConfig(
        maxRecords: 200,
        customRedactionKeys: ['api_key'],
        ignoredHosts: ['example.com'],
        ignoredUrls: ['/ping'],
      );
      const configB = NetworkInspectorConfig(
        maxRecords: 200,
        customRedactionKeys: ['api_key'],
        ignoredHosts: ['example.com'],
        ignoredUrls: ['/ping'],
      );
      const configC = NetworkInspectorConfig(
        maxRecords: 200,
        customRedactionKeys: ['api_key'],
        ignoredHosts: ['other.com'],
        ignoredUrls: ['/ping'],
      );

      expect(configA, equals(configB));
      expect(configA.hashCode, equals(configB.hashCode));
      expect(configA, isNot(equals(configC)));
    });
  });

  group('NetworkInspector Facade (CORE-01)', () {
    tearDown(() {
      NetworkInspector.resetForTesting();
    });

    test('starts with uninitialized default configuration', () {
      expect(NetworkInspector.isInitialized, isFalse);
      expect(NetworkInspector.currentConfig.maxRecords, equals(500));
      expect(NetworkInspector.isEnabled, equals(!kReleaseMode));
    });

    test('initialize stores configuration and sets isInitialized', () async {
      const customConfig = NetworkInspectorConfig(
        enabled: true,
        maxRecords: 1000,
        enableShakeDetection: false,
        enableDatabase: false,
      );

      await NetworkInspector.initialize(config: customConfig);

      expect(NetworkInspector.isInitialized, isTrue);
      expect(NetworkInspector.currentConfig, equals(customConfig));
      expect(NetworkInspector.isEnabled, isTrue);
      expect(NetworkInspector.currentConfig.maxRecords, equals(1000));
      expect(NetworkInspector.currentConfig.enableShakeDetection, isFalse);
      expect(NetworkInspector.repository, isNotNull);
    });

    test('resetForTesting restores initial state', () async {
      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(
          enabled: true,
          maxRecords: 999,
          enableDatabase: false,
        ),
      );
      expect(NetworkInspector.isInitialized, isTrue);
      expect(NetworkInspector.repository, isNotNull);

      NetworkInspector.resetForTesting();

      expect(NetworkInspector.isInitialized, isFalse);
      expect(NetworkInspector.repository, isNull);
      expect(NetworkInspector.currentConfig.maxRecords, equals(500));
    });
  });
}
