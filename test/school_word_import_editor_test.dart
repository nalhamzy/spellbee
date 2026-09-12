import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/models/word.dart';
import 'package:spellbee/core/models/word_list.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/word_list_editor_screen.dart';

void main() {
  final existing = WordList(
    id: 'school-week-1',
    name: 'This week',
    level: 2,
    createdAt: DateTime(2026, 9, 1),
    words: const [Word('bridge', 'Crosses water.', 'We crossed the bridge.')],
  );

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    WordList? list,
    double width = 430,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());
    if (list != null) await storage.saveLists([list]);
    final container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => WordListEditorScreen(existing: list),
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> paste(WidgetTester tester, String source) async {
    await tester.tap(find.text('Paste school words'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('school-word-import-text')),
      source,
    );
    await tester.pump();
  }

  testWidgets(
    'review edits apply only after confirm; save preserves original list and context',
    (tester) async {
      final container = await mount(tester, list: existing);
      await paste(tester, 'bridge\n BEE,bee, ice cream');
      expect(find.text('2 new words'), findsOneWidget);
      await tester.tap(find.text('Review words'));
      await tester.pumpAndSettle();
      expect(find.text('Review school words'), findsOneWidget);
      expect(find.text('2 duplicate entries skipped.'), findsOneWidget);
      expect(container.read(wordListsProvider).single, existing);
      await tester.enterText(
        find.byKey(const ValueKey('school-word-import-text')),
        'Bee\nwell-being\nBRIDGE\nbee',
      );
      await tester.pump();
      await tester.tap(find.text('Add 2 words'));
      await tester.pumpAndSettle();
      expect(container.read(wordListsProvider).single, existing);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Open editor'), findsOneWidget);
      final saved = container.read(wordListsProvider).single;
      expect(saved.id, existing.id);
      expect(saved.createdAt, existing.createdAt);
      expect(saved.level, existing.level);
      expect(saved.words.first, existing.words.first);
      expect(saved.words.map((word) => word.text), [
        'bridge',
        'Bee',
        'well-being',
      ]);
      expect(container.read(storageServiceProvider).loadLists().single, saved);
      expect(existing.words, hasLength(1));
    },
  );

  testWidgets(
    'cancel preview preserves list and pending individual word fields',
    (tester) async {
      final container = await mount(tester, list: existing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Word (required)'),
        'garden',
      );
      await paste(tester, 'honey\nflower');
      await tester.tap(find.text('Review words'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('garden'), findsOneWidget);
      expect(container.read(wordListsProvider).single, existing);
      await tester.tap(find.text('Add to list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        container.read(wordListsProvider).single.words.map((word) => word.text),
        ['bridge', 'garden'],
      );
    },
  );

  testWidgets(
    'name-only draft and confirmed import have working back protection',
    (tester) async {
      final container = await mount(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'List name'),
        'Week two',
      );
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await paste(tester, 'flower');
      await tester.tap(find.text('Review words'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add 1 word'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Open editor'), findsOneWidget);
      expect(container.read(wordListsProvider), isEmpty);
    },
  );

  testWidgets('blank and duplicate-only imports cannot be confirmed', (
    tester,
  ) async {
    await mount(tester, list: existing);
    await paste(tester, ' , \n BRIDGE,bridge');
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Review words'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('0 new words'), findsOneWidget);
  });

  testWidgets('import stays usable on narrow screens with large text', (
    tester,
  ) async {
    await mount(tester, width: 320, textScale: 2);
    await paste(tester, 'bee, honey');
    await tester.tap(find.text('Review words'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Add 2 words'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
