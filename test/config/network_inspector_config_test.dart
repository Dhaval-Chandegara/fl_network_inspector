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

    test('default constructor matches architectural decisions D-01, D-02, D-04, D-15', () {
      const config = NetworkInspectorConfig();

      expect(config.maxRecords, equals(500), reason: 'Default maxRecords should be 500 per D-01');
      expect(config.maxBodyBytes, equals(1048576), reason: 'Default maxBodyBytes should be 1MB per D-02');
      expect(config.enableAutoCapture, isTrue, reason: 'enableAutoCapture defaults to true per D-04');
      expect(config.enableShakeDetection, isTrue, reason: 'enableShakeDetection defaults to true per D-04');
      expect(config.enableDatabase, isTrue, reason: 'enableDatabase defaults to true per D-04');
      expect(config.includeMultipartFilePaths, isFalse, reason: 'includeMultipartFilePaths defaults to false per D-15');
      expect(config.customRedactionKeys, isEmpty);
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

    test('copyWith creates modified copy with exact overrides', () {
      const original = NetworkInspectorConfig(
        maxRecords: 100,
        customRedactionKeys: ['secret_token'],
      );

      final modified = original.copyWith(
        maxRecords: 250,
        enableShakeDetection: false,
      );

      expect(modified.maxRecords, equals(250));
      expect(modified.enableShakeDetection, isFalse);
      expect(modified.customRedactionKeys, equals(['secret_token']));
      expect(original.maxRecords, equals(100));
      expect(original.enableShakeDetection, isTrue);
    });

    test('supports value equality and hash code', () {
      const configA = NetworkInspectorConfig(
        maxRecords: 200,
        customRedactionKeys: ['api_key'],
      );
      const configB = NetworkInspectorConfig(
        maxRecords: 200,
        customRedactionKeys: ['api_key'],
      );
      const configC = NetworkInspectorConfig(
        maxRecords: 300,
        customRedactionKeys: ['api_key'],
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

    test('initialize stores configuration and sets isInitialized', () {
      const customConfig = NetworkInspectorConfig(
        enabled: true,
        maxRecords: 1000,
        enableShakeDetection: false,
      );

      NetworkInspector.initialize(config: customConfig);

      expect(NetworkInspector.isInitialized, isTrue);
      expect(NetworkInspector.currentConfig, equals(customConfig));
      expect(NetworkInspector.isEnabled, isTrue);
      expect(NetworkInspector.currentConfig.maxRecords, equals(1000));
      expect(NetworkInspector.currentConfig.enableShakeDetection, isFalse);
    });

    test('resetForTesting restores initial state', () {
      NetworkInspector.initialize(
        config: const NetworkInspectorConfig(enabled: true, maxRecords: 999),
      );
      expect(NetworkInspector.isInitialized, isTrue);

      NetworkInspector.resetForTesting();

      expect(NetworkInspector.isInitialized, isFalse);
      expect(NetworkInspector.currentConfig.maxRecords, equals(500));
    });
  });
}
