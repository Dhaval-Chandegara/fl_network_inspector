---
status: resolved
trigger: "need to fix the pubpoints of pub.dev package publish. below points required to fullfill and complete package points. 0/20 points: Compatible with dependency constraint lower bounds. downgrade analysis failed failed with 1 error: UNDFINED_CLASS - lib/src/interceptor/dio/network_inspector_dio_interceptor.dart:296:16 - Undefined class 'DioException'. Run flutter pub downgrade and then flutter analyze to reproduce the above problem. You may run dart pub upgrade --tighten to update your dependency constraints, see dart.dev/go/downgrade-testing for details. you can also check package score https://pub.dev/packages/fl_network_inspector/score here. i want complete 160 score in pub.dev."
created: 2026-11-06T23:31:35Z
updated: 2026-11-06T23:46:30Z
resolved: 2026-11-06T23:46:30Z
---

# Debug Session: pub-points-dio-downgrade

## Symptoms
- **Expected behavior**: Package achieves 160/160 pub points on pub.dev by passing all pana quality gates, including the 20-point "Compatible with dependency constraint lower bounds" check (`flutter pub downgrade && flutter analyze` passes cleanly).
- **Actual behavior**: 0/20 points awarded for dependency constraint lower bounds (total: 140/160). Downgrade analysis failed with `UNDEFINED_CLASS - lib/src/interceptor/dio/network_inspector_dio_interceptor.dart:296:16 - Undefined class 'DioException'`.
- **Error message**: `UNDEFINED_CLASS - lib/src/interceptor/dio/network_inspector_dio_interceptor.dart:296:16 - Undefined class 'DioException'`.
- **Timeline**: Present on pub.dev package score page for `fl_network_inspector` v1.0.0.
- **Reproduction**: Run `flutter pub downgrade` and then `flutter analyze`.

## Evidence
- timestamp: 2026-11-06T23:34:09Z
  command: flutter pub downgrade && flutter analyze
  output: UNDEFINED_CLASS - lib/src/interceptor/dio/network_inspector_dio_interceptor.dart:296:16 - Undefined class 'DioException'
- timestamp: 2026-11-06T23:34:54Z
  finding: Dio changelog confirms DioException was introduced in Dio 5.2.0 (replacing deprecated DioError). In Dio 5.0.0 and 5.1.0, DioException did not exist.
- timestamp: 2026-11-06T23:35:49Z
  finding: test/interceptor/dio_interceptor_test.dart used DioMediaType which was introduced in Dio 5.5.0; replacing with standard MediaType from package:http_parser provides universal compatibility.
- timestamp: 2026-11-06T23:41:22Z
  verification: flutter pub downgrade && flutter analyze passed with 0 errors after updating dio constraint to >=5.2.0 <6.0.0.
- timestamp: 2026-11-06T23:46:27Z
  pana_score: Local pana run scored 160/160 points with 20/20 points for dependency constraint lower bounds.

## Root Cause
In `pubspec.yaml`, the `dio` dependency was bounded as `">=5.0.0 <6.0.0"`. However, `DioException` (used in `NetworkInspectorDioInterceptor.onError`) was only introduced in Dio 5.2.0. When pana performs lower-bound testing via `flutter pub downgrade`, `dio` resolved to `5.0.0`, where `DioException` does not exist, causing static analysis failure and losing 20 pub points.

## Resolution
- Updated `pubspec.yaml` dependency constraint for `dio` to `">=5.2.0 <6.0.0"`.
- Replaced `DioMediaType` in `test/interceptor/dio_interceptor_test.dart` with `MediaType` from `package:http_parser/http_parser.dart` to ensure test suite remains fully compatible across all supported Dio 5.x lower bounds.

## Verification
- `flutter pub downgrade && flutter analyze`: Passed cleanly with 0 issues.
- `flutter pub upgrade && flutter analyze`: Passed cleanly with 0 issues.
- `flutter test`: All 213 unit and integration tests passed cleanly.
- `dart pub global run pana --no-warning .`: Scored 160/160 points (20/20 for "Compatible with dependency constraint lower bounds").

## Blameless Postmortem
- **Why not caught**: CI ran `flutter pub get` (resolving the latest transitive version, `dio: 5.11.1`) rather than `flutter pub downgrade && flutter analyze` before publishing.
- **Guard**: Add `flutter pub downgrade && flutter analyze` to package verification CI workflow prior to publishing releases to pub.dev.
