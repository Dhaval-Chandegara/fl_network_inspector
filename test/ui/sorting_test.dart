import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_network_inspector/src/repository/in_memory_network_inspector_repository.dart';
import 'package:fl_network_inspector/src/ui/controllers/inspector_view_model.dart';
import 'package:fl_network_inspector/src/ui/network_inspector_screen.dart';

import 'helpers/test_record_fixtures.dart';

void main() {
  group('Sorting Popup Menu Tests', () {
    testWidgets(
        'AppBar SortMenuButton reorders records by duration and timestamp',
        (tester) async {
      final repository = InMemoryNetworkInspectorRepository();
      final now = DateTime.now();

      final fastRecord = TestRecordFixtures.createRecord(
        id: 'fast',
        url: 'https://api.example.com/fast',
        durationMs: 50,
        timestamp: now.subtract(const Duration(minutes: 1)),
      );
      final mediumRecord = TestRecordFixtures.createRecord(
        id: 'medium',
        url: 'https://api.example.com/medium',
        durationMs: 450,
        timestamp: now.subtract(const Duration(minutes: 2)),
      );
      final slowRecord = TestRecordFixtures.createRecord(
        id: 'slow',
        url: 'https://api.example.com/slow',
        durationMs: 1500,
        timestamp: now.subtract(const Duration(minutes: 3)),
      );

      await repository.save(fastRecord);
      await repository.save(mediumRecord);
      await repository.save(slowRecord);

      final viewModel = InspectorViewModel(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorScreen(viewModel: viewModel),
        ),
      );

      await tester.pumpAndSettle();

      // Tap sort menu
      await tester.tap(find.byTooltip('Sort records'));
      await tester.pumpAndSettle();

      // Tap Slowest First
      await tester.tap(find.text('Slowest First'));
      await tester.pumpAndSettle();

      expect(viewModel.records.first.id, 'slow');

      // Tap sort menu -> Fastest First
      await tester.tap(find.byTooltip('Sort records'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fastest First'));
      await tester.pumpAndSettle();

      expect(viewModel.records.first.id, 'fast');

      // Tap sort menu -> Oldest First
      await tester.tap(find.byTooltip('Sort records'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Oldest First'));
      await tester.pumpAndSettle();

      expect(viewModel.records.first.id, 'slow'); // slow has earliest timestamp
    });
  });
}
