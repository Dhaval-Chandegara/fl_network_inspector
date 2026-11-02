# Phase 05: Shake & Developer Experience - Pattern Mapping

## File Classification & Analogs

| File | Classification | Nearest Analog | Pattern & Relationship |
|------|----------------|----------------|------------------------|
| `lib/src/config/network_inspector_config.dart` | Config extension | `NetworkInspectorConfig` | Adds `shakeThreshold` (`double`, default 15.0) and `shakeDebounceMs` (`int`, default 1500) with immutable copyWith. |
| `lib/src/shake/shake_detector.dart` | Hardware Controller | `StreamTapTransformer` / `ManualLogger` | Encapsulated controller with stream subscription management, lifecycle observer integration, and Euclidean vector math. |
| `lib/src/ui/widgets/network_inspector_wrapper.dart` | Presentation Wrapper | `NetworkInspectorScreen` | `StatefulWidget` wrapping root child, binding shake detector and lifecycle hooks without disturbing layout tree. |
| `lib/src/core/network_inspector.dart` | Facade Extension | `NetworkInspector` | Hooks `ShakeDetector` into `initialize`, `dispose`, and makes `open([BuildContext? context])` optional. |
| `lib/flutter_network_inspector.dart` | Public API Barrel | Root barrel export | Exports `NetworkInspectorWrapper` and `ShakeDetector`. |
| `test/shake/shake_detector_test.dart` | Hardware Unit Test | `test/interceptor/stream_tap_transformer_test.dart` | Injects synthetic `Stream<UserAccelerometerEvent>` to test threshold, debounce, lifecycle states, and error suppression. |
| `test/shake/network_inspector_wrapper_test.dart` | Widget Test | `test/ui/network_inspector_screen_test.dart` | Tests root wrapper rendering, shake navigation, contextless `open()`, and release mode no-op. |
