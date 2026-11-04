import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_network_inspector/src/models/record_filter.dart';
import 'package:fl_network_inspector/src/repository/in_memory_network_inspector_repository.dart';
import 'package:fl_network_inspector/src/ui/components/filter_bottom_sheet.dart';
import 'package:fl_network_inspector/src/ui/controllers/inspector_view_model.dart';
import 'package:fl_network_inspector/src/ui/network_inspector_screen.dart';

import 'helpers/test_record_fixtures.dart';

void main() {
  group('Filter Chips & Modal Bottom Sheet Tests', () {
    testWidgets('FilterChipsBar toggles Errors Only and method filters',
        (tester) async {
      final repository = InMemoryNetworkInspectorRepository();
      await repository.save(TestRecordFixtures.getSuccessRecord); // GET 200
      await repository.save(TestRecordFixtures.postSuccessRecord); // POST 201
      await repository
          .save(TestRecordFixtures.serverErrorRecord); // POST 500 failed

      final viewModel = InspectorViewModel(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorScreen(viewModel: viewModel),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('/v1/users'), findsOneWidget);
      expect(find.text('/v1/orders'), findsOneWidget);
      expect(find.text('/v1/checkout'), findsOneWidget);

      // Tap "Errors Only" chip
      await tester.tap(find.widgetWithText(FilterChip, 'Errors Only'));
      await tester.pumpAndSettle();

      expect(find.text('/v1/checkout'), findsOneWidget);
      expect(find.text('/v1/users'), findsNothing);
      expect(find.text('/v1/orders'), findsNothing);

      // Tap "Errors Only" chip again to deselect
      await tester.tap(find.widgetWithText(FilterChip, 'Errors Only'));
      await tester.pumpAndSettle();

      expect(find.text('/v1/users'), findsOneWidget);
      expect(find.text('/v1/orders'), findsOneWidget);
      expect(find.text('/v1/checkout'), findsOneWidget);

      // Tap "GET" chip
      await tester.tap(find.widgetWithText(FilterChip, 'GET'));
      await tester.pumpAndSettle();

      expect(find.text('/v1/users'), findsOneWidget);
      expect(find.text('/v1/orders'), findsNothing);
      expect(find.text('/v1/checkout'), findsNothing);
    });

    testWidgets('FilterBottomSheet applies multi-parameter criteria',
        (tester) async {
      final repository = InMemoryNetworkInspectorRepository();
      await repository
          .save(TestRecordFixtures.getSuccessRecord); // GET 200, 45ms
      await repository
          .save(TestRecordFixtures.clientErrorRecord); // GET 404, 82ms
      await repository
          .save(TestRecordFixtures.serverErrorRecord); // POST 500, 310ms
      await repository
          .save(TestRecordFixtures.socketFailedRecord); // GET failed, 1500ms

      final viewModel = InspectorViewModel(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorScreen(viewModel: viewModel),
        ),
      );

      await tester.pumpAndSettle();

      // Open filter sheet
      final openFilterFinder = find.byTooltip('Open filter sheet');
      await tester.ensureVisible(openFilterFinder);
      await tester.pumpAndSettle();
      await tester.tap(openFilterFinder);
      await tester.pumpAndSettle();

      expect(find.text('Filter Requests'), findsOneWidget);

      // Select 4xx Client Error chip in sheet
      await tester.tap(find.text('4xx Client Error'));
      await tester.pumpAndSettle();

      // Scroll sheet down to reveal Apply Filters button
      await tester.drag(find.text('Filter Requests'), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Tap Apply Filters
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(find.text('/v1/items/999'), findsOneWidget);
      expect(find.text('/v1/users'), findsNothing);
      expect(find.text('/v1/checkout'), findsNothing);
    });

    testWidgets(
        'FilterBottomSheet date range selection normalizes end date to end of day',
        (tester) async {
      RecordFilter? appliedFilter;
      final today = DateTime.now();
      final initialRangeStart = DateTime(today.year, today.month, today.day);
      final initialRangeEnd = DateTime(today.year, today.month, today.day);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  appliedFilter = await FilterBottomSheet.show(
                    context,
                    initialFilter: RecordFilter(
                      startDate: initialRangeStart,
                      endDate: initialRangeEnd,
                    ),
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Scroll to reveal Date Range button
      final dateButtonFinder = find.byIcon(Icons.date_range_rounded);
      await tester.ensureVisible(dateButtonFinder);
      await tester.pumpAndSettle();

      // Tap Date Range button (shows formatted date)
      await tester.tap(dateButtonFinder);
      await tester.pumpAndSettle();

      // In showDateRangePicker with initial date range, tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Tap Apply Filters
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(appliedFilter, isNotNull);
      expect(appliedFilter!.endDate, isNotNull);
      expect(appliedFilter!.endDate!.hour, 23);
      expect(appliedFilter!.endDate!.minute, 59);
      expect(appliedFilter!.endDate!.second, 59);
      expect(appliedFilter!.endDate!.millisecond, 999);
    });
  });
}
