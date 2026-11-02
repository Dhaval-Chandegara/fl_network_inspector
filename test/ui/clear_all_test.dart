import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_network_inspector/src/repository/in_memory_network_inspector_repository.dart';
import 'package:flutter_network_inspector/src/ui/components/clear_all_dialog.dart';
import 'package:flutter_network_inspector/src/ui/controllers/inspector_view_model.dart';
import 'package:flutter_network_inspector/src/ui/controllers/theme_controller.dart';
import 'package:flutter_network_inspector/src/ui/network_inspector_screen.dart';

import 'helpers/test_record_fixtures.dart';

void main() {
  group('Clear All Confirmation & Theme Toggle Tests', () {
    testWidgets('Clear All Dialog displays exact copy contract', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ClearAllDialog.show(context),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Clear All Records'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to permanently delete all captured network records? This action cannot be undone.',
        ),
        findsOneWidget,
      );
      expect(find.text('Keep Records'), findsOneWidget);
      expect(find.text('Clear Records'), findsOneWidget);
    });

    testWidgets('cancelling Clear All preserves records', (tester) async {
      final repository = InMemoryNetworkInspectorRepository();
      await repository.save(TestRecordFixtures.getSuccessRecord);
      final viewModel = InspectorViewModel(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorScreen(viewModel: viewModel),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);

      // Tap trash icon
      await tester.tap(find.byTooltip('Clear all records'));
      await tester.pumpAndSettle();

      // Tap Keep Records
      await tester.tap(find.text('Keep Records'));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(viewModel.records.length, 1);
      final count = await repository.getRecordCount();
      expect(count, 1);
    });

    testWidgets('confirming Clear All wipes repository and transitions to empty state',
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
      expect(find.text('1'), findsOneWidget);

      // Tap trash icon
      await tester.tap(find.byTooltip('Clear all records'));
      await tester.pumpAndSettle();

      // Tap Clear Records
      await tester.tap(find.text('Clear Records'));
      await tester.pumpAndSettle();

      // Empty state displayed
      expect(find.text('No Captured Traffic'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('All network records cleared'), findsOneWidget);

      final count = await repository.getRecordCount();
      expect(count, 0);
    });

    testWidgets('ThemeController toggles System -> Light -> Dark -> System',
        (tester) async {
      final themeController = ThemeController();
      expect(themeController.value, ThemeMode.system);

      themeController.toggleTheme();
      expect(themeController.value, ThemeMode.light);

      themeController.toggleTheme();
      expect(themeController.value, ThemeMode.dark);

      themeController.toggleTheme();
      expect(themeController.value, ThemeMode.system);
    });

    testWidgets('AppBar theme button toggles theme controller', (tester) async {
      final repository = InMemoryNetworkInspectorRepository();
      final themeController = ThemeController();

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkInspectorScreen(
            repository: repository,
            themeController: themeController,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(themeController.value, ThemeMode.system);

      await tester.tap(find.byTooltip('Switch Theme'));
      await tester.pumpAndSettle();
      expect(themeController.value, ThemeMode.light);

      await tester.tap(find.byTooltip('Switch Theme'));
      await tester.pumpAndSettle();
      expect(themeController.value, ThemeMode.dark);
    });
  });
}
