import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_network_inspector/src/config/network_inspector_config.dart';
import 'package:fl_network_inspector/src/core/network_inspector.dart';
import 'package:fl_network_inspector/src/models/network_record.dart';
import 'package:fl_network_inspector/src/models/record_filter.dart';
import 'package:fl_network_inspector/src/models/record_sort.dart';
import 'package:fl_network_inspector/src/repository/in_memory_network_inspector_repository.dart';
import 'package:fl_network_inspector/src/ui/components/status_badge.dart';
import 'package:fl_network_inspector/src/ui/network_inspector_detail_screen.dart';
import 'package:fl_network_inspector/src/ui/network_inspector_screen.dart';

import 'helpers/test_record_fixtures.dart';

class FailingRepository extends InMemoryNetworkInspectorRepository {
  @override
  Future<List<NetworkRecord>> getRecords({
    RecordFilter? filter,
    RecordSort? sort,
    int limit = 50,
    int offset = 0,
  }) async {
    throw Exception('Storage permission denied');
  }
}

void main() {
  setUp(() {
    NetworkInspector.resetForTesting();
  });

  tearDown(() {
    NetworkInspector.resetForTesting();
  });

  group('NetworkInspectorScreen Tests', () {
    testWidgets('renders empty state "No Captured Traffic" when no records exist',
        (tester) async {
      final repository = InMemoryNetworkInspectorRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorScreen(repository: repository),
        ),
      );

      // Loading indicator first
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('No Captured Traffic'), findsOneWidget);
      expect(
        find.text(
          'Trigger network calls in your application to inspect HTTP requests and responses here.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.radar), findsOneWidget);
    });

    testWidgets('renders request tiles with method badges, status badges, and paths',
        (tester) async {
      final repository = InMemoryNetworkInspectorRepository();
      await repository.save(TestRecordFixtures.getSuccessRecord);
      await repository.save(TestRecordFixtures.postSuccessRecord);
      await repository.save(TestRecordFixtures.pendingRecord);

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorScreen(repository: repository),
        ),
      );

      await tester.pumpAndSettle();

      // Check method badges
      expect(find.widgetWithText(MethodBadge, 'GET'), findsOneWidget);
      expect(find.widgetWithText(MethodBadge, 'POST'), findsNWidgets(2));

      // Check status badges
      expect(find.widgetWithText(StatusBadge, '200'), findsOneWidget);
      expect(find.widgetWithText(StatusBadge, '201'), findsOneWidget);
      expect(find.widgetWithText(StatusBadge, 'Pending'), findsOneWidget);

      // Check paths
      expect(find.text('/v1/users'), findsOneWidget);
      expect(find.text('/v1/orders'), findsOneWidget);
      expect(find.text('/v1/upload'), findsOneWidget);

      // Check total count badge in app bar
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('pending record omits duration display', (tester) async {
      final repository = InMemoryNetworkInspectorRepository();
      await repository.save(TestRecordFixtures.pendingRecord);

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorScreen(repository: repository),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pending'), findsOneWidget);
      expect(find.textContaining('ms'), findsNothing);
    });

    testWidgets('displays error state when repository fetch throws', (tester) async {
      final repository = FailingRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorScreen(repository: repository),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(
          'Failed to load network records: check storage permissions and tap Retry.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('NetworkInspector.open Navigation Reentrancy Tests', () {
    testWidgets('open(context) pushes screen and guards against duplicate open',
        (tester) async {
      final repository = InMemoryNetworkInspectorRepository();
      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(enabled: true),
        repository: repository,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () => NetworkInspector.open(context),
                  child: const Text('Open Inspector'),
                ),
              );
            },
          ),
        ),
      );

      expect(NetworkInspector.isOpen, isFalse);

      // Tap button to open
      await tester.tap(find.text('Open Inspector'));
      await tester.pump(); // Start transition

      expect(NetworkInspector.isOpen, isTrue);

      // Rapid second tap while open should be ignored (reentrancy guard)
      final BuildContext currentContext = tester.element(find.byType(ElevatedButton));
      await NetworkInspector.open(currentContext);

      await tester.pumpAndSettle();
      expect(find.byType(NetworkInspectorScreen), findsOneWidget);

      // Pop the screen
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(NetworkInspectorScreen), findsNothing);
      expect(NetworkInspector.isOpen, isFalse);
    });

    testWidgets('open(context) is no-op when NetworkInspector is disabled',
        (tester) async {
      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(enabled: false),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () => NetworkInspector.open(context),
                  child: const Text('Open Inspector'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Inspector'));
      await tester.pumpAndSettle();

      expect(find.byType(NetworkInspectorScreen), findsNothing);
      expect(NetworkInspector.isOpen, isFalse);
    });

    testWidgets('tapping RequestTile navigates to NetworkInspectorDetailScreen',
        (tester) async {
      final repository = InMemoryNetworkInspectorRepository();
      await repository.save(TestRecordFixtures.getSuccessRecord);

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorScreen(repository: repository),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the request tile
      await tester.tap(find.text('/v1/users'));
      await tester.pumpAndSettle();

      // Verify NetworkInspectorDetailScreen is on the screen
      expect(find.byType(NetworkInspectorDetailScreen), findsOneWidget);
      expect(find.text('Request Details'), findsOneWidget);
    });
  });
}
