import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_network_inspector/src/repository/in_memory_network_inspector_repository.dart';
import 'package:fl_network_inspector/src/ui/controllers/inspector_view_model.dart';
import 'package:fl_network_inspector/src/ui/network_inspector_screen.dart';

import 'helpers/test_record_fixtures.dart';

void main() {
  group('Search Bar & Debounce Tests', () {
    testWidgets('debounces search input by 300ms across records', (tester) async {
      final repository = InMemoryNetworkInspectorRepository();
      await repository.save(TestRecordFixtures.getSuccessRecord); // /v1/users
      await repository.save(TestRecordFixtures.postSuccessRecord); // /v1/orders
      await repository.save(TestRecordFixtures.clientErrorRecord); // /v1/items/999

      final viewModel = InspectorViewModel(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorScreen(viewModel: viewModel),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('/v1/users'), findsOneWidget);
      expect(find.text('/v1/orders'), findsOneWidget);
      expect(find.text('/v1/items/999'), findsOneWidget);

      // Enter search query "orders"
      final searchFinder = find.byType(SearchBar);
      expect(searchFinder, findsOneWidget);
      await tester.enterText(searchFinder, 'orders');

      // Advance by 200ms (before debounce expires)
      await tester.pump(const Duration(milliseconds: 200));
      // All 3 records still visible because debounce hasn't elapsed
      expect(viewModel.filter.searchQuery, isNull);

      // Advance past 300ms (debounce expires)
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(viewModel.filter.searchQuery, 'orders');
      expect(find.text('/v1/orders'), findsOneWidget);
      expect(find.text('/v1/users'), findsNothing);
      expect(find.text('/v1/items/999'), findsNothing);

      // Clear search button appears
      final clearButtonFinder = find.byTooltip('Clear search query');
      expect(clearButtonFinder, findsOneWidget);

      await tester.tap(clearButtonFinder);
      await tester.pumpAndSettle();

      expect(viewModel.filter.searchQuery, isNull);
      expect(find.text('/v1/users'), findsOneWidget);
      expect(find.text('/v1/orders'), findsOneWidget);
      expect(find.text('/v1/items/999'), findsOneWidget);
    });

    testWidgets('search matching zero records shows "No Matching Requests" empty state',
        (tester) async {
      final repository = InMemoryNetworkInspectorRepository();
      await repository.save(TestRecordFixtures.getSuccessRecord);

      final viewModel = InspectorViewModel(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorScreen(viewModel: viewModel),
        ),
      );

      await tester.pumpAndSettle();

      final searchFinder = find.byType(SearchBar);
      await tester.enterText(searchFinder, 'nonexistent_query_xyz');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('No Matching Requests'), findsOneWidget);
      expect(
        find.text(
          'Try adjusting your search terms or clearing active filters to see more results.',
        ),
        findsOneWidget,
      );

      // Tap Reset Filters
      await tester.tap(find.text('Reset Filters'));
      await tester.pumpAndSettle();

      expect(find.text('/v1/users'), findsOneWidget);
    });
  });
}
