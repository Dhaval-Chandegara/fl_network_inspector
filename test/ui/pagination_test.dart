import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_network_inspector/src/repository/in_memory_network_inspector_repository.dart';
import 'package:fl_network_inspector/src/ui/controllers/inspector_view_model.dart';
import 'package:fl_network_inspector/src/ui/network_inspector_screen.dart';

import 'helpers/test_record_fixtures.dart';

void main() {
  group('Pagination & Infinite Scroll Tests', () {
    testWidgets('loads initial 50 records and auto-fetches next 50 on scroll',
        (tester) async {
      final repository = InMemoryNetworkInspectorRepository(maxRecords: 200);
      final records = TestRecordFixtures.generateRecords(120);
      await repository.saveBatch(records);

      final viewModel = InspectorViewModel(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorScreen(
            viewModel: viewModel,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check initial 50 records loaded
      expect(viewModel.records.length, 50);
      expect(viewModel.totalCount, 120);
      expect(viewModel.hasMore, isTrue);

      // Scroll to trigger loadMore
      final listFinder = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      await tester.drag(listFinder, const Offset(0, -3000));
      await tester.pump();
      await tester.pumpAndSettle();

      // Next batch loaded: 50 + 50 = 100
      expect(viewModel.records.length, 100);
      expect(viewModel.hasMore, isTrue);

      // Scroll again for last 20
      await tester.drag(listFinder, const Offset(0, -3000));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(viewModel.records.length, 120);
      expect(viewModel.hasMore, isFalse);
    });

    testWidgets('pull to refresh resets offset and reloads latest batch',
        (tester) async {
      final repository = InMemoryNetworkInspectorRepository(maxRecords: 200);
      final records = TestRecordFixtures.generateRecords(120);
      await repository.saveBatch(records);

      final viewModel = InspectorViewModel(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorScreen(
            viewModel: viewModel,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(viewModel.records.length, 50);

      // Scroll to load second page
      final listFinder = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      await tester.drag(listFinder, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(viewModel.records.length, 100);

      // Scroll back to top before pulling down
      await tester.drag(listFinder, const Offset(0, 3000));
      await tester.pumpAndSettle();

      // Trigger pull-to-refresh
      await tester.drag(listFinder, const Offset(0, 300));
      await tester.pump();
      await tester.pumpAndSettle();

      // Reset to first page of 50
      expect(viewModel.records.length, 50);
      expect(viewModel.hasMore, isTrue);
    });
  });
}
